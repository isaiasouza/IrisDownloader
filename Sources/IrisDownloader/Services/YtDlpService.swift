import Foundation

// MARK: - Media Info

struct MediaInfo {
    let title: String
    let thumbnailURL: String?
    let duration: Int?       // seconds
    let uploader: String?
}

// MARK: - YtDlp Service

final class YtDlpService {

    let ytDlpPath: String
    let ffmpegPath: String

    init(ytDlpPath: String, ffmpegPath: String) {
        self.ytDlpPath  = ytDlpPath
        self.ffmpegPath = ffmpegPath
    }

    // MARK: - Detect installation

    static func detectYtDlp() -> String? {
        for path in ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"] {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // try `which`
        if let found = which("yt-dlp") { return found }
        return nil
    }

    static func detectFfmpeg() -> String? {
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"] {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        if let found = which("ffmpeg") { return found }
        return nil
    }

    private static func which(_ tool: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [tool]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out?.isEmpty == false ? out : nil
    }

    // MARK: - Fetch Info

    func fetchInfo(url: String) async throws -> MediaInfo {
        let args: [String] = [
            ytDlpPath,
            "--dump-json",
            "--no-playlist",
            "--quiet",
            url
        ]

        let result = try await run(args: args)
        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw YtDlpError.infoFetchFailed(result.output + result.error)
        }

        let title        = (json["title"]     as? String) ?? url
        let thumbnail    = (json["thumbnail"] as? String)
        let duration     = (json["duration"]  as? Int)
        let uploader     = (json["uploader"]  as? String) ?? (json["channel"] as? String)

        return MediaInfo(title: title, thumbnailURL: thumbnail, duration: duration, uploader: uploader)
    }

    // MARK: - Start Download

    @discardableResult
    func startDownload(
        item: SocialDownloadItem,
        onProgress: @escaping (Double, String, String) -> Void,  // progress, speed, eta
        onComplete: @escaping (Bool, String?) -> Void            // success, outputPath
    ) -> Process {

        let outputTemplate = (item.destinationPath as NSString)
            .appendingPathComponent("%(title)s.%(ext)s")

        // Prefix printed to stdout so we can extract the real output path
        let filePathPrefix = "__IRIS_FILEPATH__:"

        var args: [String] = [
            ytDlpPath,
            "--no-playlist",
            "--newline",
            // Print real output path after download/conversion finishes
            "--print", "after_move:\(filePathPrefix)%(filepath)s",
            // Separate progress lines from file path line
            "--progress-template", "PROG:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
        ]

        if !ffmpegPath.isEmpty {
            args += ["--ffmpeg-location", (ffmpegPath as NSString).deletingLastPathComponent]
        }

        switch item.format {
        case .video:
            // More permissive selector — works on Instagram/TikTok which don't always have mp4
            let fmt: String
            switch item.quality {
            case .best:  fmt = "bestvideo+bestaudio/best"
            case .q1080: fmt = "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
            case .q720:  fmt = "bestvideo[height<=720]+bestaudio/best[height<=720]/best"
            case .q480:  fmt = "bestvideo[height<=480]+bestaudio/best[height<=480]/best"
            case .q360:  fmt = "bestvideo[height<=360]+bestaudio/best[height<=360]/best"
            }
            // Recode to mp4 so the file always opens in macOS
            args += [
                "-f", fmt,
                "--merge-output-format", "mp4",
                "-o", outputTemplate
            ]
        case .audioOnly:
            args += [
                "-f", "bestaudio",
                "-x", "--audio-format", "mp3",
                "--audio-quality", "0",
                "-o", outputTemplate
            ]
        }

        args.append(item.url)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        var capturedFilePath: String? = nil

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }

            for rawLine in chunk.components(separatedBy: .newlines) {
                let l = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !l.isEmpty else { continue }

                // Capture real file path
                if l.hasPrefix(filePathPrefix) {
                    let path = String(l.dropFirst(filePathPrefix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty {
                        capturedFilePath = path
                    }
                    continue
                }

                // Parse progress line: "PROG:50.5%|1.23MiB/s|00:12"
                if l.hasPrefix("PROG:") {
                    let inner = String(l.dropFirst(5))
                    let parts = inner.components(separatedBy: "|")
                    let pctStr = parts[0].replacingOccurrences(of: "%", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if let pct = Double(pctStr) {
                        let speed = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                        let eta   = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
                        DispatchQueue.main.async {
                            onProgress(min(pct / 100.0, 0.99), speed, eta)
                        }
                    }
                }
            }
        }

        process.terminationHandler = { proc in
            outPipe.fileHandleForReading.readabilityHandler = nil

            // Flush remaining stdout
            let remaining = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            var finalPath = capturedFilePath

            // Fallback: scan remaining output for the filepath prefix
            if finalPath == nil {
                for l in remaining.components(separatedBy: .newlines) {
                    let t = l.trimmingCharacters(in: .whitespacesAndNewlines)
                    if t.hasPrefix(filePathPrefix) {
                        finalPath = String(t.dropFirst(filePathPrefix.count))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }

            let success = proc.terminationStatus == 0
            DispatchQueue.main.async {
                onComplete(success, success ? finalPath : nil)
            }
        }

        try? process.run()
        return process
    }

    // MARK: - Run helper

    private func run(args: [String]) async throws -> (output: String, error: String, status: Int32) {
        return try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError  = errPipe

            process.terminationHandler = { proc in
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (out, err, proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}

// MARK: - Errors

enum YtDlpError: LocalizedError {
    case notInstalled
    case infoFetchFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:           return "yt-dlp não encontrado. Instale via Homebrew."
        case .infoFetchFailed(let m): return "Erro ao buscar info: \(m)"
        case .downloadFailed(let m):  return "Erro no download: \(m)"
        }
    }
}

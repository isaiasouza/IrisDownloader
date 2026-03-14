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
        let platform = SocialPlatform.detect(from: url)

        // Spotify: usa oEmbed público (sem auth) para obter título + artista real
        // O áudio tem DRM, então baixamos o equivalente no YouTube depois
        if platform == .spotify {
            let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
            if let oEmbedURL = URL(string: "https://open.spotify.com/oembed?url=\(encodedURL)"),
               let (data, _) = try? await URLSession.shared.data(from: oEmbedURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                let artist   = json["author_name"] as? String
                let thumbnail = json["thumbnail_url"] as? String
                // "Artista - Título" → termo de busca ideal no YouTube
                let searchTitle = artist.map { "\($0) - \(title)" } ?? title
                return MediaInfo(title: searchTitle, thumbnailURL: thumbnail, duration: nil, uploader: artist)
            }
            // Fallback: sem acesso à internet — usa slug da URL como busca
            let slug = url.components(separatedBy: "/").last?
                .components(separatedBy: "?").first ?? url
            return MediaInfo(title: slug, thumbnailURL: nil, duration: nil, uploader: "Spotify")
        }

        let resolvedURL: String
        if platform == .search {
            resolvedURL = "ytsearch1:\(url)"
        } else {
            resolvedURL = url
        }

        let args: [String] = [
            ytDlpPath,
            "--dump-json",
            "--no-playlist",
            "--quiet",
            resolvedURL
        ]

        let result = try await run(args: args)
        
        // If output is empty, it means no results for search or error for URL
        let output = result.output.trimmingCharacters(in: .newlines)
        if output.isEmpty {
            if platform == .search {
                return MediaInfo(title: "Busca: \(url)", thumbnailURL: nil, duration: 0, uploader: nil)
            }
            throw YtDlpError.infoFetchFailed("Nenhuma informação encontrada. Verifique o link ou tente buscar pelo nome.")
        }

        guard result.status == 0,
              let data = output.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? 
                         (output.components(separatedBy: .newlines).compactMap { d in 
                             try? JSONSerialization.jsonObject(with: d.data(using: .utf8) ?? Data()) as? [String: Any] 
                         }.first)
        else {
            throw YtDlpError.infoFetchFailed("Falha ao processar dados do vídeo.")
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
        onComplete: @escaping (Bool, String?, String?) -> Void  // success, outputPath, errorMsg
    ) -> Process {

        let outputTemplate = (item.destinationPath as NSString)
            .appendingPathComponent("%(title)s.%(ext)s")

        let filePathPrefix = "__IRIS_FILEPATH__:"

        var args: [String] = [
            ytDlpPath,
            "--no-playlist",
            "--newline",
            "--print", "after_move:\(filePathPrefix)%(filepath)s",
            "--progress-template", "PROG:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--restrict-filenames",
        ]

        if !ffmpegPath.isEmpty {
            args += ["--ffmpeg-location", (ffmpegPath as NSString).deletingLastPathComponent]
        }

        switch item.format {
        case .video:
            let fmt: String
            switch item.quality {
            case .best:  fmt = "bestvideo[vcodec!=none]+bestaudio/best[vcodec!=none]/best[height>=1]"
            case .q1080: fmt = "bestvideo[height<=1080][vcodec!=none]+bestaudio/best[height<=1080][vcodec!=none]/best[vcodec!=none]"
            case .q720:  fmt = "bestvideo[height<=720][vcodec!=none]+bestaudio/best[height<=720][vcodec!=none]/best[vcodec!=none]"
            case .q480:  fmt = "bestvideo[height<=480][vcodec!=none]+bestaudio/best[height<=480][vcodec!=none]/best[vcodec!=none]"
            case .q360:  fmt = "bestvideo[height<=360][vcodec!=none]+bestaudio/best[height<=360][vcodec!=none]/best[vcodec!=none]"
            }
            args += ["-f", fmt, "--merge-output-format", "mp4", "-o", outputTemplate]
        case .audioOnly:
            args += ["-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0", "-o", outputTemplate]
        }

        var downloadURL = item.url
        if item.platform == .search {
            downloadURL = "ytsearch1:\(item.url)"
        } else if item.platform == .spotify {
            let searchTerm = item.title
                .replacingOccurrences(of: "^Spotify: ", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if searchTerm.isEmpty || searchTerm.contains("://") || searchTerm.count < 5 {
                // Sem título útil → busca por term genérico da URL
                let slug = item.url.components(separatedBy: "/").last?
                    .components(separatedBy: "?").first ?? item.url
                downloadURL = "ytsearch1:\(slug)"
            } else {
                // Busca no YouTube Music (topic) para melhor match de áudio
                downloadURL = "ytsearch1:\(searchTerm)"
            }
        }
        args.append(downloadURL)

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
        var stderrBuffer: String = ""

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }

            for rawLine in chunk.components(separatedBy: .newlines) {
                let l = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if l.hasPrefix(filePathPrefix) {
                    capturedFilePath = String(l.dropFirst(filePathPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if l.hasPrefix("PROG:") {
                    let inner = String(l.dropFirst(5))
                    let parts = inner.components(separatedBy: "|")
                    let pctStr = parts[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                    if let pct = Double(pctStr) {
                        let speed = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                        let eta   = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
                        DispatchQueue.main.async { onProgress(min(pct / 100.0, 0.99), speed, eta) }
                    }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            if let chunk = String(data: handle.availableData, encoding: .utf8) {
                stderrBuffer += chunk
            }
        }

        process.terminationHandler = { proc in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            let finalOut = String(data: (try? outPipe.fileHandleForReading.readToEnd()) ?? Data(), encoding: .utf8) ?? ""
            let finalErr = String(data: (try? errPipe.fileHandleForReading.readToEnd()) ?? Data(), encoding: .utf8) ?? ""
            stderrBuffer += finalErr

            var finalPath = capturedFilePath
            if finalPath == nil {
                for l in finalOut.components(separatedBy: .newlines) {
                    let t = l.trimmingCharacters(in: .whitespacesAndNewlines)
                    if t.hasPrefix(filePathPrefix) {
                        finalPath = String(t.dropFirst(filePathPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }

            let success = proc.terminationStatus == 0
            let errorMsg = success ? nil : stderrBuffer.components(separatedBy: .newlines)
                .filter { $0.contains("ERROR:") }
                .first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Erro no processo"

            DispatchQueue.main.async { onComplete(success, finalPath, errorMsg) }
        }

        try? process.run()
        return process
    }

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
            try? process.run()
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

import Foundation

struct RcloneRemote {
    let name: String
    let type: String
}

enum RcloneDetector {
    /// Run a process with a timeout (default 15s). Returns (output, exitCode) or nil on timeout.
    private static func runWithTimeout(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 15
    ) -> (output: String, status: Int32)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        // Read output in background to avoid pipe deadlock
        var data = Data()
        let readQueue = DispatchQueue(label: "rclonedetector.read")
        let readDone = DispatchSemaphore(value: 0)
        readQueue.async {
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            readDone.signal()
        }

        // Wait with timeout
        let semaphoreTimeout = DispatchTime.now() + timeout
        if readDone.wait(timeout: semaphoreTimeout) == .timedOut {
            if process.isRunning { process.terminate() }
            return nil
        }

        if process.isRunning {
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 {
                Thread.sleep(forTimeInterval: min(remaining, 1.0))
            }
            if process.isRunning { process.terminate() }
        }
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, process.terminationStatus)
    }

    private static let searchPaths = [
        "/opt/homebrew/bin/rclone",
        "/usr/local/bin/rclone",
        "/usr/bin/rclone",
        "\(NSHomeDirectory())/.local/bin/rclone",
        "\(NSHomeDirectory())/bin/rclone"
    ]

    static func findRclone() -> String? {
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        guard let result = runWithTimeout(executablePath: "/usr/bin/which", arguments: ["rclone"], timeout: 5) else {
            return nil
        }

        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return nil
    }

    static func isInstalled(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    static func getVersion(rclonePath: String) -> String? {
        guard let result = runWithTimeout(executablePath: rclonePath, arguments: ["version"], timeout: 10) else {
            return nil
        }
        return result.output.components(separatedBy: .newlines).first
    }

    static func listRemotes(rclonePath: String) -> [RcloneRemote] {
        guard let result = runWithTimeout(executablePath: rclonePath, arguments: ["listremotes", "--long"], timeout: 10),
              result.status == 0 else {
            return []
        }

        var remotes: [RcloneRemote] = []
        for line in result.output.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let type = parts[1].trimmingCharacters(in: .whitespaces)
                remotes.append(RcloneRemote(name: name, type: type))
            }
        }

        return remotes
    }

    static func listDriveRemotes(rclonePath: String) -> [String] {
        listRemotes(rclonePath: rclonePath)
            .filter { $0.type == "drive" }
            .map { $0.name }
    }

    /// Authorize a new Google Drive account via OAuth in the browser.
    /// Returns the token JSON string on success.
    static func authorizeGoogleDrive(
        rclonePath: String,
        onStatusUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclonePath)
        process.arguments = ["authorize", "drive"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        // Provide empty stdin so rclone doesn't hang waiting for input
        process.standardInput = Pipe()

        var outputBuffer = ""

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                outputBuffer += text
                // Check for status messages
                if text.contains("http://") || text.contains("https://") {
                    DispatchQueue.main.async {
                        onStatusUpdate("Aguardando autorização no navegador...")
                    }
                }
                if text.contains("Success") || text.contains("success") {
                    DispatchQueue.main.async {
                        onStatusUpdate("Autorizado com sucesso!")
                    }
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                outputBuffer += text
            }
        }

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            // Extract the token JSON from the output
            // rclone authorize outputs: Paste the following into your remote machine --->
            // {"access_token":"...","token_type":"Bearer",...}
            // <---End paste
            if let tokenJSON = extractToken(from: outputBuffer) {
                DispatchQueue.main.async {
                    completion(.success(tokenJSON))
                }
            } else if proc.terminationStatus != 0 {
                DispatchQueue.main.async {
                    completion(.failure(RcloneAuthError.authorizationFailed(outputBuffer)))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(RcloneAuthError.tokenNotFound))
                }
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(error))
        }

        return process
    }

    /// Create a new rclone remote with the given token
    static func createRemote(
        rclonePath: String,
        name: String,
        token: String,
        scope: String = "drive"
    ) -> Bool {
        guard let result = runWithTimeout(
            executablePath: rclonePath,
            arguments: ["config", "create", name, "drive", "scope", scope, "token", token],
            timeout: 15
        ) else { return false }
        return result.status == 0
    }

    /// Delete a remote
    static func deleteRemote(rclonePath: String, name: String) -> Bool {
        guard let result = runWithTimeout(
            executablePath: rclonePath,
            arguments: ["config", "delete", name],
            timeout: 10
        ) else { return false }
        return result.status == 0
    }

    /// Extract token JSON from rclone authorize output
    private static func extractToken(from output: String) -> String? {
        // Look for JSON token between the markers
        // Pattern: {"access_token":"..."}
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("{") && trimmed.contains("access_token") {
                return trimmed
            }
        }

        // Try to find it with regex
        if let range = output.range(of: #"\{[^{}]*"access_token"[^{}]*\}"#, options: .regularExpression) {
            return String(output[range])
        }

        return nil
    }
}

enum RcloneAuthError: LocalizedError {
    case authorizationFailed(String)
    case tokenNotFound

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let output):
            return "Autorização falhou: \(output.prefix(200))"
        case .tokenNotFound:
            return "Token não encontrado na resposta"
        }
    }
}

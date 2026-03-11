import Foundation

final class RcloneService {
    private let rclonePath: String
    private let remoteName: String
    var bandwidthLimit: String = "0"
    var uploadTransfers: Int = 8
    var driveChunkSize: String = "128M"

    init(rclonePath: String, remoteName: String) {
        self.rclonePath = rclonePath
        self.remoteName = remoteName
    }

    /// Run a process off the main thread and return output (with 60s timeout)
    private func runProcess(args: [String]) async throws -> (output: String, status: Int32) {
        let rclone = rclonePath
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: rclone)
                process.arguments = args

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                var resumed = false
                let lock = NSLock()

                // Timeout: kill the process after 60 seconds
                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + 60)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                    lock.lock()
                    if !resumed {
                        resumed = true
                        lock.unlock()
                        continuation.resume(throwing: RcloneError.timeout)
                    } else {
                        lock.unlock()
                    }
                }
                timer.resume()

                do {
                    try process.run()

                    // IMPORTANT: Read pipe BEFORE waitUntilExit to avoid deadlock.
                    // If output exceeds the pipe buffer (~64KB), the process blocks
                    // writing until the buffer is read. Reading first prevents this.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    timer.cancel()

                    lock.lock()
                    if !resumed {
                        resumed = true
                        lock.unlock()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: (output, process.terminationStatus))
                    } else {
                        lock.unlock()
                    }
                } catch {
                    timer.cancel()
                    lock.lock()
                    if !resumed {
                        resumed = true
                        lock.unlock()
                        continuation.resume(throwing: error)
                    } else {
                        lock.unlock()
                    }
                }
            }
        }
    }

    /// Get the size and file count of a remote path
    func getSize(driveID: String) async throws -> (bytes: Int64, count: Int) {
        let result = try await runProcess(args: [
            "size", "--json",
            "\(remoteName):",
            "--drive-root-folder-id", driveID
        ])

        guard result.status == 0,
              let parsed = RcloneOutputParser.parseSizeOutput(result.output) else {
            throw RcloneError.sizeQueryFailed(result.output)
        }

        return parsed
    }

    /// Get the name of a drive item
    func getName(driveID: String) async throws -> String {
        let result = try await runProcess(args: [
            "lsjson",
            "\(remoteName):",
            "--drive-root-folder-id", driveID
        ])

        if result.status == 0,
           let jsonData = result.output.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]],
           !items.isEmpty {
            if let name = try? await getFolderNameViaBackend(driveID: driveID) {
                return name
            }
            return "Pasta Drive (\(items.count) itens)"
        }

        return driveID
    }

    private func getFolderNameViaBackend(driveID: String) async throws -> String? {
        let result = try await runProcess(args: [
            "backend", "get",
            "\(remoteName):",
            "-o", "id=\(driveID)",
            "-o", "fields=name"
        ])

        guard result.status == 0 else { return nil }

        if let jsonData = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let name = json["name"] as? String {
            return name
        }

        return nil
    }

    /// List contents of the Drive root (no --drive-root-folder-id)
    func listRootContents() async throws -> [DriveItem] {
        let result = try await runProcess(args: [
            "lsjson",
            "\(remoteName):"
        ])

        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> DriveItem? in
            guard let name = item["Name"] as? String,
                  let path = item["Path"] as? String else { return nil }

            let isDir = (item["IsDir"] as? Bool) ?? false
            var size: Int64 = 0
            if let s = item["Size"] as? Int64 {
                size = s
            } else if let s = item["Size"] as? Int {
                size = Int64(s)
            } else if let s = item["Size"] as? Double {
                size = Int64(s)
            }

            let id = (item["ID"] as? String) ?? path

            return DriveItem(id: id, name: name, path: path, size: size, isFolder: isDir)
        }
    }

    /// List contents of a Drive folder
    func listContents(driveID: String) async throws -> [DriveItem] {
        let result = try await runProcess(args: [
            "lsjson",
            "\(remoteName):",
            "--drive-root-folder-id", driveID
        ])

        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> DriveItem? in
            guard let name = item["Name"] as? String,
                  let path = item["Path"] as? String else { return nil }

            let isDir = (item["IsDir"] as? Bool) ?? false
            var size: Int64 = 0
            if let s = item["Size"] as? Int64 {
                size = s
            } else if let s = item["Size"] as? Int {
                size = Int64(s)
            } else if let s = item["Size"] as? Double {
                size = Int64(s)
            }

            let id = (item["ID"] as? String) ?? path

            return DriveItem(id: id, name: name, path: path, size: size, isFolder: isDir)
        }
    }

    /// List items shared with me (root level)
    func listSharedWithMe() async throws -> [DriveItem] {
        let result = try await runProcess(args: [
            "lsjson",
            "\(remoteName):",
            "--drive-shared-with-me"
        ])

        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> DriveItem? in
            guard let name = item["Name"] as? String,
                  let path = item["Path"] as? String else { return nil }

            let isDir = (item["IsDir"] as? Bool) ?? false
            var size: Int64 = 0
            if let s = item["Size"] as? Int64 {
                size = s
            } else if let s = item["Size"] as? Int {
                size = Int64(s)
            } else if let s = item["Size"] as? Double {
                size = Int64(s)
            }

            let id = (item["ID"] as? String) ?? path

            return DriveItem(id: id, name: name, path: path, size: size, isFolder: isDir)
        }
    }

    /// List contents of a shared folder
    func listSharedContents(driveID: String) async throws -> [DriveItem] {
        let result = try await runProcess(args: [
            "lsjson",
            "\(remoteName):",
            "--drive-root-folder-id", driveID,
            "--drive-shared-with-me"
        ])

        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> DriveItem? in
            guard let name = item["Name"] as? String,
                  let path = item["Path"] as? String else { return nil }

            let isDir = (item["IsDir"] as? Bool) ?? false
            var size: Int64 = 0
            if let s = item["Size"] as? Int64 {
                size = s
            } else if let s = item["Size"] as? Int {
                size = Int64(s)
            } else if let s = item["Size"] as? Double {
                size = Int64(s)
            }

            let id = (item["ID"] as? String) ?? path

            return DriveItem(id: id, name: name, path: path, size: size, isFolder: isDir)
        }
    }

    /// Create a new folder inside a Drive folder and return its ID.
    func createFolder(name: String, parentID: String) async throws -> String {
        let mkResult = try await runProcess(args: [
            "mkdir",
            "\(remoteName):\(name)",
            "--drive-root-folder-id", parentID
        ])

        guard mkResult.status == 0 else {
            throw RcloneError.downloadFailed(Int(mkResult.status))
        }

        // List children of parent to find the new folder's ID
        let listResult = try await runProcess(args: [
            "lsjson",
            "\(remoteName):",
            "--drive-root-folder-id", parentID,
            "--dirs-only"
        ])

        if listResult.status == 0,
           let data = listResult.output.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let match = items.first(where: { ($0["Name"] as? String) == name }),
           let id = match["ID"] as? String {
            return id
        }

        return parentID  // fallback: upload to parent
    }

    /// Start a download process and return the Process handle

    /// - Parameter folderName: When provided, files are placed inside `destinationPath/folderName`,
    ///   preserving the Drive folder structure instead of copying contents flat into `destinationPath`.
    func startDownload(
        driveID: String,
        destinationPath: String,
        folderName: String? = nil,
        onStats: @escaping (RcloneStats) -> Void,
        onLogLine: ((String) -> Void)? = nil,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclonePath)

        // If a folderName is provided, append it to the destination so rclone
        // creates the folder at the destination instead of copying contents flat.
        let effectiveDest: String
        if let name = folderName, !name.isEmpty {
            effectiveDest = (destinationPath as NSString).appendingPathComponent(name)
        } else {
            effectiveDest = destinationPath
        }

        var args = [
            "copy",
            "\(remoteName):",
            effectiveDest,
            "--drive-root-folder-id", driveID,
            "--stats", "1s",
            "--use-json-log",
            "--stats-log-level", "NOTICE",
            "-v"
        ]

        // Add bandwidth limit if set
        if bandwidthLimit != "0" && !bandwidthLimit.isEmpty {
            args += ["--bwlimit", bandwidthLimit]
        }

        process.arguments = args

        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    DispatchQueue.main.async {
                        onLogLine?(line)
                    }
                    if let stats = RcloneOutputParser.parseStatsLine(line) {
                        DispatchQueue.main.async {
                            onStats(stats)
                        }
                    }
                }
            }
        }

        process.terminationHandler = { proc in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    onComplete(.success(()))
                } else if proc.terminationReason == .uncaughtSignal {
                    onComplete(.failure(RcloneError.cancelled))
                } else {
                    onComplete(.failure(RcloneError.downloadFailed(Int(proc.terminationStatus))))
                }
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                onComplete(.failure(error))
            }
        }

        return process
    }

    /// Get local folder/file size
    func getLocalSize(path: String) -> (bytes: Int64, count: Int) {
        let fm = FileManager.default
        var totalBytes: Int64 = 0
        var fileCount = 0

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return (0, 0)
        }

        if isDir.boolValue {
            if let enumerator = fm.enumerator(atPath: path) {
                while let file = enumerator.nextObject() as? String {
                    let fullPath = (path as NSString).appendingPathComponent(file)
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let fileType = attrs[.type] as? FileAttributeType,
                       fileType == .typeRegular {
                        totalBytes += (attrs[.size] as? Int64) ?? 0
                        fileCount += 1
                    }
                }
            }
        } else {
            if let attrs = try? fm.attributesOfItem(atPath: path) {
                totalBytes = (attrs[.size] as? Int64) ?? 0
                fileCount = 1
            }
        }

        return (totalBytes, fileCount)
    }

    /// Start an upload process and return the Process handle
    func startUpload(
        localPath: String,
        driveID: String,
        onStats: @escaping (RcloneStats) -> Void,
        onLogLine: ((String) -> Void)? = nil,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclonePath)

        // When uploading a folder, append its name to the dest so rclone creates
        // the same subfolder on Drive instead of dumping the contents directly.
        var isDir: ObjCBool = false
        let isFolder = FileManager.default.fileExists(atPath: localPath, isDirectory: &isDir) && isDir.boolValue
        let folderName = (localPath as NSString).lastPathComponent
        let destPath = isFolder ? "\(remoteName):\(folderName)" : "\(remoteName):"

        var args = [
            "copy",
            localPath,
            destPath,
            "--drive-root-folder-id", driveID,
            "--stats", "1s",
            "--use-json-log",
            "--stats-log-level", "NOTICE",
            "-v",
            "--transfers", "\(uploadTransfers)",
            "--drive-chunk-size", driveChunkSize
        ]

        if bandwidthLimit != "0" && !bandwidthLimit.isEmpty {
            args += ["--bwlimit", bandwidthLimit]
        }

        process.arguments = args

        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    DispatchQueue.main.async {
                        onLogLine?(line)
                    }
                    if let stats = RcloneOutputParser.parseStatsLine(line) {
                        DispatchQueue.main.async {
                            onStats(stats)
                        }
                    }
                }
            }
        }

        process.terminationHandler = { proc in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    onComplete(.success(()))
                } else if proc.terminationReason == .uncaughtSignal {
                    onComplete(.failure(RcloneError.cancelled))
                } else {
                    onComplete(.failure(RcloneError.uploadFailed(Int(proc.terminationStatus))))
                }
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                onComplete(.failure(error))
            }
        }

        return process
    }

    /// Generate a shareable Google Drive link for a given driveID
    func generateShareLink(driveID: String, isFolder: Bool) async -> String {
        // Try rclone link first (makes the item publicly accessible)
        do {
            let result = try await runProcess(args: [
                "link",
                "\(remoteName):",
                "--drive-root-folder-id", driveID
            ])
            let link = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.status == 0 && !link.isEmpty && link.hasPrefix("http") {
                return link
            }
        } catch {
            // Fall through to manual URL construction
        }

        // Fallback: construct URL manually
        if isFolder {
            return "https://drive.google.com/drive/folders/\(driveID)?usp=sharing"
        } else {
            return "https://drive.google.com/file/d/\(driveID)/view?usp=sharing"
        }
    }

    func pause(_ process: Process) {
        guard process.isRunning else { return }
        kill(process.processIdentifier, SIGSTOP)
    }

    func resume(_ process: Process) {
        guard process.isRunning else { return }
        kill(process.processIdentifier, SIGCONT)
    }

    func cancel(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
    }
}

enum RcloneError: LocalizedError {
    case sizeQueryFailed(String)
    case downloadFailed(Int)
    case uploadFailed(Int)
    case cancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .sizeQueryFailed(let output):
            return "Falha ao consultar tamanho: \(output)"
        case .downloadFailed(let code):
            return "Download falhou com código \(code)"
        case .uploadFailed(let code):
            return "Upload falhou com código \(code)"
        case .cancelled:
            return "Transferência cancelada"
        case .timeout:
            return "Operação expirou (timeout de 60s)"
        }
    }
}

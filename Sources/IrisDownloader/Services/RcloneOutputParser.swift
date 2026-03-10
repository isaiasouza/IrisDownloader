import Foundation

struct FileTransferInfo: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let bytesTransferred: Int64
    let percentage: Double  // 0-100
    let speed: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var bytesTransferredFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytesTransferred, countStyle: .file)
    }
}

struct RcloneStats {
    var bytesTransferred: Int64 = 0
    var totalBytes: Int64 = 0
    var speed: String = ""
    var eta: String = ""
    var filesTransferred: Int = 0
    var totalFiles: Int = 0
    var percentage: Double = 0
    var currentFileName: String = ""
    var transferringFiles: [FileTransferInfo] = []
}

enum RcloneOutputParser {
    /// Parse a JSON stats line from rclone --use-json-log --stats 1s
    static func parseStatsLine(_ line: String) -> RcloneStats? {
        guard let data = line.data(using: .utf8) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let stats = json["stats"] as? [String: Any] else {
            return nil
        }

        var result = RcloneStats()

        if let bytes = stats["bytes"] as? Int64 {
            result.bytesTransferred = bytes
        } else if let bytes = stats["bytes"] as? Int {
            result.bytesTransferred = Int64(bytes)
        } else if let bytes = stats["bytes"] as? Double {
            result.bytesTransferred = Int64(bytes)
        }

        if let totalBytes = stats["totalBytes"] as? Int64 {
            result.totalBytes = totalBytes
        } else if let totalBytes = stats["totalBytes"] as? Int {
            result.totalBytes = Int64(totalBytes)
        } else if let totalBytes = stats["totalBytes"] as? Double {
            result.totalBytes = Int64(totalBytes)
        }

        if let speedVal = stats["speed"] as? Double {
            result.speed = ByteCountFormatter.string(fromByteCount: Int64(speedVal), countStyle: .file) + "/s"
        }

        if let eta = stats["eta"] as? Double {
            let hours = Int(eta) / 3600
            let minutes = (Int(eta) % 3600) / 60
            let seconds = Int(eta) % 60
            if hours > 0 {
                result.eta = String(format: "%dh%02dm%02ds", hours, minutes, seconds)
            } else if minutes > 0 {
                result.eta = String(format: "%dm%02ds", minutes, seconds)
            } else {
                result.eta = String(format: "%ds", seconds)
            }
        }

        if let transfers = stats["transfers"] as? Int {
            result.filesTransferred = transfers
        }

        if let totalTransfers = stats["totalTransfers"] as? Int {
            result.totalFiles = totalTransfers
        }

        if result.totalBytes > 0 {
            result.percentage = Double(result.bytesTransferred) / Double(result.totalBytes)
        }

        // Extract all transferring files
        if let transferring = stats["transferring"] as? [[String: Any]] {
            for entry in transferring {
                guard let name = entry["name"] as? String else { continue }

                var fileSize: Int64 = 0
                if let s = entry["size"] as? Int64 { fileSize = s }
                else if let s = entry["size"] as? Int { fileSize = Int64(s) }
                else if let s = entry["size"] as? Double { fileSize = Int64(s) }

                var fileBytes: Int64 = 0
                if let b = entry["bytes"] as? Int64 { fileBytes = b }
                else if let b = entry["bytes"] as? Int { fileBytes = Int64(b) }
                else if let b = entry["bytes"] as? Double { fileBytes = Int64(b) }

                var filePct: Double = 0
                if let p = entry["percentage"] as? Double { filePct = p }
                else if let p = entry["percentage"] as? Int { filePct = Double(p) }

                var fileSpeed = ""
                if let sp = entry["speed"] as? Double {
                    fileSpeed = ByteCountFormatter.string(fromByteCount: Int64(sp), countStyle: .file) + "/s"
                }

                let info = FileTransferInfo(
                    name: (name as NSString).lastPathComponent,
                    size: fileSize,
                    bytesTransferred: fileBytes,
                    percentage: filePct,
                    speed: fileSpeed
                )
                result.transferringFiles.append(info)
            }

            if let firstName = transferring.first?["name"] as? String {
                result.currentFileName = (firstName as NSString).lastPathComponent
            }
        }

        return result
    }

    /// Parse rclone size --json output
    static func parseSizeOutput(_ output: String) -> (bytes: Int64, count: Int)? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var bytes: Int64 = 0
        var count: Int = 0

        if let b = json["bytes"] as? Int64 {
            bytes = b
        } else if let b = json["bytes"] as? Int {
            bytes = Int64(b)
        } else if let b = json["bytes"] as? Double {
            bytes = Int64(b)
        }

        if let c = json["count"] as? Int {
            count = c
        }

        return (bytes, count)
    }
}

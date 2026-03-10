import Foundation

struct ParsedDriveLink {
    let id: String
    let isFolder: Bool
}

enum GoogleDriveLinkParser {
    static func parse(_ input: String) -> ParsedDriveLink? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern: /folders/<ID>
        if let match = trimmed.range(of: #"/folders/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let fullMatch = String(trimmed[match])
            let id = fullMatch.replacingOccurrences(of: "/folders/", with: "")
            return ParsedDriveLink(id: id, isFolder: true)
        }

        // Pattern: /file/d/<ID>
        if let match = trimmed.range(of: #"/file/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let fullMatch = String(trimmed[match])
            let id = fullMatch.replacingOccurrences(of: "/file/d/", with: "")
            return ParsedDriveLink(id: id, isFolder: false)
        }

        // Pattern: ?id=<ID> or &id=<ID>
        if let match = trimmed.range(of: #"[?&]id=([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let fullMatch = String(trimmed[match])
            let id = fullMatch.replacingOccurrences(of: #"^[?&]id="#, with: "", options: .regularExpression)
            return ParsedDriveLink(id: id, isFolder: false)
        }

        // Pattern: open?id=<ID>
        if let match = trimmed.range(of: #"open\?id=([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let fullMatch = String(trimmed[match])
            let id = fullMatch.replacingOccurrences(of: "open?id=", with: "")
            return ParsedDriveLink(id: id, isFolder: true)
        }

        // Raw ID (just alphanumeric + hyphens + underscores, typical length)
        if trimmed.range(of: #"^[a-zA-Z0-9_-]{10,}$"#, options: .regularExpression) != nil {
            return ParsedDriveLink(id: trimmed, isFolder: true)
        }

        return nil
    }

    /// Reconstrói o link do Google Drive a partir do driveID e tipo (arquivo ou pasta)
    static func makeLink(driveID: String, isFolder: Bool) -> String {
        if isFolder {
            return "https://drive.google.com/drive/folders/\(driveID)"
        } else {
            return "https://drive.google.com/file/d/\(driveID)/view"
        }
    }
}

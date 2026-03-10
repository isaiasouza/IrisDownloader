import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let appSupportDir: URL
    private let historyFile: URL
    private let settingsFile: URL
    private let activeDownloadsFile: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let newDir = appSupport.appendingPathComponent("IrisDownloader", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("DriveDownloader", isDirectory: true)

        // Migrate data from old name if needed
        if FileManager.default.fileExists(atPath: oldDir.path) && !FileManager.default.fileExists(atPath: newDir.path) {
            try? FileManager.default.moveItem(at: oldDir, to: newDir)
        }

        appSupportDir = newDir
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        historyFile = appSupportDir.appendingPathComponent("history.json")
        settingsFile = appSupportDir.appendingPathComponent("settings.json")
        activeDownloadsFile = appSupportDir.appendingPathComponent("active_downloads.json")

        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - History

    func loadHistory() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: historyFile) else { return [] }
        return (try? decoder.decode([DownloadItem].self, from: data)) ?? []
    }

    func saveHistory(_ items: [DownloadItem]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsFile),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsFile, options: .atomic)
    }

    // MARK: - Active Downloads (for auto-resume)

    func loadActiveDownloads() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: activeDownloadsFile) else { return [] }
        let items = (try? decoder.decode([DownloadItem].self, from: data)) ?? []
        // Clear the file after loading
        try? FileManager.default.removeItem(at: activeDownloadsFile)
        return items
    }

    func saveActiveDownloads(_ items: [DownloadItem]) {
        if items.isEmpty {
            try? FileManager.default.removeItem(at: activeDownloadsFile)
            return
        }
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: activeDownloadsFile, options: .atomic)
    }
}

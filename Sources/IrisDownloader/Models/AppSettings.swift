import Foundation

struct AppSettings: Codable {
    var defaultDestination: String
    var maxConcurrentDownloads: Int
    var rclonePath: String
    var rcloneRemoteName: String
    var showNotifications: Bool
    var bandwidthLimit: String  // e.g. "0" (unlimited), "10M", "50M"
    var hasCompletedOnboarding: Bool
    var availableRemotes: [String]
    var lastUpdateCheck: Date?
    var autoRetryEnabled: Bool
    var maxRetries: Int
    var uploadTransfers: Int    // parallel file transfers during upload
    var driveChunkSize: String  // chunk size for Drive multipart uploads (e.g. "64M", "128M")
    var historyRetentionDays: Int
    var preserveDriveStructure: Bool
    var lastSeenVersion: String?
    var ytDlpPath: String    // path to yt-dlp binary
    var ffmpegPath: String   // path to ffmpeg binary

    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6"

    init(
        defaultDestination: String,
        maxConcurrentDownloads: Int,
        rclonePath: String,
        rcloneRemoteName: String,
        showNotifications: Bool,
        bandwidthLimit: String,
        hasCompletedOnboarding: Bool,
        availableRemotes: [String],
        lastUpdateCheck: Date? = nil,
        autoRetryEnabled: Bool = true,
        maxRetries: Int = 3,
        uploadTransfers: Int = 8,
        driveChunkSize: String = "128M",
        historyRetentionDays: Int = 0,
        preserveDriveStructure: Bool = true,
        lastSeenVersion: String? = nil,
        ytDlpPath: String = "",
        ffmpegPath: String = ""
    ) {
        self.defaultDestination = defaultDestination
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.rclonePath = rclonePath
        self.rcloneRemoteName = rcloneRemoteName
        self.showNotifications = showNotifications
        self.bandwidthLimit = bandwidthLimit
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.availableRemotes = availableRemotes
        self.lastUpdateCheck = lastUpdateCheck
        self.autoRetryEnabled = autoRetryEnabled
        self.maxRetries = maxRetries
        self.uploadTransfers = uploadTransfers
        self.driveChunkSize = driveChunkSize
        self.historyRetentionDays = historyRetentionDays
        self.preserveDriveStructure = preserveDriveStructure
        self.lastSeenVersion = lastSeenVersion
        self.ytDlpPath = ytDlpPath
        self.ffmpegPath = ffmpegPath
    }

    // Custom decoding for backward compatibility with v1.1 settings
    enum CodingKeys: String, CodingKey {
        case defaultDestination, maxConcurrentDownloads, rclonePath, rcloneRemoteName
        case showNotifications, bandwidthLimit, hasCompletedOnboarding, availableRemotes
        case lastUpdateCheck, autoRetryEnabled, maxRetries
        case uploadTransfers, driveChunkSize
        case historyRetentionDays
        case preserveDriveStructure
        case lastSeenVersion
        case ytDlpPath, ffmpegPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultDestination = try c.decode(String.self, forKey: .defaultDestination)
        maxConcurrentDownloads = try c.decode(Int.self, forKey: .maxConcurrentDownloads)
        rclonePath = try c.decode(String.self, forKey: .rclonePath)
        rcloneRemoteName = try c.decode(String.self, forKey: .rcloneRemoteName)
        showNotifications = try c.decode(Bool.self, forKey: .showNotifications)
        bandwidthLimit = try c.decode(String.self, forKey: .bandwidthLimit)
        hasCompletedOnboarding = try c.decode(Bool.self, forKey: .hasCompletedOnboarding)
        availableRemotes = try c.decode([String].self, forKey: .availableRemotes)
        lastUpdateCheck = try c.decodeIfPresent(Date.self, forKey: .lastUpdateCheck)
        autoRetryEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoRetryEnabled) ?? true
        maxRetries = try c.decodeIfPresent(Int.self, forKey: .maxRetries) ?? 3
        uploadTransfers = try c.decodeIfPresent(Int.self, forKey: .uploadTransfers) ?? 8
        driveChunkSize = try c.decodeIfPresent(String.self, forKey: .driveChunkSize) ?? "128M"
        historyRetentionDays = try c.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? 0
        preserveDriveStructure = try c.decodeIfPresent(Bool.self, forKey: .preserveDriveStructure) ?? true
        lastSeenVersion = try c.decodeIfPresent(String.self, forKey: .lastSeenVersion)
        ytDlpPath  = try c.decodeIfPresent(String.self, forKey: .ytDlpPath)  ?? YtDlpService.detectYtDlp()  ?? ""
        ffmpegPath = try c.decodeIfPresent(String.self, forKey: .ffmpegPath) ?? YtDlpService.detectFfmpeg() ?? ""
    }

    static let `default` = AppSettings(
        defaultDestination: NSHomeDirectory() + "/Downloads",
        maxConcurrentDownloads: 2,
        rclonePath: "/opt/homebrew/bin/rclone",
        rcloneRemoteName: "gdrive",
        showNotifications: true,
        bandwidthLimit: "0",
        hasCompletedOnboarding: false,
        availableRemotes: [],
        lastUpdateCheck: nil,
        autoRetryEnabled: true,
        maxRetries: 3,
        uploadTransfers: 8,
        driveChunkSize: "128M",
        historyRetentionDays: 0,
        preserveDriveStructure: true,
        lastSeenVersion: nil,
        ytDlpPath:  YtDlpService.detectYtDlp()  ?? "",
        ffmpegPath: YtDlpService.detectFfmpeg() ?? ""
    )
}

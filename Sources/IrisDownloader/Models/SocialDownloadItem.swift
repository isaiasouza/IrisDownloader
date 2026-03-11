import Foundation

// MARK: - Platform

enum SocialPlatform: String, Codable {
    case youtube  = "YouTube"
    case instagram = "Instagram"
    case tiktok   = "TikTok"
    case twitter  = "Twitter/X"
    case other    = "Web"

    var icon: String {
        switch self {
        case .youtube:   return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .tiktok:    return "music.note.tv.fill"
        case .twitter:   return "bird.fill"
        case .other:     return "globe"
        }
    }

    static func detect(from urlString: String) -> SocialPlatform {
        let u = urlString.lowercased()
        if u.contains("youtube.com") || u.contains("youtu.be") { return .youtube }
        if u.contains("instagram.com")                          { return .instagram }
        if u.contains("tiktok.com")                            { return .tiktok }
        if u.contains("twitter.com") || u.contains("x.com")   { return .twitter }
        return .other
    }
}

// MARK: - Format

enum MediaFormat: String, CaseIterable, Identifiable {
    case video     = "Vídeo (MP4)"
    case audioOnly = "Só Áudio (MP3)"

    var id: String { rawValue }
    var icon: String { self == .video ? "video.fill" : "music.note" }
}

// MARK: - Quality

enum MediaQuality: String, CaseIterable, Identifiable {
    case best   = "Melhor qualidade"
    case q1080  = "1080p"
    case q720   = "720p"
    case q480   = "480p"
    case q360   = "360p"

    var id: String { rawValue }

    /// yt-dlp format selector
    var ytDlpFormat: String {
        switch self {
        case .best:  return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        case .q1080: return "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]"
        case .q720:  return "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]"
        case .q480:  return "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480]"
        case .q360:  return "bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/best[height<=360]"
        }
    }
}

// MARK: - Status

enum SocialDownloadStatus: Equatable {
    case queued
    case fetchingInfo
    case downloading
    case converting
    case completed
    case failed(String)
    case cancelled
}

// MARK: - Item

struct SocialDownloadItem: Identifiable {
    let id: UUID
    var url: String
    var title: String
    var thumbnailURL: String?
    var platform: SocialPlatform
    var format: MediaFormat
    var quality: MediaQuality
    var status: SocialDownloadStatus
    var progress: Double       // 0.0 – 1.0
    var speed: String
    var eta: String
    var destinationPath: String
    var outputFilePath: String?

    init(
        url: String,
        format: MediaFormat,
        quality: MediaQuality,
        destination: String
    ) {
        self.id              = UUID()
        self.url             = url
        self.title           = url
        self.thumbnailURL    = nil
        self.platform        = SocialPlatform.detect(from: url)
        self.format          = format
        self.quality         = quality
        self.status          = .queued
        self.progress        = 0
        self.speed           = ""
        self.eta             = ""
        self.destinationPath = destination
        self.outputFilePath  = nil
    }
}

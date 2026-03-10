import Foundation

enum TransferType: String, Codable, Equatable {
    case download
    case upload
}

enum DownloadStatus: String, Codable, Equatable {
    case queued
    case fetchingInfo
    case downloading  // used for both download and upload in-progress
    case paused
    case completed
    case failed
    case cancelled

    func displayName(for type: TransferType) -> String {
        switch self {
        case .queued: return "Na fila"
        case .fetchingInfo: return "Obtendo info..."
        case .downloading: return type == .upload ? "Enviando" : "Baixando"
        case .paused: return "Pausado"
        case .completed: return "Concluído"
        case .failed: return "Falhou"
        case .cancelled: return "Cancelado"
        }
    }

    var displayName: String {
        displayName(for: .download)
    }

    func systemImage(for type: TransferType) -> String {
        switch self {
        case .queued: return "clock"
        case .fetchingInfo: return "magnifyingglass"
        case .downloading: return type == .upload ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var systemImage: String {
        systemImage(for: .download)
    }

    var isActive: Bool {
        self == .downloading
    }

    var isFinished: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

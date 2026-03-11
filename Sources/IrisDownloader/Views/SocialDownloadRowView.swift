import SwiftUI

struct SocialDownloadRowView: View {
    @EnvironmentObject var manager: DownloadManager
    let item: SocialDownloadItem

    var body: some View {
        HStack(spacing: 14) {
            // Platform icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: item.platform.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                // Status row
                HStack(spacing: 8) {
                    Label(item.platform.rawValue, systemImage: item.platform.icon)
                        .font(AppTheme.font(size: 10))
                        .foregroundColor(AppTheme.textMuted)

                    Label(item.format.rawValue, systemImage: item.format.icon)
                        .font(AppTheme.font(size: 10))
                        .foregroundColor(AppTheme.textMuted)

                    if !item.speed.isEmpty {
                        Text(item.speed)
                            .font(AppTheme.font(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    if !item.eta.isEmpty {
                        Text("ETA \(item.eta)")
                            .font(AppTheme.font(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                // Progress bar
                switch item.status {
                case .downloading, .converting:
                    ProgressView(value: item.progress)
                        .tint(AppTheme.accent)
                        .scaleEffect(y: 0.7)
                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                            .font(.system(size: 11))
                        Text("Concluído")
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.success)
                    }
                case .failed(let msg):
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.error)
                            .font(.system(size: 11))
                        Text(msg)
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.error)
                            .lineLimit(1)
                    }
                case .queued:
                    Text("Na fila…")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                case .fetchingInfo:
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        Text("Obtendo informações…")
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                case .cancelled:
                    Text("Cancelado")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if case .completed = item.status {
                    // Open file directly
                    if let path = item.outputFilePath {
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.accent.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Abrir arquivo")
                    }

                    // Show in Finder — uses file path if available, else opens destination folder
                    Button {
                        if let path = item.outputFilePath, FileManager.default.fileExists(atPath: path) {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        } else {
                            NSWorkspace.shared.open(URL(fileURLWithPath: item.destinationPath))
                        }
                    } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Mostrar no Finder")
                }

                if case .downloading = item.status {
                    Button { manager.cancelSocialDownload(id: item.id) } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.error.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Cancelar")
                }

                if case .failed = item.status {
                    Button { manager.retrySocialDownload(id: item.id) } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.accent.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Tentar novamente")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.bgSecondary)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.cardBorder))
        )
    }
}

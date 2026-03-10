import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var manager: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(AppTheme.accent)
                Text("Iris Downloader")
                    .font(AppTheme.font(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 4)

            Divider()

            if manager.activeDownloads.isEmpty {
                Text("Nenhum download ativo")
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.vertical, 4)
            } else {
                ForEach(manager.activeDownloads.prefix(5)) { item in
                    menuBarRow(item)
                }
            }

            if !manager.history.isEmpty {
                Divider()
                let recentCompleted = manager.history.prefix(3)
                ForEach(recentCompleted) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.status.systemImage)
                            .font(AppTheme.font(size: 10))
                            .foregroundColor(AppTheme.statusColor(for: item.status))
                        Text(item.driveName)
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            Button("Abrir Iris Downloader") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title != "" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)
            .font(AppTheme.font(size: 12))
            .foregroundColor(AppTheme.accent)

            Button("Sair") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(AppTheme.font(size: 12))
            .foregroundColor(AppTheme.textMuted)
        }
        .padding(12)
        .frame(width: 280)
    }

    private func menuBarRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.driveName)
                    .font(AppTheme.font(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(item.status.displayName)
                    .font(AppTheme.font(size: 10))
                    .foregroundColor(AppTheme.statusColor(for: item.status))
            }

            if item.status == .downloading || item.status == .paused {
                ProgressView(value: item.progress)
                    .progressViewStyle(IrisProgressStyle(height: 4))

                HStack {
                    Text("\(Int(item.progress * 100))%")
                        .font(AppTheme.font(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted)

                    if !item.speed.isEmpty {
                        Text(item.speed)
                            .font(AppTheme.font(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.accent)
                    }

                    Spacer()

                    if !item.eta.isEmpty {
                        Text(item.eta)
                            .font(AppTheme.font(size: 10, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

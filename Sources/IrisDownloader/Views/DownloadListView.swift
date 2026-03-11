import SwiftUI

struct DownloadListView: View {
    @EnvironmentObject var manager: DownloadManager
    @Binding var showDownloadSheet: Bool
    @Binding var showUploadSheet: Bool

    var body: some View {
        Group {
            if manager.activeDownloads.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Global progress bar
                    if manager.isDownloading {
                        globalProgressBar
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(manager.activeDownloads) { item in
                                DownloadRowView(
                                    item: item,
                                    onPause: { manager.pauseDownload(item) },
                                    onResume: { manager.resumeDownload(item) },
                                    onCancel: { manager.cancelDownload(item) },
                                    onOpenFinder: { manager.openInFinder(item) }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(16)
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.activeDownloads.count)
                }
            }
        }
        .background(AppTheme.bgPrimary)
    }

    private var globalProgressBar: some View {
        VStack(spacing: 6) {
            HStack {
                let activeCount = manager.activeDownloads.filter { $0.status == .downloading }.count
                let queuedCount = manager.activeDownloads.filter { $0.status == .queued }.count

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 6, height: 6)
                        .opacity(pulseAnimation ? 0.4 : 1.0)

                    Text("\(activeCount) ativo(s)")
                        .font(AppTheme.font(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                if queuedCount > 0 {
                    Text("· \(queuedCount) na fila")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                if !manager.activeSpeed.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(AppTheme.font(size: 10))
                        Text(manager.activeSpeed)
                            .font(AppTheme.font(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(AppTheme.accent)
                }

                Text("\(Int(manager.totalProgress * 100))%")
                    .font(AppTheme.font(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
            }

            ProgressView(value: manager.totalProgress)
                .progressViewStyle(IrisProgressStyle(height: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.bgSecondary)
    }

    @State private var pulseAnimation = false

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(AppTheme.font(size: 36))
                    .foregroundColor(AppTheme.accent)
            }

            Text("Nenhuma transferência ativa")
                .font(AppTheme.font(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 4) {
                Text("Clique para começar:")
                    .font(AppTheme.font(size: 13))
                    .foregroundColor(AppTheme.textMuted)

                HStack(spacing: 12) {
                    Button {
                        showDownloadSheet = true
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(AppTheme.font(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.15)))
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Upload", systemImage: "arrow.up.circle")
                            .font(AppTheme.font(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppTheme.success.opacity(0.15)))
                            .foregroundColor(AppTheme.success)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.bgPrimary)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

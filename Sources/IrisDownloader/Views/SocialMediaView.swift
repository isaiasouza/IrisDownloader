import SwiftUI

struct SocialMediaView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var showAddSheet = false
    @State private var initialURL: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Social Media")
                    .font(AppTheme.font(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Novo Download")
                    }
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.accent))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().background(AppTheme.cardBorder)

            smartModeBar

            Divider().background(AppTheme.cardBorder)

            if manager.socialDownloads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.socialDownloads) { item in
                            SocialDownloadRowView(item: item)
                                .environmentObject(manager)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.bgPrimary)
        .sheet(isPresented: $showAddSheet) {
            AddSocialDownloadView(initialURL: initialURL)
                .environmentObject(manager)
                .onDisappear { initialURL = "" }
        }
    }

    // MARK: - Smart Mode Bar

    private var smartModeBar: some View {
        HStack(spacing: 16) {
            // Paste Link Button
            Button {
                handlePasteLink()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .bold))
                    Text("Colar link")
                        .font(AppTheme.font(size: 13, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 6).fill(manager.settings.smartModeEnabled ? AppTheme.success : AppTheme.bgTertiary))
                .foregroundColor(manager.settings.smartModeEnabled ? .white : AppTheme.textPrimary)
            }
            .buttonStyle(.plain)

            // Smart Mode Toggle
            Toggle(isOn: $manager.settings.smartModeEnabled) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(manager.settings.smartModeEnabled ? .yellow : AppTheme.textMuted)
                    Text("Modo Inteligente")
                        .font(AppTheme.font(size: 12, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .tint(AppTheme.success)
            .onChange(of: manager.settings.smartModeEnabled) { _, _ in
                manager.updateSettings(manager.settings)
            }

            // Inline Pickers (Only visible when Smart Mode is ON)
            if manager.settings.smartModeEnabled {
                HStack(spacing: 12) {
                    Picker("", selection: $manager.settings.smartFormat) {
                        ForEach(MediaFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    .onChange(of: manager.settings.smartFormat) { _, _ in manager.updateSettings(manager.settings) }

                    if manager.settings.smartFormat == .video {
                        Picker("", selection: $manager.settings.smartQuality) {
                            ForEach(MediaQuality.allCases) { q in
                                Text(q.rawValue).tag(q)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .onChange(of: manager.settings.smartQuality) { _, _ in manager.updateSettings(manager.settings) }
                    }

                    Button {
                        chooseSmartDestination()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(AppTheme.textMuted)
                            Text(manager.settings.smartDestination.isEmpty ? "Padrão" : (manager.settings.smartDestination as NSString).lastPathComponent)
                                .font(AppTheme.font(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 100, alignment: .leading)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(AppTheme.bgTertiary))
                    }
                    .buttonStyle(.plain)
                    .help(manager.settings.smartDestination.isEmpty ? manager.settings.defaultDestination : manager.settings.smartDestination)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.bgSecondary)
    }

    private func chooseSmartDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            manager.settings.smartDestination = url.path
            manager.updateSettings(manager.settings)
        }
    }

    private func handlePasteLink() {
        guard let clip = NSPasteboard.general.string(forType: .string),
              clip.contains("://"), URL(string: clip) != nil else { return }

        if manager.settings.smartModeEnabled {
            // Auto add
            let dest = manager.settings.smartDestination.isEmpty ? manager.settings.defaultDestination : manager.settings.smartDestination
            manager.addSocialDownload(
                url: clip,
                title: "Buscando informações...",
                platform: SocialPlatform.detect(from: clip),
                format: manager.settings.smartFormat,
                quality: manager.settings.smartQuality,
                destination: dest
            )
            
            // Asynchronously fetch real info and update
            Task {
                let service = YtDlpService(ytDlpPath: manager.settings.ytDlpPath, ffmpegPath: manager.settings.ffmpegPath)
                if let info = try? await service.fetchInfo(url: clip) {
                    await MainActor.run {
                        if let index = manager.socialDownloads.firstIndex(where: { $0.url == clip && $0.title == "Buscando informações..." }) {
                            manager.socialDownloads[index].title = info.title
                            manager.socialDownloads[index].thumbnailURL = info.thumbnailURL
                            // Save to settings/persistence if needed
                        }
                    }
                }
            }
        } else {
            // Open sheet
            initialURL = clip
            showAddSheet = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.1)).frame(width: 72, height: 72)
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text("Nenhum download social")
                    .font(AppTheme.font(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("Cole um link do YouTube, Instagram, TikTok\nou qualquer outra plataforma")
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Adicionar link")
                }
                .font(AppTheme.font(size: 13, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.accent))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

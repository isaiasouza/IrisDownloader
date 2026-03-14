import SwiftUI

struct AddSocialDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var urlText: String
    @State private var selectedFormat: MediaFormat = .video
    @State private var selectedQuality: MediaQuality = .best
    @State private var useCustomDestination = false
    @State private var customDestination: String = ""
    @State private var isFetchingInfo = false
    @State private var fetchedTitle: String? = nil
    @State private var fetchedThumbnail: String? = nil
    @State private var fetchError: String? = nil

    init(initialURL: String = "") {
        _urlText = State(initialValue: initialURL)
    }

    private var platform: SocialPlatform { SocialPlatform.detect(from: urlText) }
    private var isValidURL: Bool { URL(string: urlText) != nil && urlText.contains("://") }
    private var destination: String {
        useCustomDestination && !customDestination.isEmpty
            ? customDestination
            : manager.settings.defaultDestination
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "arrow.down.to.line.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Download Social Media")
                        .font(AppTheme.font(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("YouTube · Instagram · TikTok · Spotify")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider().background(AppTheme.cardBorder)

            ScrollView {
                VStack(spacing: 20) {
                    // URL input
                    urlSection

                    // Preview
                    if let title = fetchedTitle {
                        previewCard(title: title)
                    }
                    if let err = fetchError {
                        errorRow(err)
                    }

                    // Format & Quality
                    if fetchedTitle != nil || isValidURL {
                        formatSection
                        if selectedFormat == .video {
                            qualitySection
                        }
                    }

                    // Destination
                    destinationSection
                }
                .padding(24)
            }

            Divider().background(AppTheme.cardBorder)

            // Buttons
            HStack {
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button(action: addDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Adicionar download")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(!urlText.isEmpty ? AppTheme.accent : AppTheme.bgTertiary))
                    .foregroundColor(!urlText.isEmpty ? .white : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .disabled(urlText.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500)
        .background(AppTheme.bgSecondary)
        .preferredColorScheme(.dark)
        .onAppear {
            // paste from clipboard if it's a URL
            if let clip = NSPasteboard.general.string(forType: .string),
               clip.contains("://"), URL(string: clip) != nil {
                urlText = clip
                if SocialPlatform.detect(from: clip) == .spotify {
                    selectedFormat = .audioOnly
                }
                fetchInfoDebounced()
            }
        }
    }

    // MARK: - Sections

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Link do vídeo", systemImage: "link")
                .font(AppTheme.font(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 8) {
                if !urlText.isEmpty {
                    Image(systemName: platform.icon)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 20)
                }
                TextField("Cole o link ou digite o nome da música...", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(AppTheme.font(size: 13, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .onChange(of: urlText) { _, newVal in
                        // Auto-seleciona áudio para Spotify (sem vídeo disponível)
                        if SocialPlatform.detect(from: newVal) == .spotify {
                            selectedFormat = .audioOnly
                        }
                        fetchInfoDebounced()
                    }

                if isFetchingInfo {
                    ProgressView().scaleEffect(0.7).frame(width: 18, height: 18)
                } else if !urlText.isEmpty {
                    Button { urlText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(AppTheme.textMuted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.bgTertiary)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                        !urlText.isEmpty ? AppTheme.accent.opacity(0.4) : AppTheme.cardBorder
                    ))
            )

            if platform == .spotify {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(AppTheme.accent)
                    Text("Links do Spotify usam busca automática no YouTube Music para evitar erros de DRM.")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 4)
            } else if platform == .search && !urlText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(AppTheme.textMuted)
                    Text("Isso será tratado como um termo de busca.")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    private func previewCard(title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(AppTheme.bgTertiary).frame(width: 60, height: 40)
                Image(systemName: platform.icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.font(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                Label(platform.rawValue, systemImage: platform.icon)
                    .font(AppTheme.font(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.success)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.success.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.success.opacity(0.2)))
        )
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(AppTheme.warning)
            Text(msg).font(AppTheme.font(size: 11)).foregroundColor(AppTheme.warning)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Formato", systemImage: "square.stack.3d.up")
                .font(AppTheme.font(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 10) {
                ForEach(MediaFormat.allCases) { fmt in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedFormat = fmt }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: fmt.icon)
                            Text(fmt.rawValue)
                        }
                        .font(AppTheme.font(size: 12, weight: selectedFormat == fmt ? .semibold : .regular))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            Capsule().fill(selectedFormat == fmt
                                ? AppTheme.accent
                                : AppTheme.bgTertiary)
                        )
                        .foregroundColor(selectedFormat == fmt ? .white : AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Qualidade", systemImage: "dial.high")
                .font(AppTheme.font(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MediaQuality.allCases) { q in
                        Button {
                            selectedQuality = q
                        } label: {
                            Text(q.rawValue)
                                .font(AppTheme.font(size: 11, weight: selectedQuality == q ? .semibold : .regular))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(
                                    selectedQuality == q ? AppTheme.accent.opacity(0.18) : AppTheme.bgTertiary
                                ))
                                .foregroundColor(selectedQuality == q ? AppTheme.accent : AppTheme.textSecondary)
                                .overlay(Capsule().strokeBorder(
                                    selectedQuality == q ? AppTheme.accent.opacity(0.4) : Color.clear
                                ))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Destino", systemImage: "folder")
                .font(AppTheme.font(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            Toggle("Usar pasta personalizada", isOn: $useCustomDestination)
                .toggleStyle(.switch).tint(AppTheme.accent)
                .font(AppTheme.font(size: 12))

            if useCustomDestination {
                HStack {
                    TextField("Caminho", text: $customDestination)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTheme.font(size: 12))
                    Button("Escolher...") { chooseFolder() }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(AppTheme.font(size: 11)).foregroundColor(AppTheme.textMuted)
                    Text(manager.settings.defaultDestination)
                        .font(AppTheme.font(size: 11)).foregroundColor(AppTheme.textMuted)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    // MARK: - Actions

    @State private var fetchDebounceTask: Task<Void, Never>? = nil

    private func fetchInfoDebounced() {
        fetchedTitle = nil
        fetchedThumbnail = nil
        fetchError = nil
        fetchDebounceTask?.cancel()
        guard isValidURL else { return }

        fetchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s debounce
            guard !Task.isCancelled else { return }

            await MainActor.run { isFetchingInfo = true }

            let ytDlpPath = manager.settings.ytDlpPath
            let ffmpegPath = manager.settings.ffmpegPath

            guard !ytDlpPath.isEmpty else {
                await MainActor.run {
                    fetchError = "yt-dlp não configurado. Configure em Ajustes."
                    isFetchingInfo = false
                }
                return
            }

            let service = YtDlpService(ytDlpPath: ytDlpPath, ffmpegPath: ffmpegPath)
            do {
                let info = try await service.fetchInfo(url: urlText)
                await MainActor.run {
                    fetchedTitle     = info.title
                    fetchedThumbnail = info.thumbnailURL
                    isFetchingInfo   = false
                }
            } catch {
                await MainActor.run {
                    fetchError = error.localizedDescription
                    isFetchingInfo = false
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            customDestination = url.path
        }
    }

    private func addDownload() {
        manager.addSocialDownload(
            url: urlText,
            title: fetchedTitle ?? urlText,
            platform: platform,
            format: selectedFormat,
            quality: selectedQuality,
            destination: destination
        )
        dismiss()
    }
}

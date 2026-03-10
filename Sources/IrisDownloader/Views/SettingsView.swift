import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager

    @State private var defaultDestination: String = ""
    @State private var maxConcurrent: Int = 2
    @State private var rclonePath: String = ""
    @State private var remoteName: String = ""
    @State private var showNotifications: Bool = true
    @State private var bandwidthLimit: String = "0"
    @State private var autoRetryEnabled: Bool = true
    @State private var maxRetries: Int = 3
    @State private var uploadTransfers: Int = 8
    @State private var driveChunkSize: String = "128M"
    @State private var historyRetentionDays: Int = 0
    @State private var preserveDriveStructure: Bool = true
    @State private var saved: Bool = false
    @State private var showAddAccount = false
    @State private var saveTask: Task<Void, Never>?
    @State private var remoteToDelete: String?
    @State private var showDeleteConfirm = false

    private let speedOptions = [
        ("Sem limite", "0"),
        ("10 MB/s", "10M"),
        ("25 MB/s", "25M"),
        ("50 MB/s", "50M"),
        ("100 MB/s", "100M"),
        ("200 MB/s", "200M")
    ]

    private let chunkOptions = [
        ("8 MB (padrão rclone)", "8M"),
        ("32 MB", "32M"),
        ("64 MB", "64M"),
        ("128 MB (recomendado)", "128M"),
        ("256 MB (máximo)", "256M")
    ]

    private let retentionOptions = [
        ("Sem limite", 0),
        ("7 dias", 7),
        ("30 dias", 30),
        ("60 dias", 60),
        ("90 dias", 90),
        ("180 dias", 180),
        ("1 ano", 365)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Rclone status card
                rcloneStatusCard

                // Destination
                settingsCard(title: "Destino Padrão", icon: "folder.fill") {
                    HStack {
                        TextField("Pasta padrão", text: $defaultDestination)
                            .textFieldStyle(.roundedBorder)
                            .font(AppTheme.font(size: 13))

                        Button("Escolher...") {
                            chooseFolder()
                        }
                    }
                }

                // Downloads
                settingsCard(title: "Downloads", icon: "arrow.down.circle") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Downloads simultâneos")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Stepper("\(maxConcurrent)", value: $maxConcurrent, in: 1...5)
                                .frame(width: 120)
                        }

                        Divider().background(AppTheme.cardBorder)

                        HStack {
                            Text("Limite de velocidade")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Picker("", selection: $bandwidthLimit) {
                                ForEach(speedOptions, id: \.1) { option in
                                    Text(option.0).tag(option.1)
                                }
                            }
                            .frame(width: 140)
                        }

                        Divider().background(AppTheme.cardBorder)

                        Toggle(isOn: $showNotifications) {
                            Text("Notificações ao concluir")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .tint(AppTheme.accent)

                        Divider().background(AppTheme.cardBorder)

                        Toggle(isOn: $autoRetryEnabled) {
                            Text("Auto-retry em falhas")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .tint(AppTheme.accent)

                        if autoRetryEnabled {
                            HStack {
                                Text("Máximo de tentativas")
                                    .font(AppTheme.font(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Stepper("\(maxRetries)", value: $maxRetries, in: 1...10)
                                    .frame(width: 120)
                            }
                        }

                        Divider().background(AppTheme.cardBorder)

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: $preserveDriveStructure) {
                                Text("Preservar estrutura de pastas")
                                    .font(AppTheme.font(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .tint(AppTheme.accent)

                            Text("Cria subpasta com o nome da pasta do Drive no destino")
                                .font(AppTheme.font(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.leading, 2)
                        }
                    }
                }

                // Upload settings
                settingsCard(title: "Uploads", icon: "arrow.up.circle") {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transferências paralelas")
                                    .font(AppTheme.font(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text("Arquivos enviados ao mesmo tempo")
                                    .font(AppTheme.font(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Spacer()
                            Stepper("\(uploadTransfers)", value: $uploadTransfers, in: 1...16)
                                .frame(width: 120)
                        }

                        Divider().background(AppTheme.cardBorder)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tamanho de chunk")
                                    .font(AppTheme.font(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text("Chunks maiores = uploads mais rápidos para vídeos")
                                    .font(AppTheme.font(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Spacer()
                            Picker("", selection: $driveChunkSize) {
                                ForEach(chunkOptions, id: \.1) { option in
                                    Text(option.0).tag(option.1)
                                }
                            }
                            .frame(width: 200)
                        }
                    }
                }

                // History retention
                settingsCard(title: "Histórico", icon: "clock") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Retenção do histórico")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Entradas mais antigas serão removidas automaticamente")
                                .font(AppTheme.font(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                        Picker("", selection: $historyRetentionDays) {
                            ForEach(retentionOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                        .frame(width: 130)
                    }
                }

                // Remote selector
                settingsCard(title: "Contas Google Drive", icon: "person.circle") {
                    VStack(spacing: 12) {
                        if manager.availableRemotes.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.warning)
                                Text("Nenhuma conta conectada")
                                    .font(AppTheme.font(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                            }
                        } else {
                            ForEach(manager.availableRemotes, id: \.self) { remote in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(remoteName == remote ? AppTheme.accent : AppTheme.textMuted)
                                    Text(remote)
                                        .font(AppTheme.font(size: 13, weight: remoteName == remote ? .semibold : .regular))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    if remoteName == remote {
                                        Text("Ativa")
                                            .font(AppTheme.font(size: 10, weight: .bold))
                                            .foregroundColor(AppTheme.success)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(AppTheme.success.opacity(0.15)))
                                    } else {
                                        Button("Usar") {
                                            remoteName = remote
                                        }
                                        .font(AppTheme.font(size: 11))
                                        .buttonStyle(.plain)
                                        .foregroundColor(AppTheme.accent)
                                    }

                                    Button {
                                        remoteToDelete = remote
                                        showDeleteConfirm = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(AppTheme.font(size: 11))
                                            .foregroundColor(AppTheme.error.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remover conta")
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Divider().background(AppTheme.cardBorder)

                        HStack {
                            Button(action: { showAddAccount = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Adicionar Conta Google")
                                }
                                .font(AppTheme.font(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button("Redetectar") {
                                manager.detectRclone()
                                loadSettings()
                            }
                            .font(AppTheme.font(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
                .sheet(isPresented: $showAddAccount) {
                    AddAccountView()
                        .environmentObject(manager)
                        .onDisappear {
                            manager.refreshRemotes()
                            loadSettings()
                        }
                }
                .alert("Remover conta?", isPresented: $showDeleteConfirm) {
                    Button("Remover", role: .destructive) {
                        if let name = remoteToDelete {
                            deleteRemote(name)
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    if let name = remoteToDelete {
                        Text("A conta \"\(name)\" será removida do rclone. Isso não afeta seus arquivos no Google Drive.")
                    }
                }

                // Updates
                settingsCard(title: "Atualizações", icon: "arrow.down.app") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Versão atual")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text(AppSettings.appVersion)
                                .font(AppTheme.font(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        Divider().background(AppTheme.cardBorder)

                        if let update = manager.updateAvailable {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppTheme.info)
                                Text("Versão \(update.version) disponível!")
                                    .font(AppTheme.font(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.info)
                                Spacer()
                                Button {
                                    NSWorkspace.shared.open(update.downloadURL)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(AppTheme.font(size: 11))
                                        Text("Baixar")
                                            .font(AppTheme.font(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(AppTheme.info))
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack {
                                if manager.isCheckingForUpdate {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(AppTheme.accent)
                                    Text("Verificando...")
                                        .font(AppTheme.font(size: 12))
                                        .foregroundColor(AppTheme.textMuted)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.success)
                                    Text("Você está na versão mais recente")
                                        .font(AppTheme.font(size: 12))
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Spacer()

                                Button("Verificar atualizações") {
                                    manager.checkForUpdates()
                                }
                                .font(AppTheme.font(size: 11))
                                .buttonStyle(.plain)
                                .foregroundColor(AppTheme.accent)
                                .disabled(manager.isCheckingForUpdate)
                            }
                        }
                    }
                }

                // Auto-save indicator
                if saved {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Salvo!")
                        }
                        .foregroundColor(AppTheme.success)
                        .font(AppTheme.font(size: 13, weight: .medium))
                        .transition(.opacity)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bgPrimary)
        .onAppear { loadSettings() }
        .onChange(of: defaultDestination) { _, _ in autoSave() }
        .onChange(of: maxConcurrent) { _, _ in autoSave() }
        .onChange(of: remoteName) { _, _ in autoSave() }
        .onChange(of: showNotifications) { _, _ in autoSave() }
        .onChange(of: bandwidthLimit) { _, _ in autoSave() }
        .onChange(of: autoRetryEnabled) { _, _ in autoSave() }
        .onChange(of: maxRetries) { _, _ in autoSave() }
        .onChange(of: uploadTransfers) { _, _ in autoSave() }
        .onChange(of: driveChunkSize) { _, _ in autoSave() }
        .onChange(of: historyRetentionDays) { _, _ in autoSave() }
        .onChange(of: preserveDriveStructure) { _, _ in autoSave() }
    }

    private var rcloneStatusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(manager.rcloneInstalled ? AppTheme.success.opacity(0.15) : AppTheme.error.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: manager.rcloneInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(AppTheme.font(size: 20))
                    .foregroundColor(manager.rcloneInstalled ? AppTheme.success : AppTheme.error)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(manager.rcloneInstalled ? "rclone instalado" : "rclone não encontrado")
                    .font(AppTheme.font(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(manager.rcloneInstalled ? manager.rcloneVersion : "Instale com: brew install rclone")
                    .font(AppTheme.font(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(manager.rcloneInstalled ? AppTheme.success.opacity(0.3) : AppTheme.error.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.accent)
                Text(title)
                    .font(AppTheme.font(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func loadSettings() {
        let s = manager.settings
        defaultDestination = s.defaultDestination
        maxConcurrent = s.maxConcurrentDownloads
        rclonePath = s.rclonePath
        remoteName = s.rcloneRemoteName
        showNotifications = s.showNotifications
        bandwidthLimit = s.bandwidthLimit
        autoRetryEnabled = s.autoRetryEnabled
        maxRetries = s.maxRetries
        uploadTransfers = s.uploadTransfers
        driveChunkSize = s.driveChunkSize
        historyRetentionDays = s.historyRetentionDays
        preserveDriveStructure = s.preserveDriveStructure
    }

    private func autoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s debounce
            guard !Task.isCancelled else { return }

            let newSettings = AppSettings(
                defaultDestination: defaultDestination,
                maxConcurrentDownloads: maxConcurrent,
                rclonePath: rclonePath,
                rcloneRemoteName: remoteName,
                showNotifications: showNotifications,
                bandwidthLimit: bandwidthLimit,
                hasCompletedOnboarding: manager.settings.hasCompletedOnboarding,
                availableRemotes: manager.availableRemotes,
                lastUpdateCheck: manager.settings.lastUpdateCheck,
                autoRetryEnabled: autoRetryEnabled,
                maxRetries: maxRetries,
                uploadTransfers: uploadTransfers,
                driveChunkSize: driveChunkSize,
                historyRetentionDays: historyRetentionDays,
                preserveDriveStructure: preserveDriveStructure
            )
            manager.updateSettings(newSettings)

            withAnimation { saved = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                withAnimation { saved = false }
            }
        }
    }

    private func deleteRemote(_ name: String) {
        let _ = RcloneDetector.deleteRemote(rclonePath: manager.settings.rclonePath, name: name)
        manager.refreshRemotes()
        // If we deleted the active remote, switch to the first available
        if remoteName == name {
            remoteName = manager.availableRemotes.first ?? ""
            autoSave()
        }
        loadSettings()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Escolha a pasta padrão de destino"
        if panel.runModal() == .OK, let url = panel.url {
            defaultDestination = url.path
        }
    }
}

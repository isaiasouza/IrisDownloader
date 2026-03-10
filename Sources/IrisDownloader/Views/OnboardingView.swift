import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var currentStep = 0
    @State private var defaultDestination: String = ""
    @State private var selectedRemote: String = ""
    @State private var showAddAccount = false

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(AppTheme.font(size: 48))
                    .foregroundStyle(AppTheme.progressGradient)
                    .padding(.top, 30)

                Text("Iris Downloader")
                    .font(AppTheme.font(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Baixe pastas do Google Drive sem compactar")
                    .font(AppTheme.font(size: 14))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.bottom, 24)

            // Steps
            Group {
                switch currentStep {
                case 0:
                    stepRcloneCheck
                case 1:
                    stepChooseRemote
                case 2:
                    stepChooseDestination
                default:
                    stepReady
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            Spacer()

            // Progress dots & navigation
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<4) { step in
                        Circle()
                            .fill(step == currentStep ? AppTheme.accent : AppTheme.bgTertiary)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentStep)
                    }
                }

                HStack {
                    if currentStep > 0 {
                        Button("Voltar") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: nextStep) {
                        HStack(spacing: 6) {
                            Text(currentStep == 3 ? "Começar" : "Próximo")
                            Image(systemName: currentStep == 3 ? "checkmark" : "arrow.right")
                                .font(AppTheme.font(size: 12))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(canProceed ? AppTheme.accent : AppTheme.bgTertiary))
                        .foregroundColor(canProceed ? .white : AppTheme.textMuted)
                        .font(AppTheme.font(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canProceed)
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 480)
        .background(AppTheme.bgSecondary)
        .onAppear {
            defaultDestination = manager.settings.defaultDestination
            manager.detectRclone()
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView()
                .environmentObject(manager)
                .onDisappear {
                    manager.refreshRemotes()
                    if selectedRemote.isEmpty, let first = manager.availableRemotes.first {
                        selectedRemote = first
                    }
                }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return manager.rcloneInstalled
        case 1: return !selectedRemote.isEmpty
        case 2: return !defaultDestination.isEmpty
        default: return true
        }
    }

    private func nextStep() {
        if currentStep == 3 {
            // Save and complete
            var newSettings = manager.settings
            newSettings.rcloneRemoteName = selectedRemote
            newSettings.defaultDestination = defaultDestination
            newSettings.hasCompletedOnboarding = true
            manager.updateSettings(newSettings)
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        }
    }

    // MARK: - Steps

    private var stepRcloneCheck: some View {
        VStack(spacing: 16) {
            settingCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(manager.rcloneInstalled ? AppTheme.success.opacity(0.15) : AppTheme.error.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: manager.rcloneInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(AppTheme.font(size: 22))
                            .foregroundColor(manager.rcloneInstalled ? AppTheme.success : AppTheme.error)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.rcloneInstalled ? "rclone encontrado!" : "rclone não encontrado")
                            .font(AppTheme.font(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(manager.rcloneInstalled ? manager.rcloneVersion : "Instale com: brew install rclone")
                            .font(AppTheme.font(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    Spacer()

                    Button("Verificar") {
                        manager.detectRclone()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accent)
                    .font(AppTheme.font(size: 13))
                }
            }

            if !manager.rcloneInstalled {
                Text("O rclone é necessário para baixar arquivos do Google Drive.\nAbra o Terminal e execute:\nbrew install rclone && rclone config")
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var stepChooseRemote: some View {
        VStack(spacing: 16) {
            if manager.availableRemotes.isEmpty {
                settingCard {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(AppTheme.font(size: 28))
                            .foregroundColor(AppTheme.accent)
                        Text("Conecte sua conta Google")
                            .font(AppTheme.font(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Faça login para acessar seus arquivos do Drive")
                            .font(AppTheme.font(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)

                        Button(action: { showAddAccount = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                Text("Conectar Google Drive")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppTheme.accent))
                            .foregroundColor(.white)
                            .font(AppTheme.font(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                Text("Selecione a conta do Google Drive")
                    .font(AppTheme.font(size: 14))
                    .foregroundColor(AppTheme.textSecondary)

                ForEach(manager.availableRemotes, id: \.self) { remote in
                    settingCard {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(AppTheme.font(size: 20))
                                .foregroundColor(selectedRemote == remote ? AppTheme.accent : AppTheme.textMuted)

                            Text(remote)
                                .font(AppTheme.font(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            if selectedRemote == remote {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation { selectedRemote = remote }
                    }
                }
                Button(action: { showAddAccount = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("Adicionar outra conta")
                    }
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if selectedRemote.isEmpty, let first = manager.availableRemotes.first {
                selectedRemote = first
            }
        }
    }

    private var stepChooseDestination: some View {
        VStack(spacing: 16) {
            Text("Onde salvar os downloads?")
                .font(AppTheme.font(size: 14))
                .foregroundColor(AppTheme.textSecondary)

            settingCard {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(AppTheme.accent)

                    Text(defaultDestination)
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Alterar") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            defaultDestination = url.path
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accent)
                    .font(AppTheme.font(size: 13))
                }
            }
        }
    }

    private var stepReady: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(AppTheme.font(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.success)
            }

            Text("Tudo pronto!")
                .font(AppTheme.font(size: 20, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 8) {
                infoRow(icon: "person.circle", text: "Conta: \(selectedRemote)")
                infoRow(icon: "folder", text: "Destino: \(defaultDestination)")
            }
        }
    }

    // MARK: - Helpers

    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
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

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

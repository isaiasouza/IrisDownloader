import SwiftUI

struct AddAccountView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var accountName: String = ""
    @State private var authState: AuthState = .idle
    @State private var statusMessage: String = ""
    @State private var authProcess: Process?
    @State private var useFullAccess: Bool = true

    enum AuthState {
        case idle
        case authorizing
        case success
        case failed
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.badge.plus")
                        .font(AppTheme.font(size: 28))
                        .foregroundColor(AppTheme.accent)
                }

                Text("Conectar Google Drive")
                    .font(AppTheme.font(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Faça login com sua conta Google")
                    .font(AppTheme.font(size: 13))
                    .foregroundColor(AppTheme.textMuted)
            }

            switch authState {
            case .idle:
                idleView
            case .authorizing:
                authorizingView
            case .success:
                successView
            case .failed:
                failedView
            }

            Spacer()

            // Bottom buttons
            HStack {
                Button("Cancelar") {
                    cancelAuth()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)
                .keyboardShortcut(.escape)

                Spacer()

                switch authState {
                case .idle:
                    Button(action: startAuth) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                            Text("Abrir Login Google")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(accountName.isEmpty ? AppTheme.bgTertiary : AppTheme.accent))
                        .foregroundColor(accountName.isEmpty ? AppTheme.textMuted : .white)
                        .font(AppTheme.font(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(accountName.isEmpty)

                case .success:
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Concluir")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.success))
                        .foregroundColor(.white)
                        .font(AppTheme.font(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return)

                case .failed:
                    Button(action: { authState = .idle }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Tentar Novamente")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppTheme.accent))
                        .foregroundColor(.white)
                        .font(AppTheme.font(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                case .authorizing:
                    EmptyView()
                }
            }
        }
        .padding(28)
        .frame(width: 480, height: 420)
        .background(AppTheme.bgSecondary)
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nome da conta")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                TextField("Ex: meu-drive, trabalho, cliente...", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.font(size: 13))
                    .onChange(of: accountName) { _, newValue in
                        // Clean name: only lowercase, numbers, hyphens
                        let cleaned = newValue
                            .lowercased()
                            .replacingOccurrences(of: " ", with: "-")
                            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        if cleaned != newValue {
                            accountName = cleaned
                        }
                    }

                Text("Esse nome identifica a conta no app")
                    .font(AppTheme.font(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissão")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Picker("", selection: $useFullAccess) {
                    Text("Leitura e escrita (download + upload)").tag(true)
                    Text("Somente leitura (apenas download)").tag(false)
                }
                .pickerStyle(.radioGroup)
                .font(AppTheme.font(size: 12))
            }

            infoCard(
                icon: "info.circle",
                text: "Ao clicar em \"Abrir Login Google\", seu navegador abrirá a página de autenticação do Google. Autorize o acesso e volte para o app."
            )
        }
    }

    private var authorizingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.accent)

            Text("Aguardando autorização...")
                .font(AppTheme.font(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Text(statusMessage)
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)

            infoCard(
                icon: "globe",
                text: "Complete o login no navegador. Se a página não abriu automaticamente, verifique seu navegador."
            )
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark.circle.fill")
                    .font(AppTheme.font(size: 28))
                    .foregroundColor(AppTheme.success)
            }

            Text("Conta conectada!")
                .font(AppTheme.font(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text("A conta \"\(accountName)\" foi adicionada com sucesso.")
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.error.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "xmark.circle.fill")
                    .font(AppTheme.font(size: 28))
                    .foregroundColor(AppTheme.error)
            }

            Text("Falha na autorização")
                .font(AppTheme.font(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text(statusMessage)
                .font(AppTheme.font(size: 12))
                .foregroundColor(AppTheme.error)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }

    // MARK: - Helpers

    private func infoCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(AppTheme.font(size: 14))
                .foregroundColor(AppTheme.accent)
                .padding(.top, 1)

            Text(text)
                .font(AppTheme.font(size: 12))
                .foregroundColor(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppTheme.accent.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Actions

    private func startAuth() {
        guard !accountName.isEmpty else { return }

        withAnimation { authState = .authorizing }
        statusMessage = "Abrindo navegador..."

        authProcess = RcloneDetector.authorizeGoogleDrive(
            rclonePath: manager.settings.rclonePath,
            onStatusUpdate: { message in
                statusMessage = message
            },
            completion: { result in
                switch result {
                case .success(let token):
                    let scope = useFullAccess ? "drive" : "drive.readonly"
                    let created = RcloneDetector.createRemote(
                        rclonePath: manager.settings.rclonePath,
                        name: accountName,
                        token: token,
                        scope: scope
                    )

                    if created {
                        manager.refreshRemotes()
                        // Auto-select the new remote
                        var newSettings = manager.settings
                        newSettings.rcloneRemoteName = accountName
                        manager.updateSettings(newSettings)

                        withAnimation { authState = .success }
                    } else {
                        statusMessage = "Conta autorizada mas falhou ao salvar a configuração."
                        withAnimation { authState = .failed }
                    }

                case .failure(let error):
                    statusMessage = error.localizedDescription
                    withAnimation { authState = .failed }
                }
            }
        )
    }

    private func cancelAuth() {
        if let process = authProcess, process.isRunning {
            process.terminate()
        }
        authProcess = nil
    }
}

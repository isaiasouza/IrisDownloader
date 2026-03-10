import SwiftUI

struct AddDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var linksText: String = ""
    @State private var useCustomDestination: Bool = false
    @State private var customDestination: String = ""
    @State private var selectedRemote: String = ""
    @State private var showDuplicateAlert: Bool = false
    @State private var duplicateLinks: [(link: String, parsed: ParsedDriveLink)] = []
    @State private var showSelectiveDownload: Bool = false

    private var validLinks: [(link: String, parsed: ParsedDriveLink)] {
        linksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                if let parsed = GoogleDriveLinkParser.parse(line) {
                    return (line, parsed)
                }
                return nil
            }
    }

    private var totalLines: Int {
        linksText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    private var validCount: Int { validLinks.count }
    private var hasInput: Bool { totalLines > 0 }

    /// If there's exactly one valid folder link, enable selective download
    private var singleFolderLink: ParsedDriveLink? {
        guard validLinks.count == 1, validLinks.first?.parsed.isFolder == true else { return nil }
        return validLinks.first?.parsed
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(AppTheme.font(size: 24))
                    .foregroundColor(AppTheme.accent)
                Text("Novo Download")
                    .font(AppTheme.font(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            // Link input
            VStack(alignment: .leading, spacing: 8) {
                Text("Links do Google Drive (um por linha)")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                TextEditor(text: $linksText)
                    .font(AppTheme.font(size: 13, design: .monospaced))
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.bgTertiary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(AppTheme.cardBorder)
                            )
                    )

                if hasInput {
                    HStack(spacing: 6) {
                        if validCount > 0 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                            Text("\(validCount) link(s) válido(s)")
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.success)
                        }
                        if validCount < totalLines {
                            if validCount > 0 {
                                Text("·")
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.error)
                            Text("\(totalLines - validCount) inválido(s)")
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.error)
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: validCount)
                }
            }

            // Remote selector (multiple accounts)
            if manager.availableRemotes.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conta Google Drive")
                        .font(AppTheme.font(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("Remote", selection: $selectedRemote) {
                        ForEach(manager.availableRemotes, id: \.self) { remote in
                            Text(remote).tag(remote)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Destination
            VStack(alignment: .leading, spacing: 8) {
                Text("Destino")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Toggle("Usar pasta personalizada", isOn: $useCustomDestination)
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)

                if useCustomDestination {
                    HStack {
                        TextField("Caminho", text: $customDestination)
                            .textFieldStyle(.roundedBorder)
                            .font(AppTheme.font(size: 13))

                        Button("Escolher...") {
                            chooseFolder()
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Text(manager.settings.defaultDestination)
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)

                Spacer()

                if singleFolderLink != nil {
                    Button {
                        showSelectiveDownload = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checklist")
                            Text("Escolher Arquivos")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(AppTheme.info.opacity(0.15))
                        )
                        .foregroundColor(AppTheme.info)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: addDownloads) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(validCount > 1 ? "Adicionar (\(validCount) links)" : "Adicionar")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(validCount > 0 ? AppTheme.accent : AppTheme.bgTertiary)
                    )
                    .foregroundColor(validCount > 0 ? .white : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .disabled(validCount == 0)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
        .background(AppTheme.bgSecondary)
        .sheet(isPresented: $showSelectiveDownload) {
            if let folder = singleFolderLink {
                SelectiveDownloadView(
                    folderDriveID: folder.id,
                    destinationPath: useCustomDestination ? customDestination : manager.settings.defaultDestination,
                    remoteName: selectedRemote
                )
                .environmentObject(manager)
                .onDisappear { dismiss() }
            }
        }
        .alert("Duplicado detectado", isPresented: $showDuplicateAlert) {
            Button("Baixar mesmo assim") {
                forceAddDuplicates()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\(duplicateLinks.count) link(s) já existe(m) na fila ou no histórico. Deseja baixar novamente?")
        }
        .onAppear {
            selectedRemote = manager.settings.rcloneRemoteName
            if let clipboard = NSPasteboard.general.string(forType: .string),
               GoogleDriveLinkParser.parse(clipboard) != nil {
                linksText = clipboard
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Escolha a pasta de destino"

        if panel.runModal() == .OK, let url = panel.url {
            customDestination = url.path
        }
    }

    private func addDownloads() {
        let dest = useCustomDestination ? customDestination : nil
        var dupes: [(link: String, parsed: ParsedDriveLink)] = []

        for (link, parsed) in validLinks {
            let result = manager.addDownload(link: link, destinationPath: dest, remoteName: selectedRemote)
            if result == .duplicateActive || result == .duplicateHistory {
                dupes.append((link, parsed))
            }
        }

        if !dupes.isEmpty {
            duplicateLinks = dupes
            showDuplicateAlert = true
        } else {
            dismiss()
        }
    }

    private func forceAddDuplicates() {
        let dest = useCustomDestination ? customDestination : nil
        for (link, _) in duplicateLinks {
            manager.addDownload(link: link, destinationPath: dest, remoteName: selectedRemote, force: true)
        }
        dismiss()
    }
}

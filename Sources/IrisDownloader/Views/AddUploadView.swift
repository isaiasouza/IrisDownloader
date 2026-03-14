import SwiftUI

struct AddUploadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var localPaths: [String] = []
    @State private var driveLink: String = ""
    @State private var driveFolderID: String = ""
    @State private var driveFolderName: String = ""
    @State private var isLinkValid: Bool = false
    @State private var linkInfo: String = ""
    @State private var totalFileInfo: String = ""
    @State private var isDragOver = false
    @State private var showDriveBrowser = false
    @State private var showDuplicateAlert = false
    @State private var duplicatePaths: [String] = []
    @State private var showNewDriveFolder = false
    @State private var newDriveFolderName = ""
    @State private var isCreatingFolder = false
    @State private var folderCreateError: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(AppTheme.font(size: 24))
                    .foregroundColor(AppTheme.success)
                Text("Novo Upload")
                    .font(AppTheme.font(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            // File/Folder selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Arquivos ou pastas para enviar")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragOver ? AppTheme.accent.opacity(0.1) : AppTheme.bgTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isDragOver ? AppTheme.accent : AppTheme.cardBorder,
                                    style: StrokeStyle(lineWidth: isDragOver ? 2 : 1, dash: [6])
                                )
                        )
                        .frame(minHeight: 80, maxHeight: localPaths.count > 3 ? 140 : 80)

                    if localPaths.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(AppTheme.font(size: 20))
                                .foregroundColor(AppTheme.textMuted)
                            Text("Arraste aqui ou clique para escolher")
                                .font(AppTheme.font(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(localPaths, id: \.self) { path in
                                    HStack(spacing: 8) {
                                        Image(systemName: isDirectory(path) ? "folder.fill" : "doc.fill")
                                            .font(AppTheme.font(size: 14))
                                            .foregroundColor(AppTheme.accent)

                                        Text((path as NSString).lastPathComponent)
                                            .font(AppTheme.font(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            removePath(path)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(AppTheme.font(size: 12))
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .onTapGesture {
                    chooseFiles()
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    handleFileDrop(providers)
                }

                if !totalFileInfo.isEmpty {
                    Text(totalFileInfo)
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            // Drive destination
            VStack(alignment: .leading, spacing: 8) {
                Text("Pasta de destino no Google Drive")
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                // Show selected folder if browsed
                if !driveFolderName.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppTheme.accent)
                        Text(driveFolderName)
                            .font(AppTheme.font(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            driveFolderID = ""
                            driveFolderName = ""
                            isLinkValid = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.accent.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AppTheme.accent.opacity(0.2)))
                    )
                    .contextMenu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNewDriveFolder = true
                            }
                        } label: {
                            Label("Nova Pasta", systemImage: "folder.badge.plus")
                        }
                    }

                    // New Folder inline UI
                    if showNewDriveFolder {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(AppTheme.accent)
                                .font(AppTheme.font(size: 14))

                            TextField("Nome da nova pasta...", text: $newDriveFolderName)
                                .textFieldStyle(.roundedBorder)
                                .font(AppTheme.font(size: 12))
                                .onSubmit { createDriveFolder() }

                            if isCreatingFolder {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                            } else {
                                Button(action: createDriveFolder) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.success)
                                }
                                .buttonStyle(.plain)
                                .disabled(newDriveFolderName.trimmingCharacters(in: .whitespaces).isEmpty)

                                Button {
                                    showNewDriveFolder = false
                                    newDriveFolderName = ""
                                    folderCreateError = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        if let err = folderCreateError {
                            Text(err)
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.error)
                        }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNewDriveFolder = true
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.badge.plus")
                                Text("Nova Pasta")
                            }
                            .font(AppTheme.font(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: { showDriveBrowser = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.gearshape")
                            Text("Navegar no Drive")
                        }
                        .font(AppTheme.font(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                        .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)

                    Text("ou")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)

                    TextField("Cole o link da pasta...", text: $driveLink)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTheme.font(size: 12))
                        .onChange(of: driveLink) { _, newValue in
                            validateDriveLink(newValue)
                        }
                }

                if !linkInfo.isEmpty && driveFolderName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: isLinkValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isLinkValid ? AppTheme.success : AppTheme.error)
                        Text(linkInfo)
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(isLinkValid ? AppTheme.success : AppTheme.error)
                    }
                }
            }
            .sheet(isPresented: $showDriveBrowser) {
                DriveBrowserView { folderID, folderName in
                    driveFolderID = folderID
                    driveFolderName = folderName
                    isLinkValid = true
                    driveLink = ""
                    linkInfo = ""
                }
                .environmentObject(manager)
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

                Button(action: startUpload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(localPaths.count > 1 ? "Enviar (\(localPaths.count) itens)" : "Enviar")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(canUpload ? AppTheme.success : AppTheme.bgTertiary)
                    )
                    .foregroundColor(canUpload ? .white : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .disabled(!canUpload)
            }
        }
        .padding(24)
        .frame(width: 520, height: 480)
        .background(AppTheme.bgSecondary)
        .alert("Duplicado detectado", isPresented: $showDuplicateAlert) {
            Button("Enviar mesmo assim") {
                forceAddDuplicates()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("\(duplicatePaths.count) item(ns) já existe(m) na fila ou no histórico. Deseja enviar novamente?")
        }
    }

    private var canUpload: Bool {
        !localPaths.isEmpty && isLinkValid
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Escolha os arquivos ou pastas para enviar"

        if panel.runModal() == .OK {
            let newPaths = panel.urls.map { $0.path }
            addPaths(newPaths)
        }
    }

    private func addPaths(_ paths: [String]) {
        for path in paths {
            if !localPaths.contains(path) {
                localPaths.append(path)
            }
        }
        updateFileInfo()
    }

    private func removePath(_ path: String) {
        localPaths.removeAll { $0 == path }
        updateFileInfo()
    }

    private func updateFileInfo() {
        guard !localPaths.isEmpty else {
            totalFileInfo = ""
            return
        }

        let service = RcloneService(
            rclonePath: manager.settings.rclonePath,
            remoteName: manager.settings.rcloneRemoteName
        )

        var totalBytes: Int64 = 0
        var totalCount = 0
        for path in localPaths {
            let info = service.getLocalSize(path: path)
            totalBytes += info.bytes
            totalCount += info.count
        }

        let sizeStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        totalFileInfo = "\(localPaths.count) item(ns) · \(totalCount) arquivo(s) · \(sizeStr)"
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            addPaths([url.path])
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private func validateDriveLink(_ input: String) {
        if let parsed = GoogleDriveLinkParser.parse(input) {
            isLinkValid = true
            linkInfo = "Pasta detectada (ID: \(parsed.id.prefix(20))...)"
        } else if input.isEmpty {
            isLinkValid = false
            linkInfo = ""
        } else {
            isLinkValid = false
            linkInfo = "Link inválido - use o link de uma pasta do Google Drive"
        }
    }

    private func startUpload() {
        let link: String
        if !driveFolderID.isEmpty {
            link = driveFolderID
        } else {
            link = driveLink
        }
        var dupes: [String] = []
        for path in localPaths {
            Task {
                let result = await manager.addUpload(localPath: path, driveLink: link)
                if result == .duplicateActive || result == .duplicateHistory {
                    dupes.append(path)
                }
            }
        }

        if !dupes.isEmpty {
            duplicatePaths = dupes
            showDuplicateAlert = true
        } else {
            dismiss()
        }
    }

    private func forceAddDuplicates() {
        let link: String
        if !driveFolderID.isEmpty {
            link = driveFolderID
        } else {
            link = driveLink
        }
        for path in duplicatePaths {
            Task {
                await manager.addUpload(localPath: path, driveLink: link, force: true)
            }
        }
        dismiss()
    }

    private func createDriveFolder() {
        let name = newDriveFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreatingFolder = true
        folderCreateError = nil

        let parentID = driveFolderID
        let remote = manager.settings.rcloneRemoteName
        let rclonePath = manager.settings.rclonePath

        Task {
            do {
                let service = RcloneService(rclonePath: rclonePath, remoteName: remote)
                let newID = try await service.createFolder(name: name, parentID: parentID)

                await MainActor.run {
                    driveFolderName = "\(driveFolderName)/\(name)"
                    driveFolderID = newID
                    newDriveFolderName = ""
                    showNewDriveFolder = false
                    isCreatingFolder = false
                }
            } catch {
                await MainActor.run {
                    folderCreateError = "Erro ao criar pasta: \(error.localizedDescription)"
                    isCreatingFolder = false
                }
            }
        }
    }
}

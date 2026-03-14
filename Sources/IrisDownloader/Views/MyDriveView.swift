import SwiftUI

enum DriveMode: String, CaseIterable {
    case myDrive      = "Meu Drive"
    case sharedWithMe = "Compartilhados"
    case sharedDrives = "Drives"
}

struct MyDriveView: View {
    @EnvironmentObject var manager: DownloadManager

    @State private var breadcrumb: [(id: String, name: String)] = []
    @State private var items: [DriveItem] = []
    @State private var selectedIDs: Set<String> = []
    @State private var selectedRemote: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var driveMode: DriveMode = .myDrive
    @State private var searchText: String = ""
    @State private var dropTargetFolderID: String? = nil
    @State private var isDropTargetingContent = false
    @State private var uploadFeedback: String? = nil
    
    // New folder states
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var targetParentIDForNewFolder: String? = nil // nil means current folder
    @State private var isCreatingFolder = false

    private var currentFolderID: String? {
        breadcrumb.last?.id
    }

    private var filteredItems: [DriveItem] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedItems: [DriveItem] {
        filteredItems.filter { selectedIDs.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: account selector + refresh
            toolbarBar

            Divider().background(AppTheme.cardBorder)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(AppTheme.font(size: 13))
                    .foregroundColor(searchText.isEmpty ? AppTheme.textMuted : AppTheme.accent)
                TextField("Pesquisar por nome...", text: $searchText)
                    .font(AppTheme.font(size: 13))
                    .textFieldStyle(.plain)
                    .foregroundColor(AppTheme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTheme.font(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.bgTertiary)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AppTheme.cardBorder))
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // Breadcrumb
            breadcrumbBar
                .padding(.vertical, 8)

            // Selection bar
            if !isLoading && errorMessage == nil && !filteredItems.isEmpty {
                selectionBar
            }

            Divider().background(AppTheme.cardBorder)

            // Content
            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.accent)
                    Text("Carregando arquivos...")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AppTheme.font(size: 32))
                        .foregroundColor(AppTheme.error)
                    Text(error)
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Tentar novamente") {
                        Task { await loadContents() }
                    }
                    .font(AppTheme.font(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accent)
                }
                Spacer()
            } else if items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(AppTheme.font(size: 32))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Pasta vazia")
                        .font(AppTheme.font(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(AppTheme.font(size: 32))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Nenhum resultado para \"\(searchText)\"")
                        .font(AppTheme.font(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else {
                ZStack {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredItems) { item in
                                itemRow(item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargetingContent) { providers in
                        guard let folderID = currentFolderID else { return false }
                        handleLocalDrop(providers, targetFolderID: folderID)
                        return true
                    }
                    .contextMenu {
                        Button {
                            promptForNewFolder(parentID: currentFolderID)
                        } label: {
                            Label("Nova Pasta", systemImage: "folder.badge.plus")
                        }
                        
                        Divider()
                        
                        Button {
                            Task { await loadContents() }
                        } label: {
                            Label("Atualizar", systemImage: "arrow.clockwise")
                        }
                    }

                    // Overlay quando arrasta arquivo sobre a área de conteúdo
                    if isDropTargetingContent, let folderID = currentFolderID {
                        let folderName = breadcrumb.last?.name ?? "esta pasta"
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(AppTheme.success, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.success.opacity(0.06)))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.up.to.line.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.success)
                                    Text("Soltar para enviar para")
                                        .font(AppTheme.font(size: 13))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text(folderName)
                                        .font(AppTheme.font(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            )
                            .padding(16)
                            .allowsHitTesting(false)
                            .id(folderID)
                    }
                }
            }

            // Feedback toast de upload
            if let msg = uploadFeedback {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    Text(msg)
                        .font(AppTheme.font(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.bgTertiary))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 4)
            }

            Divider().background(AppTheme.cardBorder)

            // Footer: download button
            footerBar
        }
        .background(AppTheme.bgPrimary)
        .onAppear {
            if selectedRemote.isEmpty {
                selectedRemote = manager.settings.rcloneRemoteName
            }
        }
        .task(id: selectedRemote) {
            guard !selectedRemote.isEmpty else { return }
            breadcrumb.removeAll()
            selectedIDs.removeAll()
            await loadContents()
        }
        .alert("Nova Pasta", isPresented: $showingNewFolderAlert) {
            TextField("Nome da pasta", text: $newFolderName)
            Button("Cancelar", role: .cancel) {
                newFolderName = ""
                targetParentIDForNewFolder = nil
            }
            Button("Criar") {
                createNewFolder()
            }
            .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Digite o nome para a nova pasta no Google Drive.")
        }
    }

    // MARK: - Toolbar

    private var toolbarBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if manager.availableRemotes.count > 1 {
                    Picker("Conta", selection: $selectedRemote) {
                        ForEach(manager.availableRemotes, id: \.self) { remote in
                            Text(remote).tag(remote)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    .font(AppTheme.font(size: 12))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppTheme.accent)
                        Text(selectedRemote)
                            .font(AppTheme.font(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }

                Spacer()

                Button {
                    Task { await loadContents() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Atualizar")
                .disabled(isLoading)
            }

            // Drive mode picker
            Picker("Modo", selection: $driveMode) {
                ForEach(DriveMode.allCases, id: \.self) { mode in
                    let icon: String = {
                        switch mode {
                        case .myDrive:      return "externaldrive.fill"
                        case .sharedWithMe: return "person.2.fill"
                        case .sharedDrives: return "building.2.fill"
                        }
                    }()
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: driveMode) { _, _ in
                breadcrumb.removeAll()
                selectedIDs.removeAll()
                Task { await loadContents() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                breadcrumbButton(name: {
                    switch driveMode {
                    case .myDrive:      return "Meu Drive"
                    case .sharedWithMe: return "Compartilhados"
                    case .sharedDrives: return "Drives"
                    }
                }(), id: nil)

                ForEach(Array(breadcrumb.enumerated()), id: \.element.id) { _, crumb in
                    Image(systemName: "chevron.right")
                        .font(AppTheme.font(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                    breadcrumbButton(name: crumb.name, id: crumb.id)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func breadcrumbButton(name: String, id: String?) -> some View {
        Button {
            navigateTo(id: id)
        } label: {
            Text(name)
                .font(AppTheme.font(size: 11, weight: .medium))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(AppTheme.accent.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button("Selecionar Todos") {
                selectedIDs = Set(filteredItems.map { $0.id })
            }
            .font(AppTheme.font(size: 11, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.accent)

            Button("Desmarcar") {
                selectedIDs.removeAll()
            }
            .font(AppTheme.font(size: 11, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.textMuted)

            Spacer()

            Text("\(filteredItems.count) itens")
                .font(AppTheme.font(size: 11))
                .foregroundColor(AppTheme.textMuted)

            if !selectedItems.isEmpty {
                Text("· \(selectedItems.count) selecionado(s) (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                    .font(AppTheme.font(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Item Row

    private func itemRow(_ item: DriveItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        let isDropTarget = dropTargetFolderID == item.id

        return HStack(spacing: 10) {
            // Folder/file icon
            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .font(AppTheme.font(size: 14))
                .foregroundColor(item.isFolder
                    ? (isDropTarget ? AppTheme.success : AppTheme.warning)
                    : AppTheme.info)

            // Name — click navigates into folder
            Button {
                if item.isFolder {
                    navigateInto(item)
                } else {
                    toggleSelection(item)
                }
            } label: {
                Text(item.name)
                    .font(AppTheme.font(size: 13))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if !item.isFolder {
                Text(item.sizeFormatted)
                    .font(AppTheme.font(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
            }

            // Quick upload button (folders only) — abre file picker
            if item.isFolder {
                Button {
                    pickFilesForUpload(targetFolderID: item.id, folderName: item.name)
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.success.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Enviar arquivos para \"\(item.name)\"")
            }

            // Quick download button (files only)
            if !item.isFolder {
                Button {
                    downloadItem(item)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.accent.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Baixar \"\(item.name)\"")
            }

            if item.isFolder {
                Image(systemName: isDropTarget ? "arrow.up.to.line" : "chevron.right")
                    .font(AppTheme.font(size: 10))
                    .foregroundColor(isDropTarget ? AppTheme.success : AppTheme.textMuted)
            }

            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(AppTheme.font(size: 16))
                .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textMuted)
                .onTapGesture {
                    toggleSelection(item)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isDropTarget
                        ? AppTheme.success.opacity(0.10)
                        : isSelected ? AppTheme.accent.opacity(0.08) : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isDropTarget ? AppTheme.success.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        // Drag & drop de arquivos locais PARA esta pasta do Drive
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { dropTargetFolderID == item.id },
            set: { dropTargetFolderID = $0 ? item.id : nil }
        )) { providers in
            handleLocalDrop(providers, targetFolderID: item.id)
            return true
        }
        .contextMenu {
            if item.isFolder {
                Button {
                    navigateInto(item)
                } label: {
                    Label("Abrir", systemImage: "folder.fill")
                }
                
                Button {
                    promptForNewFolder(parentID: item.id)
                } label: {
                    Label("Nova Pasta Aqui", systemImage: "folder.badge.plus")
                }
            } else {
                Button {
                    downloadItem(item)
                } label: {
                    Label("Baixar", systemImage: "arrow.down.circle")
                }
            }
            
            Divider()
            
            Button {
                toggleSelection(item)
            } label: {
                Label(isSelected ? "Desmarcar" : "Selecionar", systemImage: isSelected ? "circle.slash" : "checkmark.circle")
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if !selectedItems.isEmpty {
                Text("\(selectedItems.count) selecionado(s) — \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                    .font(AppTheme.font(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }

            Spacer()

            Button(action: downloadSelected) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Baixar Selecionados (\(selectedItems.count))")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selectedItems.isEmpty ? AppTheme.bgTertiary : AppTheme.accent)
                )
                .foregroundColor(selectedItems.isEmpty ? AppTheme.textMuted : .white)
                .font(AppTheme.font(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Navigation

    private func navigateInto(_ folder: DriveItem) {
        breadcrumb.append((id: folder.id, name: folder.name))
        selectedIDs.removeAll()
        Task { await loadContents() }
    }

    private func navigateTo(id: String?) {
        if id == nil {
            // Root
            breadcrumb.removeAll()
        } else if let idx = breadcrumb.firstIndex(where: { $0.id == id }) {
            breadcrumb = Array(breadcrumb.prefix(through: idx))
        }
        selectedIDs.removeAll()
        Task { await loadContents() }
    }

    private func toggleSelection(_ item: DriveItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    // MARK: - Load Contents

    private func loadContents() async {
        isLoading = true
        errorMessage = nil
        items = []

        let service = RcloneService(
            rclonePath: manager.settings.rclonePath,
            remoteName: selectedRemote
        )

        do {
            let result: [DriveItem]
            switch driveMode {
            case .myDrive:
                if let folderID = currentFolderID {
                    result = try await service.listContents(driveID: folderID)
                } else {
                    result = try await service.listRootContents()
                }
            case .sharedWithMe:
                if let folderID = currentFolderID {
                    // Bug fix: subpastas de itens compartilhados não usam --drive-shared-with-me
                    result = try await service.listContents(driveID: folderID)
                } else {
                    result = try await service.listSharedWithMe()
                }
            case .sharedDrives:
                if let folderID = currentFolderID {
                    result = try await service.listContents(driveID: folderID)
                } else {
                    // Nível raiz: mostra a lista de Drives Compartilhados como pastas
                    let drives = try await service.listSharedDrives()
                    items = drives.map { drive in
                        DriveItem(id: drive.id, name: drive.name, path: drive.id, size: 0, isFolder: true)
                    }
                    isLoading = false
                    return
                }
            }
            items = result.sorted { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            isLoading = false
        } catch {
            errorMessage = "Falha ao listar arquivos: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Drag & Drop Upload

    private func handleLocalDrop(_ providers: [NSItemProvider], targetFolderID: String) {
        var count = 0
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    let link = "https://drive.google.com/drive/folders/\(targetFolderID)"
                    Task { @MainActor in
                        _ = await self.manager.addUpload(
                            localPath: url.path,
                            driveLink: link,
                            remoteName: self.selectedRemote,
                            force: true
                        )
                    }
                }
                count += 1
            }
        }
        if count > 0 {
            showUploadFeedback(count == 1 ? "Upload adicionado à fila" : "\(count) uploads adicionados à fila")
        }
    }

    private func pickFilesForUpload(targetFolderID: String, folderName: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Escolha arquivos ou pastas para enviar para \"\(folderName)\""
        guard panel.runModal() == .OK else { return }
        let link = "https://drive.google.com/drive/folders/\(targetFolderID)"
        var count = 0
        for url in panel.urls {
            Task {
                _ = await manager.addUpload(
                    localPath: url.path,
                    driveLink: link,
                    remoteName: selectedRemote,
                    force: true
                )
            }
            count += 1
        }
        if count > 0 {
            showUploadFeedback(count == 1 ? "Upload adicionado à fila" : "\(count) uploads adicionados à fila")
        }
    }

    // MARK: - New Folder Logic

    private func promptForNewFolder(parentID: String?) {
        targetParentIDForNewFolder = parentID
        newFolderName = ""
        showingNewFolderAlert = true
    }

    private func createNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        // Se targetParentIDForNewFolder é nil, cria na pasta atual
        let parentID = targetParentIDForNewFolder ?? currentFolderID ?? "root"
        
        isLoading = true
        isCreatingFolder = true
        
        let service = RcloneService(
            rclonePath: manager.settings.rclonePath,
            remoteName: selectedRemote
        )
        
        Task {
            do {
                _ = try await service.createFolder(name: name, parentID: parentID)
                await MainActor.run {
                    isLoading = false
                    isCreatingFolder = false
                    targetParentIDForNewFolder = nil
                    newFolderName = ""
                    Task { await loadContents() }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erro ao criar pasta: \(error.localizedDescription)"
                    isLoading = false
                    isCreatingFolder = false
                }
            }
        }
    }

    private func showUploadFeedback(_ message: String) {
        withAnimation { uploadFeedback = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { uploadFeedback = nil }
        }
    }

    // MARK: - Download

    private func downloadItem(_ item: DriveItem) {
        let destination = manager.settings.defaultDestination
        let link = item.isFolder
            ? "https://drive.google.com/drive/folders/\(item.id)"
            : "https://drive.google.com/file/d/\(item.id)/view"
        manager.addDownload(link: link, destinationPath: destination, remoteName: selectedRemote, force: true)
    }

    private func downloadSelected() {
        let destination = manager.settings.defaultDestination
        for item in selectedItems {
            if item.isFolder {
                let link = "https://drive.google.com/drive/folders/\(item.id)"
                manager.addDownload(link: link, destinationPath: destination, remoteName: selectedRemote, force: true)
            } else {
                let link = "https://drive.google.com/file/d/\(item.id)/view"
                manager.addDownload(link: link, destinationPath: destination, remoteName: selectedRemote, force: true)
            }
        }
        selectedIDs.removeAll()
    }
}

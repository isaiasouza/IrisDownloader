import SwiftUI

enum DriveMode: String, CaseIterable {
    case myDrive = "Meu Drive"
    case sharedWithMe = "Compartilhados"
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
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
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
                    HStack(spacing: 4) {
                        Image(systemName: mode == .myDrive ? "externaldrive.fill" : "person.2.fill")
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
                breadcrumbButton(name: driveMode == .myDrive ? "Meu Drive" : "Compartilhados", id: nil)

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
        return HStack(spacing: 10) {
            // Folder/file icon
            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .font(AppTheme.font(size: 14))
                .foregroundColor(item.isFolder ? AppTheme.warning : AppTheme.info)

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

            if item.isFolder {
                Image(systemName: "chevron.right")
                    .font(AppTheme.font(size: 10))
                    .foregroundColor(AppTheme.textMuted)
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
                .fill(isSelected ? AppTheme.accent.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
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
                    result = try await service.listSharedContents(driveID: folderID)
                } else {
                    result = try await service.listSharedWithMe()
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

    // MARK: - Download

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

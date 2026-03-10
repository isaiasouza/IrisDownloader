import SwiftUI

struct DriveFolder: Identifiable {
    let id: String
    let name: String
    let modTime: String
}

struct DriveBrowserView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    var remoteName: String?  // nil = use default from settings
    let onSelect: (String, String) -> Void  // (folderID, folderName)

    @State private var folders: [DriveFolder] = []
    @State private var breadcrumb: [(id: String, name: String)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentFolderID: String = "root"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(AppTheme.accent)
                Text("Escolher pasta no Drive")
                    .font(AppTheme.font(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(16)

            // Breadcrumb
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    breadcrumbButton(name: "Meu Drive", id: "root")

                    ForEach(Array(breadcrumb.enumerated()), id: \.element.id) { index, crumb in
                        Image(systemName: "chevron.right")
                            .font(AppTheme.font(size: 9))
                            .foregroundColor(AppTheme.textMuted)
                        breadcrumbButton(name: crumb.name, id: crumb.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            Divider().background(AppTheme.cardBorder)

            // Folder list
            if isLoading {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("Carregando pastas...")
                        .font(AppTheme.font(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(AppTheme.font(size: 24))
                        .foregroundColor(AppTheme.warning)
                    Text(error)
                        .font(AppTheme.font(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else if folders.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(AppTheme.font(size: 24))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Nenhuma subpasta")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(folders) { folder in
                            folderRow(folder)
                        }
                    }
                    .padding(8)
                }
            }

            Divider().background(AppTheme.cardBorder)

            // Bottom bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pasta selecionada:")
                        .font(AppTheme.font(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Text(breadcrumb.last?.name ?? "Meu Drive")
                        .font(AppTheme.font(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()

                Button("Cancelar") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)

                Button(action: selectCurrent) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Selecionar")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.accent))
                    .foregroundColor(.white)
                    .font(AppTheme.font(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 460, height: 450)
        .background(AppTheme.bgSecondary)
        .onAppear {
            loadFolders(parentID: "root")
        }
    }

    private func breadcrumbButton(name: String, id: String) -> some View {
        Button(action: {
            navigateTo(id: id, name: name)
        }) {
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

    private func folderRow(_ folder: DriveFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(AppTheme.font(size: 16))
                .foregroundColor(AppTheme.accent.opacity(0.7))

            Text(folder.name)
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTheme.font(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            navigateInto(folder: folder)
        }
    }

    private func navigateInto(folder: DriveFolder) {
        breadcrumb.append((id: folder.id, name: folder.name))
        currentFolderID = folder.id
        loadFolders(parentID: folder.id)
    }

    private func navigateTo(id: String, name: String) {
        if id == "root" {
            breadcrumb.removeAll()
        } else if let idx = breadcrumb.firstIndex(where: { $0.id == id }) {
            breadcrumb = Array(breadcrumb.prefix(through: idx))
        }
        currentFolderID = id
        loadFolders(parentID: id)
    }

    private func selectCurrent() {
        let id = currentFolderID
        let name = breadcrumb.last?.name ?? "Meu Drive"
        onSelect(id, name)
        dismiss()
    }

    private func loadFolders(parentID: String) {
        isLoading = true
        errorMessage = nil
        folders = []

        let rclonePath = manager.settings.rclonePath
        let remoteName = self.remoteName ?? manager.settings.rcloneRemoteName

        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: rclonePath)

            var args = [
                "lsjson",
                "\(remoteName):",
                "--dirs-only"
            ]

            if parentID != "root" {
                args += ["--drive-root-folder-id", parentID]
            }

            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()

                // Read pipe BEFORE waitUntilExit to avoid deadlock
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0,
                   let jsonData = output.data(using: .utf8),
                   let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    let parsed = items.compactMap { item -> DriveFolder? in
                        guard let name = item["Name"] as? String,
                              let id = item["ID"] as? String else { return nil }
                        let modTime = (item["ModTime"] as? String) ?? ""
                        return DriveFolder(id: id, name: name, modTime: modTime)
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    DispatchQueue.main.async {
                        folders = parsed
                        isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        errorMessage = "Erro ao listar pastas"
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

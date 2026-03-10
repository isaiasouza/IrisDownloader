import SwiftUI

struct SelectiveDownloadView: View {
    @EnvironmentObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    let folderDriveID: String
    let destinationPath: String
    let remoteName: String

    @State private var items: [DriveItem] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var selectedItems: [DriveItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.badge.questionmark")
                    .font(AppTheme.font(size: 20))
                    .foregroundColor(AppTheme.accent)
                Text("Escolher Arquivos")
                    .font(AppTheme.font(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.accent)
                    Text("Listando arquivos da pasta...")
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
                }
                Spacer()
            } else {
                // Select all / Deselect all
                HStack(spacing: 12) {
                    Button("Selecionar Todos") {
                        selectedIDs = Set(items.map { $0.id })
                    }
                    .font(AppTheme.font(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accent)

                    Button("Desmarcar Todos") {
                        selectedIDs.removeAll()
                    }
                    .font(AppTheme.font(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.textMuted)

                    Spacer()

                    Text("\(items.count) itens")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                Divider().background(AppTheme.cardBorder)

                // File list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { item in
                            fileRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            Divider().background(AppTheme.cardBorder)

            // Footer
            HStack {
                if !selectedItems.isEmpty {
                    Text("\(selectedItems.count) selecionado(s) — \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                        .font(AppTheme.font(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }

                Spacer()

                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)

                Button(action: downloadSelected) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Baixar Selecionados")
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 480)
        .background(AppTheme.bgSecondary)
        .task {
            await loadContents()
        }
    }

    private func fileRow(_ item: DriveItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(AppTheme.font(size: 16))
                .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textMuted)

            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .font(AppTheme.font(size: 14))
                .foregroundColor(item.isFolder ? AppTheme.warning : AppTheme.info)

            Text(item.name)
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if !item.isFolder {
                Text(item.sizeFormatted)
                    .font(AppTheme.font(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppTheme.accent.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
    }

    private func loadContents() async {
        let service = RcloneService(
            rclonePath: manager.settings.rclonePath,
            remoteName: remoteName
        )
        do {
            let result = try await service.listContents(driveID: folderDriveID)
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

    private func downloadSelected() {
        for item in selectedItems {
            if item.isFolder {
                // Folder items use their ID as drive root
                let link = "https://drive.google.com/drive/folders/\(item.id)"
                manager.addDownload(link: link, destinationPath: destinationPath, remoteName: remoteName, force: true)
            } else {
                let link = "https://drive.google.com/file/d/\(item.id)/view"
                manager.addDownload(link: link, destinationPath: destinationPath, remoteName: remoteName, force: true)
            }
        }
        dismiss()
    }
}

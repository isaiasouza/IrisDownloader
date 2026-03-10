import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var copiedItemId: UUID? = nil
    @State private var searchText: String = ""
    @State private var statusFilter: HistoryFilter = .all
    @State private var logItem: DownloadItem? = nil
    @State private var expandedItems: Set<UUID> = Set()

    enum HistoryFilter: String, CaseIterable {
        case all = "Todos"
        case completed = "Concluídos"
        case failed = "Falhos"
        case downloads = "Downloads"
        case uploads = "Uploads"
    }

    private var filteredHistory: [DownloadItem] {
        manager.history.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.driveName.localizedCaseInsensitiveContains(searchText) ||
                item.remoteName.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch statusFilter {
            case .all: matchesFilter = true
            case .completed: matchesFilter = item.status == .completed
            case .failed: matchesFilter = item.status == .failed || item.status == .cancelled
            case .downloads: matchesFilter = item.transferType == .download
            case .uploads: matchesFilter = item.transferType == .upload
            }

            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        Group {
            if manager.history.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Toolbar
                    VStack(spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(AppTheme.font(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                                TextField("Buscar...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(AppTheme.font(size: 12))
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(AppTheme.font(size: 10))
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppTheme.bgTertiary)
                            )

                            Button(action: { manager.clearHistory() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(AppTheme.font(size: 11))
                                    Text("Limpar")
                                        .font(AppTheme.font(size: 12, weight: .medium))
                                }
                                .foregroundColor(AppTheme.error)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 6) {
                            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        statusFilter = filter
                                    }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(AppTheme.font(size: 10, weight: statusFilter == filter ? .bold : .medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(statusFilter == filter ? AppTheme.accent.opacity(0.15) : AppTheme.bgTertiary)
                                        )
                                        .foregroundColor(statusFilter == filter ? AppTheme.accent : AppTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Text("\(filteredHistory.count) de \(manager.history.count)")
                                .font(AppTheme.font(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()
                        .background(AppTheme.cardBorder)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredHistory) { item in
                                historyRow(item)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .padding(16)
                    }
                    .animation(.spring(response: 0.3), value: filteredHistory.count)
                }
            }
        }
        .background(AppTheme.bgPrimary)
        .sheet(item: $logItem) { item in
            TransferLogView(item: item)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.textMuted.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock")
                    .font(AppTheme.font(size: 36))
                    .foregroundColor(AppTheme.textMuted)
            }
            Text("Sem histórico")
                .font(AppTheme.font(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Downloads concluídos aparecerão aqui")
                .font(AppTheme.font(size: 13))
                .foregroundColor(AppTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.bgPrimary)
    }

    private func historyRow(_ item: DownloadItem) -> some View {
        let isExpanded = expandedItems.contains(item.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(AppTheme.statusColor(for: item.status).opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: item.status.systemImage(for: item.transferType))
                        .font(AppTheme.font(size: 14))
                        .foregroundColor(AppTheme.statusColor(for: item.status))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.driveName)
                        .font(AppTheme.font(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if item.transferType == .upload {
                            Text("Upload")
                                .font(AppTheme.font(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.success)
                        }

                        if !item.remoteName.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "person.circle")
                                    .font(AppTheme.font(size: 9))
                                Text(item.remoteName)
                                    .font(AppTheme.font(size: 10))
                            }
                            .foregroundColor(AppTheme.textMuted)
                        }

                        Text(item.totalBytesFormatted)
                            .font(AppTheme.font(size: 11, design: .monospaced))

                        if let date = item.dateCompleted {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTheme.font(size: 11))
                        }
                    }
                    .foregroundColor(AppTheme.textMuted)

                    if let error = item.errorMessage, !isExpanded {
                        Text(error)
                            .font(AppTheme.font(size: 10))
                            .foregroundColor(AppTheme.error)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedItems.contains(item.id) {
                                expandedItems.remove(item.id)
                            } else {
                                expandedItems.insert(item.id)
                            }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.font(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if !item.transferLog.isEmpty {
                        Button {
                            logItem = item
                        } label: {
                            Image(systemName: "doc.text")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.info)
                        }
                        .buttonStyle(.plain)
                        .help("Ver log")
                    }

                    if item.status == .completed && item.transferType == .upload,
                       let link = item.shareLink {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(link, forType: .string)
                            copiedItemId = item.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if copiedItemId == item.id {
                                    copiedItemId = nil
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: copiedItemId == item.id ? "checkmark" : "link")
                                    .font(AppTheme.font(size: 11))
                                Text(copiedItemId == item.id ? "Copiado!" : "Copiar Link")
                                    .font(AppTheme.font(size: 10, weight: .medium))
                            }
                            .foregroundColor(copiedItemId == item.id ? AppTheme.success : AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Copiar link de compartilhamento")
                    }

                    // Copiar link original do Drive (para downloads concluídos)
                    if item.status == .completed && item.transferType == .download {
                        let driveLink = GoogleDriveLinkParser.makeLink(driveID: item.driveID, isFolder: item.isFolder)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(driveLink, forType: .string)
                            copiedItemId = item.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if copiedItemId == item.id { copiedItemId = nil }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: copiedItemId == item.id ? "checkmark" : "link")
                                    .font(AppTheme.font(size: 11))
                                Text(copiedItemId == item.id ? "Copiado!" : "Link Drive")
                                    .font(AppTheme.font(size: 10, weight: .medium))
                            }
                            .foregroundColor(copiedItemId == item.id ? AppTheme.success : AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Copiar link original do Google Drive")
                    }

                    if item.status == .completed {
                        Button {
                            manager.openInFinder(item)
                        } label: {
                            Image(systemName: "folder")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Abrir no Finder")
                    }

                    if item.status == .failed || item.status == .cancelled {
                        Button {
                            manager.retryDownload(item)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(AppTheme.font(size: 13))
                                .foregroundColor(AppTheme.warning)
                        }
                        .buttonStyle(.plain)
                        .help("Tentar novamente")
                    }

                    Button {
                        manager.removeFromHistory(item)
                    } label: {
                        Image(systemName: "xmark")
                            .font(AppTheme.font(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Remover")
                }
            }

            // Expanded metadata section
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .background(AppTheme.cardBorder)
                        .padding(.vertical, 4)

                    historyDetailRow(icon: "folder", label: "Destino", value: item.destinationPath)

                    if item.totalFiles > 0 {
                        historyDetailRow(icon: "doc.on.doc",
                                         label: "Arquivos",
                                         value: "\(item.filesTransferred) de \(item.totalFiles) · \(item.totalBytesFormatted)")
                    }

                    historyDetailRow(icon: "calendar",
                                     label: "Início",
                                     value: item.dateAdded.formatted(date: .abbreviated, time: .shortened))

                    if let completed = item.dateCompleted {
                        historyDetailRow(icon: "calendar.badge.checkmark",
                                         label: "Conclusão",
                                         value: completed.formatted(date: .abbreviated, time: .shortened))

                        let duration = completed.timeIntervalSince(item.dateAdded)
                        historyDetailRow(icon: "timer",
                                         label: "Duração",
                                         value: formatDuration(duration))
                    }

                    if let error = item.errorMessage {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(AppTheme.font(size: 10))
                                .foregroundColor(AppTheme.error)
                            Text(error)
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.error)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 44) // align with text content
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func historyDetailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppTheme.font(size: 10))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 14)
            Text(label)
                .font(AppTheme.font(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.font(size: 11))
                .foregroundColor(AppTheme.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

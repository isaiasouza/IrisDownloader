import SwiftUI

struct DownloadRowView: View {
    @ObservedObject var item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onOpenFinder: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var linkCopied = false
    @State private var showCancelConfirm = false

    private var hasFileDetails: Bool {
        item.isFolder || item.totalFiles > 1 || !item.transferringFiles.isEmpty || !item.completedFileNames.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 10) {
                // Icon with pulse animation when downloading
                ZStack {
                    Circle()
                        .fill(AppTheme.statusColor(for: item.status).opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: item.transferType == .upload
                        ? "arrow.up.doc.fill"
                        : (item.isFolder ? "folder.fill" : "doc.fill"))
                        .font(AppTheme.font(size: 16))
                        .foregroundColor(AppTheme.statusColor(for: item.status))
                }
                .scaleEffect(item.status == .downloading ? (isHovering ? 1.05 : 1.0) : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: item.status == .downloading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.driveName)
                        .font(AppTheme.font(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !item.remoteName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(AppTheme.font(size: 9))
                            Text(item.remoteName)
                                .font(AppTheme.font(size: 10))
                        }
                        .foregroundColor(AppTheme.textMuted)
                    }

                    if !item.currentFileName.isEmpty && item.status == .downloading && !isExpanded {
                        Text(item.currentFileName)
                            .font(AppTheme.font(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                            .transition(.opacity)
                    }

                    if item.retryCount > 0 && !item.status.isFinished {
                        Text("Tentativa \(item.retryCount + 1)")
                            .font(AppTheme.font(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.warning)
                    }
                }

                Spacer()

                statusBadge
            }

            // Progress section
            if item.status == .downloading || item.status == .paused {
                VStack(spacing: 6) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(IrisProgressStyle())

                    HStack(spacing: 0) {
                        Text("\(item.transferredBytesFormatted) / \(item.totalBytesFormatted)")
                            .font(AppTheme.font(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)

                        if !item.speed.isEmpty && item.status == .downloading {
                            Text("  ·  ")
                                .foregroundColor(AppTheme.textMuted)
                            Text(item.speed)
                                .font(AppTheme.font(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.accent)
                        }

                        if !item.eta.isEmpty && item.status == .downloading {
                            Text("  ·  ")
                                .foregroundColor(AppTheme.textMuted)
                            Text(item.eta)
                                .font(AppTheme.font(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        if item.totalFiles > 0 {
                            Text("\(item.filesTransferred)/\(item.totalFiles)")
                                .font(AppTheme.font(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textMuted)
                            Image(systemName: "doc")
                                .font(AppTheme.font(size: 9))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.leading, 2)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Expandable file details toggle
            if hasFileDetails && !item.status.isFinished {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.font(size: 9, weight: .bold))

                        if !item.transferringFiles.isEmpty {
                            Text("\(item.transferringFiles.count) transferindo")
                                .font(AppTheme.font(size: 11, weight: .medium))
                        }

                        if !item.completedFileNames.isEmpty {
                            if !item.transferringFiles.isEmpty {
                                Text("·")
                            }
                            Text("\(item.completedFileNames.count) concluído\(item.completedFileNames.count == 1 ? "" : "s")")
                                .font(AppTheme.font(size: 11, weight: .medium))
                        }

                        if item.transferringFiles.isEmpty && item.completedFileNames.isEmpty {
                            Text("Ver arquivos")
                                .font(AppTheme.font(size: 11, weight: .medium))
                        }

                        Spacer()
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.accent.opacity(0.08))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Expanded per-file list
            if isExpanded && hasFileDetails && !item.status.isFinished {
                expandedFileList
            }

            if item.status == .fetchingInfo {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.accent)
                    Text("Obtendo informações...")
                        .font(AppTheme.font(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            if let error = item.errorMessage {
                Text(error)
                    .font(AppTheme.font(size: 11))
                    .foregroundColor(AppTheme.error)
                    .lineLimit(2)
            }

            // Action buttons
            if !item.status.isFinished {
                HStack(spacing: 12) {
                    Spacer()

                    if item.status == .downloading {
                        actionButton("Pausar", icon: "pause.fill", color: AppTheme.warning) {
                            onPause()
                        }
                    }

                    if item.status == .paused {
                        actionButton("Retomar", icon: "play.fill", color: AppTheme.success) {
                            onResume()
                        }
                    }

                    if item.status == .completed {
                        actionButton("Abrir", icon: "folder", color: AppTheme.info) {
                            onOpenFinder()
                        }
                    }

                    if item.status == .downloading || item.status == .paused || item.status == .queued {
                        actionButton("Cancelar", icon: "xmark", color: AppTheme.error) {
                            if item.status == .queued {
                                onCancel()
                            } else {
                                showCancelConfirm = true
                            }
                        }
                    }
                }
            }

            // Share link button for completed uploads
            if item.status == .completed && item.transferType == .upload && item.shareLink != nil {
                HStack(spacing: 12) {
                    Spacer()
                    copyLinkButton
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? AppTheme.bgTertiary : AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 0.5)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.3), value: item.status)
        .alert("Cancelar transferência?", isPresented: $showCancelConfirm) {
            Button("Cancelar transferência", role: .destructive) {
                onCancel()
            }
            Button("Voltar", role: .cancel) {}
        } message: {
            Text("O progresso de \"\(item.driveName)\" será perdido.")
        }
    }

    private var expandedFileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Currently transferring files
            ForEach(item.transferringFiles) { file in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: item.transferType == .upload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(AppTheme.font(size: 12))
                            .foregroundColor(AppTheme.accent)
                        Text(file.name)
                            .font(AppTheme.font(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(file.percentage))%")
                            .font(AppTheme.font(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.accent)
                    }
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.accent.opacity(0.15))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.accent)
                                    .frame(width: geo.size.width * min(file.percentage / 100.0, 1.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                        Text("\(file.bytesTransferredFormatted) / \(file.sizeFormatted)")
                            .font(AppTheme.font(size: 9, design: .monospaced))
                            .foregroundColor(AppTheme.textMuted)
                            .fixedSize()
                        if !file.speed.isEmpty {
                            Text(file.speed)
                                .font(AppTheme.font(size: 9, design: .monospaced))
                                .foregroundColor(AppTheme.accent.opacity(0.8))
                                .fixedSize()
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.accent.opacity(0.04))
                )
            }

            // Completed files
            if !item.completedFileNames.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(item.completedFileNames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.success)
                            Text(name)
                                .font(AppTheme.font(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var copyLinkButton: some View {
        Button {
            if let link = item.shareLink {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
                linkCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    linkCopied = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: linkCopied ? "checkmark" : "link")
                    .font(AppTheme.font(size: 10))
                Text(linkCopied ? "Copiado!" : "Copiar Link")
                    .font(AppTheme.font(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(linkCopied ? AppTheme.success.opacity(0.12) : AppTheme.accent.opacity(0.12))
            )
            .foregroundColor(linkCopied ? AppTheme.success : AppTheme.accent)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: linkCopied)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: item.status.systemImage(for: item.transferType))
                .font(AppTheme.font(size: 10))
            Text(item.status.displayName(for: item.transferType))
                .font(AppTheme.font(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppTheme.statusColor(for: item.status).opacity(0.15))
        )
        .foregroundColor(AppTheme.statusColor(for: item.status))
    }

    private func actionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(AppTheme.font(size: 10))
                Text(label)
                    .font(AppTheme.font(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }
}

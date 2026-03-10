import SwiftUI
import AppKit

struct TransferLogView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .font(AppTheme.font(size: 16))
                    .foregroundColor(AppTheme.accent)
                Text("Log — \(item.driveName)")
                    .font(AppTheme.font(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(AppTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.bgSecondary)

            Divider().background(AppTheme.cardBorder)

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(item.transferLog.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(AppTheme.font(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: item.transferLog.count) { _, newCount in
                    if autoScroll && newCount > 0 {
                        withAnimation {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .background(AppTheme.bgPrimary)

            Divider().background(AppTheme.cardBorder)

            // Actions
            HStack(spacing: 12) {
                Text("\(item.transferLog.count) linhas")
                    .font(AppTheme.font(size: 11))
                    .foregroundColor(AppTheme.textMuted)

                Spacer()

                Button {
                    copyLog()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(AppTheme.font(size: 11))
                        Text("Copiar")
                            .font(AppTheme.font(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Button {
                    saveLog()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(AppTheme.font(size: 11))
                        Text("Salvar...")
                            .font(AppTheme.font(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Button("Fechar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.bgSecondary)
        }
        .frame(width: 640, height: 420)
    }

    private func copyLog() {
        let text = item.transferLog.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func saveLog() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(item.driveName)-log.txt"
        if panel.runModal() == .OK, let url = panel.url {
            let text = item.transferLog.joined(separator: "\n")
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

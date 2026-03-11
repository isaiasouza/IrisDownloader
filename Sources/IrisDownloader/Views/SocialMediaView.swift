import SwiftUI

struct SocialMediaView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Social Media")
                    .font(AppTheme.font(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Novo Download")
                    }
                    .font(AppTheme.font(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.accent))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().background(AppTheme.cardBorder)

            if manager.socialDownloads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.socialDownloads) { item in
                            SocialDownloadRowView(item: item)
                                .environmentObject(manager)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.bgPrimary)
        .sheet(isPresented: $showAddSheet) {
            AddSocialDownloadView()
                .environmentObject(manager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.1)).frame(width: 72, height: 72)
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text("Nenhum download social")
                    .font(AppTheme.font(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("Cole um link do YouTube, Instagram, TikTok\nou qualquer outra plataforma")
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Adicionar link")
                }
                .font(AppTheme.font(size: 13, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.accent))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

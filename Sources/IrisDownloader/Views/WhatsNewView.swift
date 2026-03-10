import SwiftUI

struct WhatsNewView: View {
    let entry: ChangelogEntry
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: 4) {
                    Text("O Que Há de Novo")
                        .font(AppTheme.font(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Versão \(entry.version) · \(entry.date)")
                        .font(AppTheme.font(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            // Features list
            VStack(spacing: 4) {
                ForEach(entry.features.indices, id: \.self) { i in
                    featureRow(entry.features[i])

                    if i < entry.features.count - 1 {
                        Divider()
                            .background(AppTheme.cardBorder)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // CTA button
            Button(action: onDismiss) {
                Text("Continuar")
                    .font(AppTheme.font(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 20)
        }
        .frame(width: 420)
        .background(AppTheme.bgPrimary)
        .preferredColorScheme(.dark)
    }

    private func featureRow(_ feature: ChangelogFeature) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: feature.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(AppTheme.font(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(feature.description)
                    .font(AppTheme.font(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

import SwiftUI
import CoreText

enum AppTheme {
    // IRIS Media brand colors — warm palette
    static let accent = Color(red: 1.0, green: 0.427, blue: 0.161)          // Orange #FF6D29
    static let accentLight = Color(red: 1.0, green: 0.541, blue: 0.314)     // Light orange #FF8A50
    static let accentDark = Color(red: 0.80, green: 0.337, blue: 0.125)     // Dark orange #CC5620

    static let bgPrimary = Color(red: 0.086, green: 0.075, blue: 0.086)     // #161316
    static let bgSecondary = Color(red: 0.118, green: 0.098, blue: 0.110)   // #1E191C
    static let bgTertiary = Color(red: 0.165, green: 0.133, blue: 0.145)    // #2A2225

    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.729, green: 0.729, blue: 0.729) // #BABABA
    static let textMuted = Color(red: 0.420, green: 0.369, blue: 0.380)     // #6B5E61

    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1.0, green: 0.722, blue: 0.0)           // #FFB800
    static let error = Color(red: 0.95, green: 0.26, blue: 0.21)
    static let info = Color(red: 0.25, green: 0.56, blue: 0.97)

    static let cardBackground = Color(red: 0.118, green: 0.098, blue: 0.110) // #1E191C
    static let cardBorder = Color(red: 0.208, green: 0.176, blue: 0.188)     // #352D30

    static let sidebarBg = Color(red: 0.075, green: 0.067, blue: 0.075)      // #131113

    static let progressGradient = LinearGradient(
        colors: [accent, accentLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func statusColor(for status: DownloadStatus) -> Color {
        switch status {
        case .queued, .fetchingInfo: return textMuted
        case .downloading: return accent
        case .paused: return warning
        case .completed: return success
        case .failed: return error
        case .cancelled: return textMuted
        }
    }

    // MARK: - Neue Montreal Font

    static func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        if design == .monospaced {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold:
            name = "NeueMontreal-Bold"
        case .medium:
            name = "NeueMontreal-Medium"
        case .light, .ultraLight, .thin:
            name = "NeueMontreal-Light"
        default:
            name = "NeueMontreal-Regular"
        }
        return .custom(name, size: size)
    }

    static func registerFonts() {
        let fontNames = ["NeueMontreal-Regular", "NeueMontreal-Medium",
                         "NeueMontreal-Bold", "NeueMontreal-Light"]
        for name in fontNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "otf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

// Custom progress bar style
struct IrisProgressStyle: ProgressViewStyle {
    var height: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppTheme.bgTertiary)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppTheme.progressGradient)
                    .frame(width: max(geo.size.width * fraction, 0), height: height)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: height)
    }
}

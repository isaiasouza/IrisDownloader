import SwiftUI

@main
struct IrisDownloaderApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @State private var showOnboarding = false

    @FocusedBinding(\.showDownloadSheet) private var showDownloadSheet
    @FocusedBinding(\.showUploadSheet) private var showUploadSheet

    init() {
        AppTheme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView {
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                    .environmentObject(downloadManager)
                } else {
                    ContentView()
                        .environmentObject(downloadManager)
                        .frame(minWidth: 700, minHeight: 450)
                }
            }
            .onAppear {
                showOnboarding = !downloadManager.settings.hasCompletedOnboarding
                downloadManager.checkForUpdatesIfNeeded()
                downloadManager.requestNotificationPermission()
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandMenu("Transferências") {
                Button("Novo Download") {
                    showDownloadSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Novo Upload") {
                    showUploadSheet = true
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }

        // Menu bar icon
        MenuBarExtra {
            MenuBarView()
                .environmentObject(downloadManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: downloadManager.isDownloading ? "arrow.down.circle.fill" : "arrow.down.circle")
                .symbolRenderingMode(.hierarchical)

            if downloadManager.isDownloading {
                Text("\(Int(downloadManager.totalProgress * 100))%")
                    .font(AppTheme.font(size: 10, design: .monospaced))

                if !downloadManager.activeSpeed.isEmpty {
                    Text(downloadManager.activeSpeed)
                        .font(AppTheme.font(size: 9, design: .monospaced))
                }
            }
        }
    }
}

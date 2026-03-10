import Foundation
import AppKit
import UserNotifications

@MainActor
final class DownloadManager: ObservableObject {
    @Published var activeDownloads: [DownloadItem] = []
    @Published var history: [DownloadItem] = []
    @Published var settings: AppSettings
    @Published var rcloneInstalled: Bool = false
    @Published var rcloneVersion: String = ""
    @Published var availableRemotes: [String] = []

    // Update state
    @Published var updateAvailable: UpdateInfo? = nil
    @Published var isCheckingForUpdate: Bool = false

    // Disk space warning
    @Published var diskSpaceWarning: String? = nil

    // Duplicate detection
    @Published var duplicateWarning: String? = nil

    // File exists detection
    @Published var fileExistsItem: DownloadItem? = nil

    // Computed for menu bar
    var totalProgress: Double {
        let active = activeDownloads.filter { $0.status == .downloading }
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(0.0) { $0 + $1.progress }
        return total / Double(active.count)
    }

    var isDownloading: Bool {
        activeDownloads.contains { $0.status == .downloading }
    }

    var activeSpeed: String {
        let active = activeDownloads.filter { $0.status == .downloading }
        guard let first = active.first, !first.speed.isEmpty else { return "" }
        return first.speed
    }

    private var processes: [UUID: Process] = [:]
    private var rcloneService: RcloneService
    private let persistence = PersistenceService.shared
    private let updateService = UpdateService()
    private var saveDebounceTask: Task<Void, Never>?

    init() {
        let loadedSettings = PersistenceService.shared.loadSettings()
        self.settings = loadedSettings
        self.rcloneService = RcloneService(
            rclonePath: loadedSettings.rclonePath,
            remoteName: loadedSettings.rcloneRemoteName
        )
        self.rcloneService.bandwidthLimit = loadedSettings.bandwidthLimit
        self.rcloneService.uploadTransfers = loadedSettings.uploadTransfers
        self.rcloneService.driveChunkSize = loadedSettings.driveChunkSize
        self.history = persistence.loadHistory()
        detectRclone()
        purgeOldHistory()
        resumeInterruptedDownloads()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        rcloneService = RcloneService(
            rclonePath: newSettings.rclonePath,
            remoteName: newSettings.rcloneRemoteName
        )
        rcloneService.bandwidthLimit = newSettings.bandwidthLimit
        rcloneService.uploadTransfers = newSettings.uploadTransfers
        rcloneService.driveChunkSize = newSettings.driveChunkSize
        persistence.saveSettings(newSettings)
    }

    // MARK: - Rclone detection

    func detectRclone() {
        if let path = RcloneDetector.findRclone() {
            rcloneInstalled = true
            if path != settings.rclonePath {
                settings.rclonePath = path
                persistence.saveSettings(settings)
                rcloneService = RcloneService(rclonePath: path, remoteName: settings.rcloneRemoteName)
            }
            rcloneVersion = RcloneDetector.getVersion(rclonePath: path) ?? "Instalado"
            refreshRemotes()
        } else {
            rcloneInstalled = false
            rcloneVersion = ""
        }
    }

    func refreshRemotes() {
        let remotes = RcloneDetector.listDriveRemotes(rclonePath: settings.rclonePath)
        availableRemotes = remotes
        settings.availableRemotes = remotes
        persistence.saveSettings(settings)
    }

    // MARK: - History auto-purge

    /// Remove entradas do histórico mais antigas que historyRetentionDays dias (0 = sem limite)
    func purgeOldHistory() {
        let days = settings.historyRetentionDays
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let before = history.count
        history.removeAll { item in
            // Remove se a data de conclusão (ou adição) for anterior ao cutoff
            let refDate = item.dateCompleted ?? item.dateAdded
            return refDate < cutoff
        }
        if history.count != before {
            persistence.saveHistory(history)
        }
    }

    // MARK: - Auto-update

    /// Check for updates if last check was > 24h ago
    func checkForUpdatesIfNeeded() {
        if let lastCheck = settings.lastUpdateCheck,
           Date().timeIntervalSince(lastCheck) < 86400 {
            return
        }
        checkForUpdates()
    }

    /// Force check for updates
    func checkForUpdates() {
        isCheckingForUpdate = true
        let service = updateService
        Task {
            let info = await service.checkForUpdates()
            self.updateAvailable = info
            self.isCheckingForUpdate = false
            self.settings.lastUpdateCheck = Date()
            self.persistence.saveSettings(self.settings)
        }
    }

    /// Dismiss the update banner
    func dismissUpdate() {
        updateAvailable = nil
    }

    /// Mark the current version's What's New as seen — won't show again until next update
    func markWhatsNewSeen() {
        settings.lastSeenVersion = AppSettings.appVersion
        persistence.saveSettings(settings)
    }

    // MARK: - Auto-resume interrupted downloads

    private func resumeInterruptedDownloads() {
        // Load any downloads that were active when the app closed
        let interrupted = persistence.loadActiveDownloads()
        for item in interrupted {
            item.status = .queued
            item.speed = ""
            item.eta = ""
            activeDownloads.append(item)
        }
        if !interrupted.isEmpty {
            processQueue()
        }
    }

    private func saveActiveState() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s debounce
            guard !Task.isCancelled else { return }
            let active = activeDownloads.filter { !$0.status.isFinished }
            persistence.saveActiveDownloads(active)
        }
    }

    /// Save immediately (for critical state changes like completion/cancellation)
    private func saveActiveStateNow() {
        saveDebounceTask?.cancel()
        let active = activeDownloads.filter { !$0.status.isFinished }
        persistence.saveActiveDownloads(active)
    }

    // MARK: - Duplicate detection

    enum AddResult {
        case added
        case duplicateActive
        case duplicateHistory
        case invalidLink
    }

    private func checkDuplicate(driveID: String, destinationPath: String) -> AddResult? {
        if activeDownloads.contains(where: { $0.driveID == driveID && $0.destinationPath == destinationPath }) {
            return .duplicateActive
        }
        if history.contains(where: { $0.driveID == driveID && $0.destinationPath == destinationPath && $0.status == .completed }) {
            return .duplicateHistory
        }
        return nil
    }

    // MARK: - Add download

    @discardableResult
    func addDownload(link: String, destinationPath: String?, remoteName: String? = nil, force: Bool = false) -> AddResult {
        guard let parsed = GoogleDriveLinkParser.parse(link) else { return .invalidLink }

        let dest = destinationPath ?? settings.defaultDestination
        let remote = remoteName ?? settings.rcloneRemoteName

        if !force, let duplicate = checkDuplicate(driveID: parsed.id, destinationPath: dest) {
            if duplicate == .duplicateActive {
                duplicateWarning = "Este arquivo já está na fila de transferências."
            } else {
                duplicateWarning = "Este arquivo já foi baixado anteriormente para este destino."
            }
            return duplicate
        }

        let item = DownloadItem(
            driveID: parsed.id,
            driveName: parsed.id,
            isFolder: parsed.isFolder,
            destinationPath: dest,
            remoteName: remote
        )

        activeDownloads.append(item)
        item.status = .queued
        saveActiveStateNow()

        // Fetch name/size, check disk space, then start
        let service = rcloneServiceFor(remote: remote)
        let driveID = parsed.id
        Task {
            do {
                async let nameTask = service.getName(driveID: driveID)
                async let sizeTask = service.getSize(driveID: driveID)

                let name = try await nameTask
                let sizeResult = try await sizeTask

                item.driveName = name
                if item.totalBytes == 0 {
                    item.totalBytes = sizeResult.bytes
                }
                if item.totalFiles == 0 {
                    item.totalFiles = sizeResult.count
                }
                self.saveActiveState()

                // Check disk space
                if sizeResult.bytes > 0, let warning = self.checkDiskSpace(path: dest, needed: sizeResult.bytes) {
                    item.status = .failed
                    item.errorMessage = warning
                    self.diskSpaceWarning = warning
                    self.moveToHistory(item)
                    self.saveActiveStateNow()
                    return
                }

                // Check if file/folder already exists at destination.
                // When preserveDriveStructure is on, the effective path is dest/name;
                // otherwise rclone copies content flat but we still check dest/name.
                let targetPath = (dest as NSString).appendingPathComponent(name)

                if FileManager.default.fileExists(atPath: targetPath) {
                    self.fileExistsItem = item
                    return  // Wait for user confirmation before processing queue
                }
            } catch {
                // Info fetch failed — rclone stats will fill in data
            }

            self.processQueue()
        }
        return .added
    }

    /// User chose to replace existing file — proceed with download
    func confirmReplaceFile() {
        fileExistsItem = nil
        processQueue()
    }

    /// User chose to skip — cancel the download
    func skipFileExists() {
        if let item = fileExistsItem {
            item.status = .cancelled
            moveToHistory(item)
            saveActiveStateNow()
        }
        fileExistsItem = nil
        processQueue()
    }

    private func checkDiskSpace(path: String, needed: Int64) -> String? {
        // Walk up to the nearest existing directory so resourceValues returns real data
        var checkURL = URL(fileURLWithPath: path)
        while !FileManager.default.fileExists(atPath: checkURL.path) {
            let parent = checkURL.deletingLastPathComponent()
            if parent == checkURL { break }
            checkURL = parent
        }

        guard let values = try? checkURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage,
              available > 0 else {
            // Could not reliably determine available space — skip check
            return nil
        }
        if needed > available {
            let neededStr = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
            let availStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Espaço insuficiente: necessário \(neededStr), disponível \(availStr)"
        }
        return nil
    }

    /// Create an RcloneService for a specific remote name
    private func rcloneServiceFor(remote: String) -> RcloneService {
        let service = RcloneService(rclonePath: settings.rclonePath, remoteName: remote)
        service.bandwidthLimit = settings.bandwidthLimit
        service.uploadTransfers = settings.uploadTransfers
        service.driveChunkSize = settings.driveChunkSize
        return service
    }

    // MARK: - Queue processing

    private func processQueue() {
        let activeCount = activeDownloads.filter { $0.status.isActive }.count
        let slotsAvailable = settings.maxConcurrentDownloads - activeCount

        guard slotsAvailable > 0 else { return }

        let queued = activeDownloads.filter { $0.status == .queued }
        for item in queued.prefix(slotsAvailable) {
            if item.transferType == .upload {
                startUpload(item)
            } else {
                startDownload(item)
            }
        }
    }

    private func startDownload(_ item: DownloadItem) {
        item.status = .downloading

        let service = item.remoteName.isEmpty ? rcloneService : rcloneServiceFor(remote: item.remoteName)

        // Pass folderName when preserve-structure is on — rclone will create
        // destinationPath/folderName instead of copying content flat.
        let folderName: String? = (settings.preserveDriveStructure && item.isFolder) ? item.driveName : nil

        let process = service.startDownload(
            driveID: item.driveID,
            destinationPath: item.destinationPath,
            folderName: folderName,
            onStats: { [weak self, weak item] stats in
                guard let item = item else { return }
                if stats.totalBytes > 0 {
                    item.totalBytes = stats.totalBytes
                }
                item.transferredBytes = stats.bytesTransferred
                item.speed = stats.speed
                item.eta = stats.eta
                item.filesTransferred = stats.filesTransferred
                if stats.totalFiles > 0 {
                    item.totalFiles = stats.totalFiles
                }
                if !stats.currentFileName.isEmpty {
                    item.currentFileName = stats.currentFileName
                }

                // Track completed files (files that left the transferring array)
                let previousNames = Set(item.transferringFiles.map { $0.name })
                let newNames = Set(stats.transferringFiles.map { $0.name })
                let finished = previousNames.subtracting(newNames)
                if !finished.isEmpty {
                    let existingCompleted = Set(item.completedFileNames)
                    for name in finished where !existingCompleted.contains(name) {
                        item.completedFileNames.append(name)
                    }
                }
                item.transferringFiles = stats.transferringFiles

                self?.updateDockBadge()
            },
            onLogLine: { [weak item] line in
                guard let item = item else { return }
                if item.transferLog.count < 500 {
                    item.transferLog.append(line)
                }
            },
            onComplete: { [weak self, weak item] result in
                guard let self = self, let item = item else { return }
                self.processes.removeValue(forKey: item.id)

                switch result {
                case .success:
                    item.status = .completed
                    item.dateCompleted = Date()
                    item.transferredBytes = item.totalBytes
                    self.sendNotification(title: "Download concluído", body: item.driveName)
                case .failure(let error):
                    if case RcloneError.cancelled = error {
                        item.status = .cancelled
                    } else if self.shouldAutoRetry(item) {
                        item.retryCount += 1
                        item.status = .queued
                        item.errorMessage = nil
                        self.saveActiveStateNow()
                        let delay = UInt64(pow(2.0, Double(item.retryCount))) * 1_000_000_000
                        Task {
                            try? await Task.sleep(nanoseconds: delay)
                            self.processQueue()
                        }
                        return
                    } else {
                        item.status = .failed
                        item.errorMessage = error.localizedDescription
                        self.sendNotification(title: "Download falhou", body: "\(item.driveName): \(error.localizedDescription)")
                    }
                }

                self.moveToHistory(item)
                self.saveActiveStateNow()
                self.updateDockBadge()
                self.processQueue()
            }
        )

        processes[item.id] = process
        saveActiveStateNow()
    }

    // MARK: - Controls

    func pauseDownload(_ item: DownloadItem) {
        guard let process = processes[item.id] else { return }
        rcloneService.pause(process)
        item.status = .paused
        saveActiveStateNow()
    }

    func resumeDownload(_ item: DownloadItem) {
        if let process = processes[item.id], process.isRunning {
            rcloneService.resume(process)
            item.status = .downloading
        } else {
            item.status = .queued
            processQueue()
        }
        saveActiveStateNow()
    }

    func cancelDownload(_ item: DownloadItem) {
        if let process = processes[item.id] {
            rcloneService.cancel(process)
        }
        processes.removeValue(forKey: item.id)
        item.status = .cancelled
        moveToHistory(item)
        saveActiveStateNow()
        processQueue()
    }

    func retryDownload(_ item: DownloadItem) {
        history.removeAll { $0.id == item.id }
        persistence.saveHistory(history)

        let newItem = DownloadItem(
            driveID: item.driveID,
            driveName: item.driveName,
            isFolder: item.isFolder,
            destinationPath: item.destinationPath,
            transferType: item.transferType,
            remoteName: item.remoteName
        )
        newItem.totalBytes = item.totalBytes
        newItem.totalFiles = item.totalFiles
        activeDownloads.append(newItem)
        newItem.status = .queued
        saveActiveStateNow()
        processQueue()
    }

    func clearHistory() {
        history.removeAll()
        persistence.saveHistory(history)
    }

    func removeFromHistory(_ item: DownloadItem) {
        history.removeAll { $0.id == item.id }
        persistence.saveHistory(history)
    }

    // MARK: - Upload

    @discardableResult
    func addUpload(localPath: String, driveLink: String, remoteName: String? = nil, force: Bool = false) async -> AddResult {
        guard let parsed = GoogleDriveLinkParser.parse(driveLink) else { return .invalidLink }

        let remote = remoteName ?? settings.rcloneRemoteName

        if !force, let duplicate = checkDuplicate(driveID: parsed.id, destinationPath: localPath) {
            if duplicate == .duplicateActive {
                duplicateWarning = "Este arquivo já está na fila de transferências."
            } else {
                duplicateWarning = "Este arquivo já foi enviado anteriormente para este destino."
            }
            return duplicate
        }

        let fileName = (localPath as NSString).lastPathComponent
        var isDir: ObjCBool = false
        let isFolder = FileManager.default.fileExists(atPath: localPath, isDirectory: &isDir) && isDir.boolValue

        let item = DownloadItem(
            driveID: parsed.id,
            driveName: fileName,
            isFolder: isFolder,
            destinationPath: localPath,
            transferType: .upload,
            remoteName: remote
        )

        // Get local size
        let sizeInfo = rcloneService.getLocalSize(path: localPath)
        item.totalBytes = sizeInfo.bytes
        item.totalFiles = sizeInfo.count

        activeDownloads.append(item)
        item.status = .queued
        saveActiveStateNow()
        processQueue()
        return .added
    }

    private func startUpload(_ item: DownloadItem) {
        item.status = .downloading

        let service = item.remoteName.isEmpty ? rcloneService : rcloneServiceFor(remote: item.remoteName)
        let process = service.startUpload(
            localPath: item.destinationPath,
            driveID: item.driveID,
            onStats: { [weak self, weak item] stats in
                guard let item = item else { return }
                if stats.totalBytes > 0 {
                    item.totalBytes = stats.totalBytes
                }
                item.transferredBytes = stats.bytesTransferred
                item.speed = stats.speed
                item.eta = stats.eta
                item.filesTransferred = stats.filesTransferred
                if stats.totalFiles > 0 {
                    item.totalFiles = stats.totalFiles
                }
                if !stats.currentFileName.isEmpty {
                    item.currentFileName = stats.currentFileName
                }

                // Track completed files (files that left the transferring array)
                let previousNames = Set(item.transferringFiles.map { $0.name })
                let newNames = Set(stats.transferringFiles.map { $0.name })
                let finished = previousNames.subtracting(newNames)
                if !finished.isEmpty {
                    let existingCompleted = Set(item.completedFileNames)
                    for name in finished where !existingCompleted.contains(name) {
                        item.completedFileNames.append(name)
                    }
                }
                item.transferringFiles = stats.transferringFiles

                self?.updateDockBadge()
            },
            onLogLine: { [weak item] line in
                guard let item = item else { return }
                if item.transferLog.count < 500 {
                    item.transferLog.append(line)
                }
            },
            onComplete: { [weak self, weak item] result in
                guard let self = self, let item = item else { return }
                self.processes.removeValue(forKey: item.id)

                switch result {
                case .success:
                    item.status = .completed
                    item.dateCompleted = Date()
                    item.transferredBytes = item.totalBytes
                    self.sendNotification(title: "Upload concluído", body: item.driveName)

                    // Generate share link after upload completes
                    let svc = item.remoteName.isEmpty ? self.rcloneService : self.rcloneServiceFor(remote: item.remoteName)
                    let driveID = item.driveID
                    let isFolder = item.isFolder
                    Task {
                        let link = await svc.generateShareLink(driveID: driveID, isFolder: isFolder)
                        item.shareLink = link
                        self.persistence.saveHistory(self.history)
                    }

                case .failure(let error):
                    if case RcloneError.cancelled = error {
                        item.status = .cancelled
                    } else if self.shouldAutoRetry(item) {
                        item.retryCount += 1
                        item.status = .queued
                        item.errorMessage = nil
                        self.saveActiveStateNow()
                        let delay = UInt64(pow(2.0, Double(item.retryCount))) * 1_000_000_000
                        Task {
                            try? await Task.sleep(nanoseconds: delay)
                            self.processQueue()
                        }
                        return
                    } else {
                        item.status = .failed
                        item.errorMessage = error.localizedDescription
                        self.sendNotification(title: "Upload falhou", body: "\(item.driveName): \(error.localizedDescription)")
                    }
                }

                self.moveToHistory(item)
                self.saveActiveStateNow()
                self.updateDockBadge()
                self.processQueue()
            }
        )

        processes[item.id] = process
        saveActiveStateNow()
    }

    func openInFinder(_ item: DownloadItem) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.destinationPath)
    }

    // MARK: - Auto-Retry

    private func shouldAutoRetry(_ item: DownloadItem) -> Bool {
        settings.autoRetryEnabled && item.retryCount < settings.maxRetries
    }

    // MARK: - Private

    private func moveToHistory(_ item: DownloadItem) {
        activeDownloads.removeAll { $0.id == item.id }
        history.insert(item, at: 0)
        persistence.saveHistory(history)
    }

    // MARK: - Dock badge

    func updateDockBadge() {
        if isDownloading {
            NSApp.dockTile.badgeLabel = "\(Int(totalProgress * 100))%"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        guard settings.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

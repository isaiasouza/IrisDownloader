import Foundation

final class DownloadItem: ObservableObject, Identifiable, Codable {
    let id: UUID
    let driveID: String
    var driveName: String
    let isFolder: Bool
    let destinationPath: String  // local path (dest for download, source for upload)
    let dateAdded: Date
    let transferType: TransferType
    let remoteName: String

    @Published var status: DownloadStatus
    @Published var totalBytes: Int64
    @Published var transferredBytes: Int64
    @Published var speed: String
    @Published var eta: String
    @Published var filesTransferred: Int
    @Published var totalFiles: Int
    @Published var errorMessage: String?
    @Published var dateCompleted: Date?
    @Published var currentFileName: String
    @Published var shareLink: String?
    @Published var retryCount: Int = 0
    @Published var transferringFiles: [FileTransferInfo] = []
    @Published var completedFileNames: [String] = []
    var transferLog: [String] = []  // not persisted

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    var totalBytesFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var transferredBytesFormatted: String {
        ByteCountFormatter.string(fromByteCount: transferredBytes, countStyle: .file)
    }

    init(
        driveID: String,
        driveName: String,
        isFolder: Bool,
        destinationPath: String,
        transferType: TransferType = .download,
        remoteName: String = ""
    ) {
        self.id = UUID()
        self.driveID = driveID
        self.driveName = driveName
        self.isFolder = isFolder
        self.destinationPath = destinationPath
        self.dateAdded = Date()
        self.transferType = transferType
        self.remoteName = remoteName
        self.status = .queued
        self.totalBytes = 0
        self.transferredBytes = 0
        self.speed = ""
        self.eta = ""
        self.filesTransferred = 0
        self.totalFiles = 0
        self.currentFileName = ""
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, driveID, driveName, isFolder, destinationPath, dateAdded
        case status, totalBytes, transferredBytes, filesTransferred, totalFiles
        case errorMessage, dateCompleted, currentFileName, transferType, shareLink
        case remoteName
        case retryCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        driveID = try container.decode(String.self, forKey: .driveID)
        driveName = try container.decode(String.self, forKey: .driveName)
        isFolder = try container.decode(Bool.self, forKey: .isFolder)
        destinationPath = try container.decode(String.self, forKey: .destinationPath)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        transferType = try container.decodeIfPresent(TransferType.self, forKey: .transferType) ?? .download
        remoteName = try container.decodeIfPresent(String.self, forKey: .remoteName) ?? ""
        status = try container.decode(DownloadStatus.self, forKey: .status)
        totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
        transferredBytes = try container.decode(Int64.self, forKey: .transferredBytes)
        filesTransferred = try container.decode(Int.self, forKey: .filesTransferred)
        totalFiles = try container.decode(Int.self, forKey: .totalFiles)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        dateCompleted = try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
        currentFileName = try container.decodeIfPresent(String.self, forKey: .currentFileName) ?? ""
        shareLink = try container.decodeIfPresent(String.self, forKey: .shareLink)
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        speed = ""
        eta = ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(driveID, forKey: .driveID)
        try container.encode(driveName, forKey: .driveName)
        try container.encode(isFolder, forKey: .isFolder)
        try container.encode(destinationPath, forKey: .destinationPath)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(transferType, forKey: .transferType)
        try container.encode(remoteName, forKey: .remoteName)
        try container.encode(status, forKey: .status)
        try container.encode(totalBytes, forKey: .totalBytes)
        try container.encode(transferredBytes, forKey: .transferredBytes)
        try container.encode(filesTransferred, forKey: .filesTransferred)
        try container.encode(totalFiles, forKey: .totalFiles)
        try container.encode(errorMessage, forKey: .errorMessage)
        try container.encode(dateCompleted, forKey: .dateCompleted)
        try container.encode(currentFileName, forKey: .currentFileName)
        try container.encodeIfPresent(shareLink, forKey: .shareLink)
        try container.encode(retryCount, forKey: .retryCount)
    }
}

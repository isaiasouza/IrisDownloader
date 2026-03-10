import Foundation

struct DriveItem: Identifiable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isFolder: Bool

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

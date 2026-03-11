import SwiftUI

// MARK: - Focused Value Keys for Menu Commands

struct ShowDownloadSheetKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ShowUploadSheetKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showDownloadSheet: Binding<Bool>? {
        get { self[ShowDownloadSheetKey.self] }
        set { self[ShowDownloadSheetKey.self] = newValue }
    }

    var showUploadSheet: Binding<Bool>? {
        get { self[ShowUploadSheetKey.self] }
        set { self[ShowUploadSheetKey.self] = newValue }
    }
}

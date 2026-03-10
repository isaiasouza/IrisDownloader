import Foundation

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Update Info

struct UpdateInfo {
    let version: String
    let downloadURL: URL
    let releaseNotes: String?
    let releaseName: String?
}

// MARK: - Update Service

final class UpdateService {
    static let githubOwner = "isaiasouza"
    static let githubRepo = "IrisDownloader"

    private let currentVersion: String

    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Check GitHub Releases for a newer version
    func checkForUpdates() async -> UpdateInfo? {
        let urlString = "https://api.github.com/repos/\(Self.githubOwner)/\(Self.githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            guard isNewer(remote: remoteVersion, current: currentVersion) else {
                return nil
            }

            // Find .dmg asset
            let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") }
            guard let asset = dmgAsset,
                  let downloadURL = URL(string: asset.browserDownloadUrl) else {
                // Fallback to release page
                guard let pageURL = URL(string: release.htmlUrl) else { return nil }
                return UpdateInfo(
                    version: remoteVersion,
                    downloadURL: pageURL,
                    releaseNotes: release.body,
                    releaseName: release.name
                )
            }

            return UpdateInfo(
                version: remoteVersion,
                downloadURL: downloadURL,
                releaseNotes: release.body,
                releaseName: release.name
            )
        } catch {
            return nil
        }
    }

    /// Semantic version comparison: returns true if remote > current
    private func isNewer(remote: String, current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let maxLen = max(remoteParts.count, currentParts.count)
        for i in 0..<maxLen {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}

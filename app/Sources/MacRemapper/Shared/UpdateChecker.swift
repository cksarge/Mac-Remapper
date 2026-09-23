import Foundation
import MacRemapperCore

/// Checks GitHub for a newer release at launch and every 12 hours. It only reads the public
/// "latest release" info (the same data the website uses); nothing about the user is sent.
/// Installing stays manual: the menu shows a notice that opens the release page.
final class UpdateChecker: ObservableObject {
    struct Update: Equatable {
        let version: String
        let pageURL: URL
    }

    @Published private(set) var availableUpdate: Update?

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/cksarge/Mac-Remapper/releases/latest")!
    private static let checkInterval: TimeInterval = 12 * 60 * 60

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private var timer: Timer?

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func check() {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data,
                  let release = try? JSONDecoder().decode(Release.self, from: data),
                  !release.draft, !release.prerelease,
                  let pageURL = URL(string: release.htmlURL) else { return }

            let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            let update = AppVersion.isVersion(version, newerThan: self.currentVersion)
                ? Update(version: version, pageURL: pageURL)
                : nil
            DispatchQueue.main.async {
                if self.availableUpdate != update { self.availableUpdate = update }
            }
        }.resume()
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let draft: Bool
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft, prerelease
        }
    }
}

import AppKit
import Foundation

struct GitHubRelease {
    let version: String
    let name: String
    let pageURL: URL
    let installerURL: URL
}

enum UpdateCheckResult {
    case upToDate
    case available(GitHubRelease)
}

final class GitHubUpdateController {
    private struct ReleaseResponse: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case draft
            case prerelease
            case assets
        }
    }

    private struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/Zhigalove/SLSwitch/releases/latest")!

    func checkForUpdates(completion: @escaping (Result<UpdateCheckResult, Error>) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SLSwitch/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(UpdateError.emptyResponse))
                return
            }

            do {
                let response = try JSONDecoder().decode(ReleaseResponse.self, from: data)
                guard !response.draft, !response.prerelease else {
                    completion(.success(.upToDate))
                    return
                }

                guard let installerURL = response.assets.first(where: { asset in
                    asset.name.localizedCaseInsensitiveContains("SLSwitch")
                        && asset.name.localizedCaseInsensitiveContains("Installer")
                        && asset.name.localizedCaseInsensitiveContains(".dmg")
                })?.browserDownloadURL else {
                    completion(.failure(UpdateError.installerAssetMissing))
                    return
                }

                let releaseVersion = Self.normalizedVersion(response.tagName)
                guard Self.compareVersions(releaseVersion, AppVersion.short) == .orderedDescending else {
                    completion(.success(.upToDate))
                    return
                }

                completion(.success(.available(GitHubRelease(
                    version: releaseVersion,
                    name: response.name ?? response.tagName,
                    pageURL: response.htmlURL,
                    installerURL: installerURL
                ))))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func downloadInstaller(for release: GitHubRelease, completion: @escaping (Result<URL, Error>) -> Void) {
        URLSession.shared.downloadTask(with: release.installerURL) { temporaryURL, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let temporaryURL else {
                completion(.failure(UpdateError.emptyResponse))
                return
            }

            do {
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("SLSwitch-\(release.version)-Installer.dmg")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                completion(.success(destination))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue < rhsValue { return .orderedAscending }
            if lhsValue > rhsValue { return .orderedDescending }
        }

        return .orderedSame
    }
}

private enum UpdateError: LocalizedError {
    case emptyResponse
    case installerAssetMissing

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return L10n.string("updates.error.empty_response")
        case .installerAssetMissing:
            return L10n.string("updates.error.installer_missing")
        }
    }
}

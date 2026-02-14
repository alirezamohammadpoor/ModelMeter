import Foundation

struct LatestRelease: Equatable {
    let tagName: String
    let htmlURL: URL
}

struct GitHubReleaseService {
    private let releasesURL = URL(string: "https://api.github.com/repos/alirezamohammadpoor/ModelMeter/releases/latest")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "UpdateManager", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "GitHub API returned \(http.statusCode)."
            ])
        }

        let payload = try JSONDecoder().decode(LatestReleasePayload.self, from: data)
        return LatestRelease(tagName: payload.tagName, htmlURL: payload.htmlURL)
    }
}

private struct LatestReleasePayload: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

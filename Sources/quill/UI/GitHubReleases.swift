import Foundation

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let publishedAt: String?
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case publishedAt = "published_at"
        case body
    }
}

/// Live source for the Change Log tab — quill's repo went public with
/// real tagged releases starting at v0.1.0, so this reads straight from
/// GitHub's public Releases API. No auth needed (public repo, public
/// endpoint), same "unauthenticated public API" shape as
/// `OpenRouterModels.fetch()` elsewhere in this app. Falls back to
/// `ChangeLog.entries`' hand-written local array on any failure —
/// offline, rate-limited, or before this ever worked — so the tab is
/// never blank.
enum GitHubReleases {
    private static let releasesURL = URL(string: "https://api.github.com/repos/imtamiliniyan/quill/releases")!

    static func fetch() async throws -> [ChangeLogEntry] {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        return releases.map(toEntry)
    }

    private static func toEntry(_ release: GitHubRelease) -> ChangeLogEntry {
        let label = (release.name?.isEmpty == false) ? release.name! : release.tagName
        return ChangeLogEntry(
            id: release.tagName,
            label: label,
            date: formattedDate(release.publishedAt),
            changes: bulletPoints(from: release.body ?? "")
        )
    }

    private static func formattedDate(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Pulls just the `- ` bullet lines out of the release body's
    /// Markdown, dropping headings and blank lines — the same flat
    /// `[String]` shape `ChangeLogEntry.changes` already expects,
    /// whether the content came from GitHub or the local fallback array.
    private static func bulletPoints(from body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") }
            .map { String($0.dropFirst(2)) }
    }
}

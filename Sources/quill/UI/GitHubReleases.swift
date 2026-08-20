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

/// Live source for the Change Log tab (`fetch()` only — update *checking*
/// itself is Sparkle's job now, see `AppUpdater.swift`). Quill's repo went
/// public with
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

        // GitHub's release-creation API has no way to backdate
        // `published_at` — it's always stamped at the moment `gh release
        // create` actually runs, regardless of which historical commit
        // the tag points to. v0.1.0 (the real Aug 10 build, tagged
        // retroactively once this repo had releases at all) would
        // otherwise show today's date and sort ahead of v0.5.0 just
        // because it was *published* to GitHub more recently. Each
        // release's notes carry a `Released: yyyy-MM-dd` line as the
        // real source of truth for both the displayed date and the
        // sort order; `published_at` is only a fallback for releases
        // that don't include one.
        let dated: [(entry: ChangeLogEntry, date: Date)] = releases.map { release in
            let (releasedAt, changes) = parseBody(release.body ?? "")
            let resolvedDate = releasedAt ?? isoDate(release.publishedAt) ?? .distantPast
            let label = (release.name?.isEmpty == false) ? release.name! : release.tagName
            let entry = ChangeLogEntry(
                id: release.tagName,
                label: label,
                date: displayDate(resolvedDate),
                changes: changes
            )
            return (entry, resolvedDate)
        }
        return dated.sorted { $0.date > $1.date }.map(\.entry)
    }

    /// Pulls the `Released: yyyy-MM-dd` line and the `- ` bullet lines
    /// out of a release body's Markdown — the same flat `[String]`
    /// shape `ChangeLogEntry.changes` already expects, whether the
    /// content came from GitHub or the local fallback array.
    private static func parseBody(_ body: String) -> (releasedAt: Date?, changes: [String]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        var releasedAt: Date?
        var changes: [String] = []
        for rawLine in body.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Released:") {
                let dateString = line.dropFirst("Released:".count).trimmingCharacters(in: .whitespaces)
                releasedAt = dateFormatter.date(from: dateString)
            } else if line.hasPrefix("- ") {
                changes.append(String(line.dropFirst(2)))
            }
        }
        return (releasedAt, changes)
    }

    private static func isoDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }

    private static func displayDate(_ date: Date) -> String {
        guard date != .distantPast else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

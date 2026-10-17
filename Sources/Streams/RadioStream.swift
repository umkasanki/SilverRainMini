import Foundation

/// One of the station's own streams, as listed in `streams.json` (SPEC FR-9).
/// Not `Stream`: that name belongs to `Foundation.Stream`.
struct RadioStream: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    /// What Settings shows: «Высокое · AAC 96».
    let title: String
    /// What the panel shows: «AAC 96».
    let shortTitle: String
    let url: URL
    let isDefault: Bool

    private enum CodingKeys: String, CodingKey {
        case id, title, shortTitle, url
        case isDefault = "default"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        shortTitle = try container.decode(String.self, forKey: .shortTitle)
        url = try container.decode(URL.self, forKey: .url)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

/// What the player is asked to play, whichever way it was chosen.
struct PlayableStream: Equatable, Sendable {
    /// `nil` when the user's own address cannot be played.
    let url: URL?
    /// What the panel shows next to «В эфире».
    let shortTitle: String
    /// The emergency path is for the station's own streams only (SPEC FR-5).
    let allowsFallback: Bool
}

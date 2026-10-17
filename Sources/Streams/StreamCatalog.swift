import Foundation

/// The station's streams from `streams.json`, plus the user's own address (SPEC FR-9).
struct StreamCatalog: Sendable {
    enum Failure: Error, Equatable {
        case empty
        case notExactlyOneDefault
        case duplicateID(String)
        case notHTTPS(String)
    }

    /// Why the user's own address cannot be played, in the words Settings shows.
    enum AddressProblem: Error, Equatable {
        case empty
        case notHTTPS
        case malformed

        var message: String {
            switch self {
            case .empty: "Введите адрес потока"
            case .notHTTPS: "Нужен адрес https://"
            case .malformed: "Это не похоже на адрес"
            }
        }
    }

    /// The value of the `streamId` setting that means «Свой адрес…».
    static let customID = "custom"

    let streams: [RadioStream]
    let defaultStream: RadioStream

    /// Checks the list as well as reading it: a broken catalog is caught by a test,
    /// not discovered when the app cannot play.
    init(data: Data) throws {
        let streams = try JSONDecoder().decode([RadioStream].self, from: data)
        guard !streams.isEmpty else { throw Failure.empty }
        let defaults = streams.filter(\.isDefault)
        guard defaults.count == 1, let defaultStream = defaults.first else { throw Failure.notExactlyOneDefault }
        var seen = Set<String>()
        for stream in streams {
            guard seen.insert(stream.id).inserted, stream.id != Self.customID else { throw Failure.duplicateID(stream.id) }
            guard stream.url.scheme == "https" else { throw Failure.notHTTPS(stream.id) }
        }
        self.streams = streams
        self.defaultStream = defaultStream
    }

    /// The catalog that ships inside the app.
    static let bundled: StreamCatalog = {
        guard let url = Bundle.main.url(forResource: "streams", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? StreamCatalog(data: data)
        else {
            fatalError("streams.json is missing or broken; StreamCatalogTests should have caught it")
        }
        return catalog
    }()

    /// The station's stream with `id`, or the default one if the id is unknown.
    func stream(id: String) -> RadioStream {
        streams.first { $0.id == id } ?? defaultStream
    }

    /// What to play for the saved settings.
    func playable(streamID: String, customAddress: String) -> PlayableStream {
        guard streamID == Self.customID else {
            let stream = stream(id: streamID)
            return PlayableStream(url: stream.url, shortTitle: stream.shortTitle, allowsFallback: true)
        }
        return PlayableStream(
            url: try? Self.customURL(from: customAddress).get(),
            shortTitle: "Свой адрес",
            allowsFallback: false
        )
    }

    /// The user's own address made playable: trimmed, given `https://` if it has
    /// no scheme. Plain `http://` is refused, as the app plays HTTPS only.
    static func customURL(from text: String) -> Result<URL, AddressProblem> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: withScheme),
              let host = components.host, !host.isEmpty,
              let url = components.url
        else { return .failure(.malformed) }
        guard components.scheme?.lowercased() == "https" else {
            return .failure(components.scheme?.lowercased() == "http" ? .notHTTPS : .malformed)
        }
        return .success(url)
    }
}

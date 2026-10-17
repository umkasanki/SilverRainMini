import Foundation

/// The «Проверить» button (SPEC FR-10): asks the address for its headers only and
/// says what kind of stream is there.
struct StreamProbe: Sendable {
    enum Outcome: Equatable, Sendable {
        /// «AAC · 96 kbps».
        case stream(String)
        /// The server answered in a way the check cannot read, though it may well play.
        case inconclusive(String)
        case failure(String)
    }

    var timeout: TimeInterval = 5

    func probe(_ address: String) async -> Outcome {
        let url: URL
        switch StreamCatalog.customURL(from: address) {
        case .success(let valid): url = valid
        case .failure(let problem): return .failure(problem.message)
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        do {
            // Only the headers are wanted; the stream itself never ends.
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            bytes.task.cancel()
            guard let http = response as? HTTPURLResponse else { return .failure("Не удалось подключиться") }
            guard (200..<300).contains(http.statusCode) else { return .failure("Сервер ответил: \(http.statusCode)") }
            return Self.describe(
                contentType: http.value(forHTTPHeaderField: "Content-Type"),
                bitrate: http.value(forHTTPHeaderField: "icy-br")
            )
        } catch {
            return Self.outcome(for: error)
        }
    }

    /// Old SHOUTcast servers answer `ICY 200 OK` instead of an HTTP status line.
    /// URLSession cannot read that, but `AVPlayer` plays such streams, so the check
    /// says it does not know rather than that the address is dead.
    static func outcome(for error: any Error) -> Outcome {
        switch (error as? URLError)?.code {
        case .cannotParseResponse?, .badServerResponse?:
            .inconclusive("Сервер старого типа: проверить нельзя, попробуйте включить")
        default:
            .failure("Не удалось подключиться")
        }
    }

    /// Names the codec from `Content-Type` and adds the bitrate from `icy-br`,
    /// which some servers send twice («96, 96»).
    static func describe(contentType: String?, bitrate: String?) -> Outcome {
        let type = (contentType ?? "").lowercased()
        let codec: String
        if type.contains("aac") {
            codec = "AAC"
        } else if type.contains("mpeg") || type.contains("mp3") {
            codec = "MP3"
        } else if type.contains("ogg") {
            codec = "Ogg"
        } else if type.hasPrefix("audio/") {
            codec = String(type.dropFirst("audio/".count).prefix { $0 != ";" }).uppercased()
        } else {
            return .failure("Это не аудиопоток")
        }
        let kbps = bitrate?.split(whereSeparator: { !$0.isNumber }).first.map(String.init)
        return .stream(kbps.map { "\(codec) · \($0) kbps" } ?? codec)
    }
}

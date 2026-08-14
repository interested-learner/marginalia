import Foundation

/// One book, as Open Library describes it.
///
/// Deliberately thin: title, author, page count. There is no cover URL here and
/// there never will be — see `docs/decisions.md` §7.
struct BookCandidate: Identifiable, Equatable, Sendable {
    /// The work key, or the isbn. Identifies the row in a results list and is
    /// never shown.
    let id: String
    let title: String
    /// Empty when Open Library doesn't know, which happens often enough that
    /// it's a blank field rather than a failure.
    var author: String = ""
    /// 0 when Open Library doesn't know.
    var pageCount: Int = 0
    var isbn: String?
}

/// Open Library. No API key, no account, no attribution requirement.
///
/// **Fetching and parsing are kept apart on purpose.** Everything under
/// *Parsing* is a pure function from `Data`, so the response shapes are tested
/// against captured fixtures instead of against the network.
///
/// **Lookup failure is routine, not exceptional.** Every path here has to end
/// somewhere the reader can still type the book in by hand.
nonisolated enum BookLookup {

    enum Failure: Error, Equatable {
        /// Nothing worth searching for, or a barcode that isn't a book.
        case badQuery
        /// No network, or Open Library didn't answer.
        case unreachable
        /// It answered, and doesn't have this one.
        case notFound

        /// In the app's own words, lowercase like the rest of the chrome.
        var message: String {
            switch self {
            case .badQuery: "that isn't an isbn — type the book in instead"
            case .unreachable: "couldn't reach open library — type the book in instead"
            case .notFound: "no match — type the book in instead"
            }
        }
    }

    private static let host = "https://openlibrary.org"

    /// Open Library asks callers to identify themselves. No key, just manners.
    private static let agent =
        "marginalia/1.0 (iOS book notes; github.com/interested-learner/marginalia)"

    // MARK: Fetching

    static func search(
        _ query: String,
        using session: URLSession = .shared
    ) async throws -> [BookCandidate] {
        guard let url = searchURL(for: query) else { throw Failure.badQuery }
        return candidates(fromSearch: try await fetch(url, using: session))
    }

    /// The isbn endpoint returns an **edition**, whose authors are key
    /// references rather than names — so the name costs a second request. That
    /// request is allowed to fail: a book with no author still beats no book,
    /// and the author field is right there to type into.
    static func edition(
        isbn raw: String,
        using session: URLSession = .shared
    ) async throws -> BookCandidate {
        guard let isbn = ISBN.normalized(raw), let url = editionURL(for: isbn)
        else { throw Failure.badQuery }

        let data = try await fetch(url, using: session)
        guard var found = candidate(fromEdition: data, isbn: isbn) else { throw Failure.notFound }

        if found.author.isEmpty,
           let key = authorKey(inEdition: data),
           let url = authorURL(for: key),
           let payload = try? await fetch(url, using: session),
           let name = authorName(from: payload) {
            found.author = name
        }
        return found
    }

    private static func fetch(_ url: URL, using session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.unreachable
        }

        guard let http = response as? HTTPURLResponse else { throw Failure.unreachable }
        guard http.statusCode == 200 else { throw Failure.notFound }
        return data
    }

    // MARK: URLs

    static func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: "\(host)/search.json")
        else { return nil }

        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            // Asking only for the fields that get drawn keeps the response
            // small — the default one carries every edition of every match.
            URLQueryItem(name: "fields", value: "key,title,author_name,number_of_pages_median,isbn"),
            // More than this and picking becomes reading. The duplicates that
            // `candidates(fromSearch:)` collapses come out of this budget, so
            // the list on screen is usually shorter.
            URLQueryItem(name: "limit", value: "15"),
        ]
        return components.url
    }

    static func editionURL(for isbn: String) -> URL? {
        guard let isbn = ISBN.normalized(isbn) else { return nil }
        return URL(string: "\(host)/isbn/\(isbn).json")
    }

    /// `/authors/OL23919A` → the author document.
    static func authorURL(for key: String) -> URL? {
        let trimmed = key.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !trimmed.isEmpty, trimmed.hasPrefix("authors/") else { return nil }
        return URL(string: "\(host)/\(trimmed).json")
    }

    // MARK: Parsing
    //
    // Pure, from here down. Every shape below is in `BookLookupTests` as a
    // captured fixture, including the ones missing an author or a page count.

    /// Open Library holds a separate work record for every translation and
    /// reissue, so a search for *Meditations* comes back as nine rows of
    /// "Meditations · Marcus Aurelius" differing only in page count. They're
    /// collapsed to the first — which is the most relevant one, since the
    /// order is Open Library's — because a list you have to read twice to pick
    /// from is worse than a shorter one that might have picked the wrong
    /// edition's page count. That number is editable in the field below it.
    static func candidates(fromSearch data: Data) -> [BookCandidate] {
        guard let response = try? decoder.decode(SearchResponse.self, from: data)
        else { return [] }

        var seen: Set<String> = []
        return response.docs.compactMap { doc in
            let title = doc.title?.squeezed ?? ""
            guard !title.isEmpty else { return nil }

            let author = doc.authorName?.first?.squeezed ?? ""
            guard seen.insert("\(title)|\(author)".lowercased()).inserted else { return nil }

            return BookCandidate(
                id: doc.key ?? title,
                title: title,
                author: author,
                pageCount: doc.numberOfPagesMedian ?? 0,
                isbn: preferred(doc.isbn)
            )
        }
    }

    static func candidate(fromEdition data: Data, isbn: String) -> BookCandidate? {
        guard let edition = try? decoder.decode(EditionResponse.self, from: data) else { return nil }
        let title = edition.title?.squeezed ?? ""
        guard !title.isEmpty else { return nil }

        return BookCandidate(
            id: isbn,
            title: title,
            author: author(inStatement: edition.byStatement) ?? "",
            pageCount: edition.numberOfPages ?? 0,
            isbn: preferred(edition.isbn13) ?? ISBN.normalized(isbn)
        )
    }

    static func authorKey(inEdition data: Data) -> String? {
        (try? decoder.decode(EditionResponse.self, from: data))?
            .authors?.compactMap(\.key).first
    }

    static func authorName(from data: Data) -> String? {
        let name = (try? decoder.decode(AuthorResponse.self, from: data))?.name?.squeezed ?? ""
        return name.isEmpty ? nil : name
    }

    /// `by Daniel Kahneman` → `Daniel Kahneman`.
    ///
    /// The edition sometimes carries its author as prose alongside the key
    /// reference. When it does, it saves a request.
    private static func author(inStatement statement: String?) -> String? {
        guard let statement = statement?.squeezed, !statement.isEmpty else { return nil }
        let name = statement.hasPrefix("by ")
            ? String(statement.dropFirst(3)).squeezed
            : statement
        return name.isEmpty ? nil : name
    }

    /// The thirteen-digit form when it's on offer — it's what a barcode reads
    /// and what the isbn endpoint takes.
    private static func preferred(_ candidates: [String]?) -> String? {
        let valid = (candidates ?? []).compactMap(ISBN.normalized)
        return valid.first { $0.count == 13 } ?? valid.first
    }

    /// Built per call rather than held: `JSONDecoder` isn't `Sendable`, so a
    /// shared one can't be a global under strict concurrency.
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: Response shapes

    private struct SearchResponse: Decodable {
        struct Doc: Decodable {
            let key: String?
            let title: String?
            let authorName: [String]?
            let numberOfPagesMedian: Int?
            let isbn: [String]?
        }
        let docs: [Doc]
    }

    private struct EditionResponse: Decodable {
        struct AuthorRef: Decodable { let key: String? }
        let title: String?
        let numberOfPages: Int?
        let byStatement: String?
        let authors: [AuthorRef]?
        let isbn13: [String]?
    }

    private struct AuthorResponse: Decodable {
        let name: String?
    }
}

/// An isbn as it comes off a barcode or out of a field — hyphens, spaces, and
/// the occasional `ISBN` typed in front of it.
nonisolated enum ISBN {

    /// `978-0-374-53355-7` → `9780374533557`, and nothing at all for a barcode
    /// that isn't a book.
    ///
    /// Thirteen digits are only an isbn under Bookland — the `978` and `979`
    /// prefixes. The EAN off a cereal box is a perfectly valid barcode and not
    /// a book, and saying so beats a lookup that fails for no visible reason.
    static func normalized(_ raw: String) -> String? {
        let stripped = raw.uppercased().filter { $0.isNumber || $0 == "X" }
        switch stripped.count {
        case 13 where stripped.hasPrefix("978") || stripped.hasPrefix("979"):
            return stripped.allSatisfy(\.isNumber) ? stripped : nil
        case 10 where stripped.dropLast().allSatisfy(\.isNumber):
            return stripped
        default:
            return nil
        }
    }
}

/// `nonisolated` because the project defaults to `MainActor` isolation and
/// every parser above is pure — see the note in `CLAUDE.md`.
private extension String {
    nonisolated var squeezed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

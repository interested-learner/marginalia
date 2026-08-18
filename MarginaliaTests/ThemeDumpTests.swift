import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// **This is the one that decides whether the summary is worth reading.**
///
/// `ThemeEngineTests` proves the rule is the rule — that membership follows the
/// rankings, that the partition is a partition, that the same library always
/// reads the same way. None of that can say whether `#attention` is a group a
/// person would recognise, and no assertion can. So this prints the real thing:
/// every theme, its name, how many books it spans, the exemplar the overview
/// will quote, and every member underneath — and a person reads it.
///
/// It is also the honest half of `docs/decisions.md` §20. The themes on this
/// machine are the **fallback** embedder's, and phase 6 measured that model
/// scoring two paraphrases at `0.267` against each other and `0.274` against an
/// unrelated note about a kitchen tap. Rank-based grouping survives a change of
/// embedder; it cannot manufacture a signal that was never there. **Read this
/// again on the device**, next to `AffinityDumpTests`, and judge then.
///
/// Off by default, because it belongs to a decision rather than to a regression:
///
/// ```bash
/// TEST_RUNNER_MARGINALIA_THEMES=1 xcodebuild -scheme Marginalia \
///   -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build \
///   test -only-testing:MarginaliaTests/ThemeDumpTests 2>&1 | grep '^|'
/// ```
///
/// Every line starts with `|` so it survives an `xcodebuild` log, which is
/// otherwise not a place prose gets out of alive.
@MainActor
struct ThemeDumpTests {

    @Test(.enabled(if: themeDumpWasAskedFor()))
    func dumpTheSeedLibrarysThemes() async throws {
        let context = ModelContext(try ModelContainer.marginalia(inMemory: true))
        let defaults = UserDefaults(suiteName: "marginalia.themes.\(UUID().uuidString)")!
        try Library.prepare(context, counter: ShortIDCounter(defaults: defaults))

        // The themes don't need the edges, but the relink is what embeds the
        // library — and reading both dumps off the same store is the point.
        try await LinkWriter.relink(in: context)

        let notes = try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.shortID)]))
        let shelf = BookShelf.ordered(try context.fetch(FetchDescriptor<Book>()))
        let index = Dictionary(
            uniqueKeysWithValues: shelf.enumerated().map { ($1.persistentModelID, $0) }
        )

        let source = notes.compactMap(\.embeddingSource).first

        let subjects = notes.map { note in
            ThemeEngine.Subject(
                id: note.shortID,
                vector: source.flatMap { note.vector(from: $0) } ?? [],
                tags: note.tags,
                book: note.book.flatMap { index[$0.persistentModelID] }
            )
        }

        let documents = notes.map { note in
            ThemeName.Document(id: note.shortID, phrases: NounPhrases.in(note.text))
        }
        let byID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        let texts = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.text) })
        let titles = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.book?.title ?? "—") })

        let reading = ThemeEngine.reading(subjects)

        let model = source?.rawValue ?? "none"
        let width = subjects.first(where: { !$0.vector.isEmpty })?.vector.count ?? 0
        let embedded = subjects.count { !$0.vector.isEmpty }

        say("")
        say("model: \(model) · \(width)d · \(embedded) of \(notes.count) notes embedded"
            + " · rank \(ThemeEngine.neighbors), no floor")
        say("\(reading.themes.count) themes · \(reading.loose.count) loose"
            + " · \(reading.themes.map(\.count).reduce(0, +)) notes grouped")
        say("")

        for theme in reading.themes {
            let members = theme.members.compactMap { byID[$0] }
            let name = ThemeName.name(for: members, in: documents)
            let label = name.isEmpty ? "(unnamed)" : name.text

            let books = theme.books.count
            say("\(label)")
            say("  \(theme.count) notes · \(books) \(books == 1 ? "book" : "books")"
                + " · \(theme.ties) ties · exemplar n.\(pad(theme.exemplar))")

            for id in theme.members {
                let mark = id == theme.exemplar ? "*" : " "
                say("  \(mark) n.\(pad(id))  \(clip(texts[id] ?? "", 88))")
                say("       \(clip(titles[id] ?? "", 88))")
            }
            say("")
        }

        guard !reading.loose.isEmpty else { return }

        say("loose — in no theme")
        for id in reading.loose {
            say("    n.\(pad(id))  \(clip(texts[id] ?? "", 88))")
        }
        say("")
    }

    // MARK: Legibility

    private func say(_ line: String) { print("| \(line)") }

    private func pad(_ id: Int) -> String { id < 10 ? "0\(id)" : "\(id)" }

    private func clip(_ text: String, _ width: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count <= width ? flat : String(flat.prefix(width - 1)) + "…"
    }
}

/// Outside the type on purpose. `@Test(.enabled(if:))` evaluates its condition in
/// a `Sendable` closure, which a `@MainActor` member can't be read from — the
/// same reason `AffinityDumpTests` puts its own gate down here.
private nonisolated func themeDumpWasAskedFor() -> Bool {
    ProcessInfo.processInfo.environment["MARGINALIA_THEMES"] == "1"
}

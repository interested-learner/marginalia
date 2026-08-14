import Foundation
import SwiftData
import Testing
@testable import Marginalia

/// **This is the one that decides whether phase 6 worked.**
///
/// Nothing here asserts anything about quality, because no assertion can: a test
/// can prove the floor is respected and the degree cap holds, and still describe
/// a library full of connections nobody would defend. So this prints the real
/// output — every seed note, its five best candidates, the score, and whether
/// the constraints let it through — and a person reads it.
///
/// Off by default, because it's two hundred lines and it belongs to a decision
/// rather than to a regression:
///
/// ```bash
/// TEST_RUNNER_MARGINALIA_DUMP=1 xcodebuild -scheme Marginalia \
///   -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build \
///   test -only-testing:MarginaliaTests/AffinityDumpTests 2>&1 | grep '^|'
/// ```
///
/// Every line it prints starts with `|` so it can be pulled back out of an
/// `xcodebuild` log, which is otherwise not a place prose survives.
@MainActor
struct AffinityDumpTests {

    @Test(.enabled(if: dumpWasAskedFor()))
    func dumpTheSeedLibrarysConnections() async throws {
        let context = ModelContext(try ModelContainer.marginalia(inMemory: true))
        let defaults = UserDefaults(suiteName: "marginalia.dump.\(UUID().uuidString)")!
        try Library.prepare(context, counter: ShortIDCounter(defaults: defaults))

        try await LinkWriter.relink(in: context)

        let notes = try context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.shortID)]))
        let edges = try context.fetch(FetchDescriptor<NoteEdge>())

        let source = notes.compactMap(\.embeddingSource).first
        let subjects = notes.compactMap { note -> AffinityEngine.Subject? in
            guard let source, let vector = note.vector(from: source) else { return nil }
            return AffinityEngine.Subject(id: note.shortID, vector: vector, tags: note.tags)
        }

        var kind: [AffinityEngine.Pair: String] = [:]
        for edge in edges {
            guard let from = edge.from?.shortID, let to = edge.to?.shortID else { continue }
            kind[AffinityEngine.Pair(from, to)] = edge.isPinned ? "seeded" : "edge"
        }

        let titles = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.book?.title ?? "—") })
        let texts = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.text) })
        let tags = Dictionary(uniqueKeysWithValues: notes.map { ($0.shortID, $0.tags) })

        let model: String = source?.rawValue ?? "none"
        let width: Int = subjects.first?.vector.count ?? 0
        let rules = "floor \(AffinityEngine.floor) · k \(AffinityEngine.neighbors) · cap \(AffinityEngine.degreeCap)"
        say("")
        say("model: \(model) · \(width)d · \(subjects.count) of \(notes.count) notes embedded · \(rules)")
        say("")

        for subject in subjects {
            var scored: [Candidate] = []
            for other in subjects where other.id != subject.id {
                scored.append(Candidate(id: other.id, score: AffinityEngine.score(subject, other)))
            }
            scored.sort { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
            let best = scored.prefix(5)

            let title: String = titles[subject.id] ?? ""
            let line: String = clip(texts[subject.id] ?? "", 96)
            say("n.\(pad(subject.id)) \(title) \(tagLine(tags[subject.id] ?? []))")
            say("       \(line)")

            for candidate in best {
                let pair = AffinityEngine.Pair(subject.id, candidate.id)
                let held: String = kind[pair, default: "—"]
                let state: String = held.padding(toLength: 6, withPad: " ", startingAt: 0)
                let text: String = clip(texts[candidate.id] ?? "", 74)
                say("  \(score(candidate.score)) \(state) n.\(pad(candidate.id)) \(text)")
            }
            say("")
        }

        // What the graph came out as, which is the other half of the judgement:
        // a defensible edge list that leaves half the library isolated is still
        // a map worth nothing.
        var degree: [Int: Int] = [:]
        for pair in kind.keys {
            degree[pair.low, default: 0] += 1
            degree[pair.high, default: 0] += 1
        }
        let automatic = kind.values.filter { $0 == "edge" }.count
        let isolated = subjects.filter { degree[$0.id, default: 0] == 0 }.map(\.id)

        let ends: Int = degree.values.reduce(0, +)
        let mean = String(format: "%.1f", Double(ends) / Double(max(subjects.count, 1)))
        let most: Int = degree.values.max() ?? 0
        let alone: String = isolated.map { "n.\(pad($0))" }.joined(separator: " ")
        say("\(kind.count) connections — \(automatic) found, \(kind.count - automatic) seeded")
        say("degree: mean \(mean) · max \(most) · isolated \(isolated.count) \(alone)")

        var all: [Double] = []
        for i in subjects.indices {
            for j in (i + 1)..<subjects.count {
                all.append(AffinityEngine.score(subjects[i], subjects[j]))
            }
        }
        all.sort(by: >)
        let over: Int = all.filter { $0 >= AffinityEngine.floor }.count
        let median: Double = all.isEmpty ? 0 : all[all.count / 2]
        say("scores: max \(score(all.first ?? 0)) · median \(score(median)) · over the floor \(over) of \(all.count)")
        say("")
    }

    // MARK: Legibility

    private struct Candidate {
        let id: Int
        let score: Double
    }

    private func say(_ line: String) { print("| \(line)") }

    private func pad(_ id: Int) -> String { id < 10 ? "0\(id)" : "\(id)" }

    private func score(_ value: Double) -> String { String(format: "%.3f", value) }

    private func tagLine(_ tags: [String]) -> String {
        tags.map { "#\($0)" }.joined(separator: " ")
    }

    private func clip(_ text: String, _ width: Int) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count <= width ? flat : String(flat.prefix(width - 1)) + "…"
    }
}

/// Outside the type on purpose. `@Test(.enabled(if:))` evaluates its condition
/// in a `Sendable` closure, which a `@MainActor` member can't be read from.
private nonisolated func dumpWasAskedFor() -> Bool {
    ProcessInfo.processInfo.environment["MARGINALIA_DUMP"] == "1"
}

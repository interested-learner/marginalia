import Foundation

/// What a theme is called.
///
/// **Pure**, and deliberately incapable of invention. There is no LLM here —
/// on-device, no network, no key — and inventing prose would be the app's first
/// invented text besides. A name is an extraction from the notes' own words or
/// there is no name.
///
/// ## Nothing here comes from anything the reader typed
///
/// A theme used to be named by a tag when a majority of its notes shared one,
/// with extracted terms as the fallback. That was *correct* — the grouping never
/// needed tags, and a note with no tags at all still lands in a theme — but it
/// **read** as though tagging were the mechanism, because six of the seven
/// themes on the seed library came out tag-named. `SeedLibrary` is deliberately
/// heavily tagged, so the sample was misrepresenting the feature.
///
/// So tags name nothing now. They remain 20% of `AffinityEngine.score`, which is
/// part of what pulls two notes together in the first place, but no label on the
/// map depends on the reader having typed one.
///
/// ## Phrases, not keywords
///
/// Single distinctive words produced `error · systems · blame`, which reads as
/// keyword salad. `NounPhrases` supplies phrases as well as bare nouns, and a
/// phrase wins ties, so a theme comes out as `human error · system design`. The
/// impure half lives there; this file only ever sees strings.
nonisolated enum ThemeName {

    /// A note, reduced to what a name can be made of.
    struct Document: Sendable, Equatable {
        let id: Int
        /// Already extracted — call `NounPhrases.in(_:)`.
        let phrases: [String]

        init(id: Int, phrases: [String] = []) {
            self.id = id
            self.phrases = phrases
        }
    }

    struct Name: Sendable, Equatable {
        let text: String

        static let none = Name(text: "")

        var isEmpty: Bool { text.isEmpty }
    }

    /// A candidate and what it weighed. Named rather than a tuple: the tuple
    /// form stalls the type checker once `sorted` and a key-path `map` are
    /// chained onto it.
    private struct Weighted {
        let phrase: String
        let weight: Double
        let words: Set<String>
    }

    /// How many phrases a name carries. Three fits one line at every type size
    /// the chrome ceiling allows; four does not.
    static let terms = 3

    /// How many of a theme's notes a phrase must appear in before it may name
    /// the theme. Two is the smallest number that means *shared*.
    static let shared = 2

    /// The separator, which is the same middot every metadata line in the app
    /// already uses.
    static let separator = " · "

    // MARK: The name

    static func name(for members: [Document], in library: [Document]) -> Name {
        let chosen = distinctive(for: members, in: library)
        guard !chosen.isEmpty else { return .none }
        return Name(text: chosen.joined(separator: separator))
    }

    /// The phrases most particular to these notes: common inside the theme, rare
    /// outside it.
    ///
    /// A phrase must appear in **at least two** of the theme's notes, and if
    /// nothing clears that the theme has no name.
    ///
    /// **The relaxation to one note was tried and removed.** `ThemeDumpTests` on
    /// the seed library produced `aspects · attention · automatically` — three
    /// words beginning with `a`, which is the signature of the failure rather
    /// than a coincidence. Where nothing is shared, every candidate carries the
    /// same document frequency, every weight ties exactly, and the alphabetical
    /// tie-break returns the first three words in the group. A theme with nothing
    /// in common has no name to report, and the overview leads with its exemplar
    /// instead — which was always the evidence.
    private static func distinctive(
        for members: [Document],
        in library: [Document]
    ) -> [String] {
        guard !members.isEmpty else { return [] }

        var withinCount: [String: Int] = [:]
        for member in members {
            for phrase in Set(member.phrases) { withinCount[phrase, default: 0] += 1 }
        }
        guard !withinCount.isEmpty else { return [] }

        var acrossCount: [String: Int] = [:]
        for document in library {
            for phrase in Set(document.phrases) { acrossCount[phrase, default: 0] += 1 }
        }

        let corpus = Double(max(library.count, members.count))

        var weighted: [Weighted] = []
        for (phrase, within) in withinCount where within >= shared {
            let across = Double(acrossCount[phrase] ?? within)
            // Frequency inside the theme against rarity across the library — the
            // shape of tf-idf, over documents rather than tokens, because a note
            // is short enough that a repeated word says nothing a present word
            // doesn't.
            let inverse = log((corpus + 1) / (across + 1)) + 1
            let words = phrase.split(separator: " ").map(String.init)
            // **A phrase beats a bare noun on a tie.** `human error` and `error`
            // are often shared by the same notes and weigh the same otherwise;
            // the one that names an idea should win.
            let length = 1 + 0.35 * Double(words.count - 1)
            let weight = Double(within) / Double(members.count) * inverse * length
            weighted.append(Weighted(phrase: phrase, weight: weight, words: Set(words)))
        }

        weighted.sort { $0.weight != $1.weight ? $0.weight > $1.weight : $0.phrase < $1.phrase }

        // **No two picks may share a word.** Without this a name comes out
        // `human error · system error · error messages`, which is one idea said
        // three times and worse than saying it once.
        var chosen: [String] = []
        var spent: Set<String> = []
        for candidate in weighted where chosen.count < terms {
            guard candidate.words.isDisjoint(with: spent) else { continue }
            spent.formUnion(candidate.words)
            chosen.append(candidate.phrase)
        }
        return chosen
    }

    // MARK: Splitting

    /// Lowercased, letters only, three characters or more, stopwords gone.
    ///
    /// The fallback shape, and what the stopword list is written against.
    /// `NounPhrases` is what the app actually calls.
    static func words(in text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    /// English function words, plus the handful of verbs and bookish nouns that
    /// turn up in every note ever written about a book and name nothing.
    static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "can", "her", "was",
        "one", "our", "out", "his", "has", "had", "him", "she", "its", "who", "get",
        "got", "let", "may", "own", "say", "says", "said", "see", "seen", "too", "use",
        "used", "uses", "way", "ways", "why", "how", "what", "when", "where", "which",
        "with", "will", "would", "could", "should", "shall", "might", "must", "have",
        "having", "been", "being", "does", "did", "done", "doing", "from", "into",
        "onto", "than", "that", "them", "then", "they", "this", "these", "those",
        "there", "their", "theirs", "thing", "things", "very", "just", "like", "also",
        "even", "more", "most", "much", "many", "some", "such", "only", "over",
        "under", "after", "before", "again", "about", "above", "below", "between",
        "because", "while", "until", "since", "each", "every", "both", "either",
        "neither", "other", "others", "another", "same", "different", "make", "makes",
        "made", "making", "take", "takes", "took", "taken", "come", "comes", "came",
        "goes", "going", "went", "gone", "know", "knows", "knew", "known", "think",
        "thinks", "thought", "want", "wants", "need", "needs", "give", "gives",
        "given", "find", "finds", "found", "look", "looks", "seem", "seems", "seemed",
        "become", "becomes", "became", "keep", "keeps", "kept", "put", "puts", "lets",
        "here", "were", "isn", "don", "doesn", "didn", "won", "cannot", "never",
        "always", "often", "ever", "still", "yet", "off", "far", "few", "less",
        "least", "lot", "bit", "part", "kind", "sort", "something", "anything",
        "nothing", "everything", "someone", "anyone", "everyone", "nobody", "itself",
        "himself", "herself", "themselves", "myself", "yourself", "book", "books",
        "page", "pages", "note", "notes", "read", "reads", "reading", "write",
        "writes", "writing", "written",
    ]
}

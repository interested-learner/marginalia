import Foundation
import NaturalLanguage

/// Text → the noun phrases in it.
///
/// **The impure half of naming a theme.** `ThemeName` takes phrases and picks
/// the distinctive ones; this is the part that talks to `NaturalLanguage`, and
/// it is a separate file for the same reason `TextScanner` is separate from
/// `ScannedPassage` and `NotificationScheduler` from `NotificationPlan`.
///
/// A theme used to be named by a tag when a majority of its notes shared one.
/// That worked, and it read as though the reader had to tag things for the
/// screen to function — six of seven themes on the seed library came out
/// tag-named, because `SeedLibrary` is deliberately heavily tagged. **Nothing on
/// the map should depend on anything anybody typed**, so tags name nothing now
/// and the words come out of the notes themselves.
///
/// Single words were the first attempt and they read as keyword salad —
/// `error · systems · blame`. A noun phrase is the smallest unit that names an
/// idea rather than gesturing at one: `human error`, `system design`.
nonisolated enum NounPhrases {

    /// Longest phrase kept. Beyond three words a phrase stops being a name and
    /// starts being a fragment of the sentence it came from.
    static let longest = 3

    /// Every noun phrase in the text, plus each noun in them on its own.
    ///
    /// **Both, deliberately.** Phrases are sparse — `human error` appears in one
    /// seed note and `error` in six — so a rule that only compared phrases would
    /// usually find nothing shared and leave the theme unnamed. Emitting the
    /// nouns too gives `ThemeName` a candidate that can actually be shared,
    /// while the phrase wins whenever it *is* shared, because `ThemeName`
    /// rewards length.
    ///
    /// A phrase is `(adjective | noun)* noun` — trailing adjectives are dropped,
    /// because `the design is good` should not offer `good`.
    static func `in`(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var phrases: [String] = []
        var run: [Word] = []

        func flush() {
            defer { run = [] }

            // Back off to the last noun: a run ending in an adjective names
            // nothing.
            guard let end = run.lastIndex(where: \.isNoun) else { return }
            let phrase = Array(run[...end])

            if phrase.count > 1 {
                phrases.append(phrase.suffix(longest).map(\.text).joined(separator: " "))
            }
            phrases.append(contentsOf: phrase.filter(\.isNoun).map(\.text))
        }

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, range in
            let word = text[range].lowercased()

            guard let tag, tag == .noun || tag == .adjective,
                  word.count >= 3, !ThemeName.stopwords.contains(word) else {
                flush()
                return true
            }

            run.append(Word(text: word, isNoun: tag == .noun))
            return true
        }
        flush()

        return phrases
    }

    private struct Word {
        let text: String
        let isNoun: Bool
    }
}

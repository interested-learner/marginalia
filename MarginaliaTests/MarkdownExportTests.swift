import Foundation
import Testing
@testable import Marginalia

/// The whole library as one document. Output shape, link rendering, follow-up
/// nesting — the three things `docs/specs` asks this to prove.
struct MarkdownExportTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func document(_ books: [MarkdownExport.Book]) -> String {
        MarkdownExport.document(books, exported: day(2026, 8, 14), calendar: calendar)
    }

    private var thinking: MarkdownExport.Book {
        MarkdownExport.Book(
            title: "Thinking, Fast and Slow",
            author: "Daniel Kahneman",
            status: "reading",
            notes: [
                MarkdownExport.Note(
                    id: 1,
                    kind: "thought",
                    text: "Attention is a finite budget.",
                    page: 214,
                    tags: ["attention", "memory"],
                    createdAt: day(2026, 8, 1),
                    links: [9, 3]
                )
            ]
        )
    }

    // MARK: Shape

    @Test func theDocumentOpensWithTheWordmarkAndACount() {
        let lines = document([thinking]).components(separatedBy: "\n")
        #expect(lines[0] == "# marginalia")
        #expect(lines[2] == "1 note from 1 book · exported 2026-08-14")
    }

    @Test func aBookIsASectionWithItsBylineUnderIt() {
        let text = document([thinking])
        #expect(text.contains("## Thinking, Fast and Slow"))
        #expect(text.contains("Daniel Kahneman · reading"))
    }

    /// The same rule the book row follows on screen: an absent author closes up
    /// rather than leaving a stray separator.
    @Test func anUnknownAuthorClosesUp() {
        let book = MarkdownExport.Book(title: "Untitled", author: "", status: "queued",
                                       notes: [MarkdownExport.Note(id: 1, text: "a")])
        #expect(document([book]).contains("· queued") == false)
        #expect(document([book]).contains("\nqueued\n"))
    }

    @Test func aNoteIsHeadedByItsIdAndCarriesItsMetadata() {
        let text = document([thinking])
        #expect(text.contains("### n.01"))
        #expect(text.contains("thought · 2026-08-01 · p.214 · #attention #memory"))
    }

    /// `[t]` is a thing the app draws. A document says the word.
    @Test func theMetadataUsesWordsRatherThanMarkers() {
        #expect(document([thinking]).contains("[t]") == false)
    }

    @Test func aPageNobodyRecordedIsLeftOut() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 2, kind: "thought", text: "no page here",
                                createdAt: day(2026, 8, 2))
        ])
        #expect(document([book]).contains("p.") == false)
    }

    @Test func aStarredNoteSaysSo() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 2, text: "x", createdAt: day(2026, 8, 2), isStarred: true)
        ])
        #expect(document([book]).contains("· starred"))
    }

    // MARK: Quotes and threads

    @Test func aQuoteIsABlockquoteAndAThoughtIsAParagraph() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 1, kind: "quote", text: "Confine thyself to the present.",
                                isQuote: true, createdAt: day(2026, 8, 1)),
            MarkdownExport.Note(id: 2, kind: "thought", text: "A plain thought.",
                                createdAt: day(2026, 8, 2))
        ])
        let text = document([book])
        #expect(text.contains("> Confine thyself to the present."))
        #expect(text.contains("\nA plain thought."))
    }

    /// **One level deeper than whatever it answers.** A thread under a thought
    /// is a blockquote; a thread under a quote sits inside the quote it grew
    /// out of.
    @Test func aFollowUpIsNestedUnderTheNoteItAnswers() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 1, text: "A plain thought.", createdAt: day(2026, 8, 1),
                                followUps: [.init(text: "Still true.", createdAt: day(2026, 8, 5))])
        ])
        #expect(document([book]).contains("> 2026-08-05 · Still true."))
    }

    @Test func aFollowUpUnderAQuoteNestsTwice() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 1, kind: "quote", text: "Quoted.", isQuote: true,
                                createdAt: day(2026, 8, 1),
                                followUps: [.init(text: "Held up.", createdAt: day(2026, 8, 5))])
        ])
        #expect(document([book]).contains(">> 2026-08-05 · Held up."))
    }

    /// A quotation that wraps across paragraphs is still one quotation.
    @Test func everyLineOfAQuoteCarriesTheMarker() {
        let book = MarkdownExport.Book(title: "A", notes: [
            MarkdownExport.Note(id: 1, kind: "quote", text: "one\n\ntwo", isQuote: true,
                                createdAt: day(2026, 8, 1))
        ])
        let text = document([book])
        #expect(text.contains("> one\n>\n> two"))
    }

    // MARK: Links

    @Test func connectionsRenderAsWikiLinks() {
        #expect(document([thinking]).contains("[[n.03]] · [[n.09]]"))
    }

    @Test func aNoteWithNoConnectionsHasNoLinkLine() {
        let book = MarkdownExport.Book(title: "A", notes: [MarkdownExport.Note(id: 1, text: "x")])
        #expect(document([book]).contains("[[") == false)
    }

    // MARK: Nothing to say

    @Test func aBookWithNoNotesIsLeftOut() {
        let empty = MarkdownExport.Book(title: "Never Opened", author: "Nobody", status: "queued")
        let text = document([empty, thinking])
        #expect(text.contains("Never Opened") == false)
        #expect(text.contains("1 note from 1 book"))
    }

    @Test func anEmptyLibrarySaysSoRatherThanBeingBlank() {
        #expect(document([]).contains("no notes yet · exported 2026-08-14"))
    }

    @Test func theDocumentEndsWithANewline() {
        #expect(document([thinking]).hasSuffix("\n"))
    }
}

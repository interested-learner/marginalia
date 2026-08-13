import Foundation

/// Static content for phase 1, so the design system can be judged before the
/// SwiftData model exists. Phase 2 replaces every use of this with real queries
/// and moves the seed content into `Model/`.
enum SampleData {

    static let streamToday: [NoteRowData] = [
        NoteRowData(
            id: 11,
            idLabel: Glyphs.noteID(11),
            meta: "\(Glyphs.voice) voice · 2 min ago",
            text: "Attention is a finite budget and switching costs are paid in comprehension — same as context switching in engineering work.",
            isQuote: false,
            source: "Thinking, Fast and Slow · p.214 · #systems"
        ),
        NoteRowData(
            id: 10,
            idLabel: Glyphs.noteID(10),
            meta: "\(Glyphs.thought) thought · 1 hr ago",
            text: "Good error messages assume the user is competent and the system is at fault. Applies to people too.",
            isQuote: false,
            source: "The Design of Everyday Things · p.65 · #design",
            links: [Glyphs.noteID(9)]
        ),
    ]

    static let streamYesterday: [NoteRowData] = [
        NoteRowData(
            id: 9,
            idLabel: Glyphs.noteID(9),
            meta: "\(Glyphs.quote) quote · #stoicism",
            text: "Confine thyself to the present.",
            isQuote: true,
            source: "Meditations · p.47"
        ),
        NoteRowData(
            id: 8,
            idLabel: Glyphs.noteID(8),
            meta: "\(Glyphs.thought) thought",
            text: "Gumption traps map exactly onto debugging morale. Setbacks are part of the work, not interruptions to it.",
            isQuote: false,
            source: "Zen and the Art of Motorcycle Maintenance · p.160 · #craft",
            links: [Glyphs.noteID(3)]
        ),
        NoteRowData(
            id: 7,
            idLabel: Glyphs.noteID(7),
            meta: "\(Glyphs.thought) thought · #quality",
            text: "Quality can't be defined but you know it when you see it — the same problem as \u{201C}good taste\u{201D} in code review.",
            isQuote: false,
            source: "Zen and the Art of Motorcycle Maintenance · p.184",
            links: [Glyphs.noteID(1), Glyphs.noteID(9)]
        ),
    ]

    static let books: [BookRowData] = [
        BookRowData(id: 1, marker: Glyphs.reading, title: "Thinking, Fast and Slow",
                    author: "Daniel Kahneman", status: "reading", count: 4),
        BookRowData(id: 2, marker: Glyphs.finished, title: "Meditations",
                    author: "Marcus Aurelius", status: "finished", count: 3),
        BookRowData(id: 3, marker: Glyphs.reading, title: "Zen and the Art of Motorcycle Maintenance",
                    author: "Robert M. Pirsig", status: "reading", count: 2),
        BookRowData(id: 4, marker: Glyphs.queued, title: "The Beginning of Infinity",
                    author: "David Deutsch", status: "queued", count: 0),
        BookRowData(id: 5, marker: Glyphs.finished, title: "The Design of Everyday Things",
                    author: "Don Norman", status: "finished", count: 2),
        BookRowData(id: 0, marker: Glyphs.inbox, title: "Inbox",
                    author: "quick captures, unfiled", status: "inbox", count: 1),
    ]

    static let tags = ["all", "#systems", "#quality", "#design", "#stoicism", "#craft"]
}

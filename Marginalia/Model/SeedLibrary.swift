import Foundation

/// What a fresh install opens onto.
///
/// Forty notes, not twelve. Two reasons: a sparse map proves nothing about
/// whether the layout works in phase 7, and phase 6 tunes the affinity weights
/// against this content — so the notes need **genuine conceptual overlap across
/// books**, not forty unrelated sentences. `attention`, `error`, `quality`,
/// `memory` and `systems` each run through three or four different authors on
/// purpose; that's the signal the embedder is supposed to find without being
/// told.
///
/// Values only, no SwiftData. `Library.prepare` turns them into models.
nonisolated enum SeedLibrary {

    // MARK: Shapes

    struct BookSeed {
        let key: String
        let title: String
        let author: String
        let status: BookStatus
        var pageCount: Int = 0
        var currentPage: Int = 0
    }

    /// Ages are expressed against launch, so a fresh install always opens onto
    /// a stream with all three date headers in it.
    ///
    /// Older notes are placed by **calendar day** rather than by elapsed hours:
    /// `daysAgo(1)` has to read as `yesterday` whether the app is first opened
    /// at nine in the morning or ten at night.
    enum Age {
        case minutesAgo(Int)
        case daysAgo(Int, hour: Int)
    }

    struct NoteSeed {
        let key: String
        let book: String
        let kind: NoteKind
        let text: String
        var page: Int?
        var tags: [String] = []
        let age: Age
        var starred: Bool = false
    }

    /// Seeded connections are **pinned**, which is what stops phase 6's first
    /// recompute from pruning them. They are hand-picked rather than plausible
    /// filler: each pair is one a reader would defend.
    struct EdgeSeed {
        let a: String
        let b: String
    }

    // MARK: Books

    static let books: [BookSeed] = [
        BookSeed(key: "kahneman", title: "Thinking, Fast and Slow", author: "Daniel Kahneman",
                 status: .reading, pageCount: 499, currentPage: 214),
        BookSeed(key: "aurelius", title: "Meditations", author: "Marcus Aurelius",
                 status: .finished, pageCount: 254, currentPage: 254),
        BookSeed(key: "pirsig", title: "Zen and the Art of Motorcycle Maintenance", author: "Robert M. Pirsig",
                 status: .reading, pageCount: 418, currentPage: 284),
        BookSeed(key: "deutsch", title: "The Beginning of Infinity", author: "David Deutsch",
                 status: .queued, pageCount: 487),
        BookSeed(key: "norman", title: "The Design of Everyday Things", author: "Don Norman",
                 status: .finished, pageCount: 368, currentPage: 368),
        BookSeed(key: "inbox", title: Inbox.title, author: Inbox.author,
                 status: .inbox),
    ]

    // MARK: Notes — oldest first, so ids ascend the way they were written

    static let notes: [NoteSeed] = [

        // The Design of Everyday Things — read first, finished.

        NoteSeed(key: "nor.invisible", book: "norman", kind: .quote,
                 text: "Good design is actually a lot harder to notice than poor design, in part because good designs fit our needs so well that the design is invisible.",
                 page: 10, tags: ["design", "quality"], age: .daysAgo(41, hour: 21)),

        NoteSeed(key: "nor.affordance", book: "norman", kind: .thought,
                 text: "Affordances aren't properties of an object — they're relationships between the object and whoever is using it. Which means the same interface can be obvious to me and opaque to you, and neither of us is wrong.",
                 page: 14, tags: ["design", "systems"], age: .daysAgo(40, hour: 8)),

        NoteSeed(key: "nor.errors", book: "norman", kind: .thought,
                 text: "Good error messages assume the user is competent and the system is at fault. Applies to people too.",
                 page: 65, tags: ["design", "error"], age: .daysAgo(38, hour: 22)),

        NoteSeed(key: "nor.systemerror", book: "norman", kind: .quote,
                 text: "Human error usually is a result of poor design: it should be called system error.",
                 page: 68, tags: ["error", "systems"], age: .daysAgo(36, hour: 20), starred: true),

        NoteSeed(key: "nor.slips", book: "norman", kind: .thought,
                 text: "Slips and mistakes are different failures — one is the right plan executed wrong, the other is the wrong plan executed perfectly. Typos versus wrong algorithms. Treating them the same is why so much review is wasted.",
                 page: 72, tags: ["error", "quality"], age: .daysAgo(34, hour: 9)),

        NoteSeed(key: "nor.discoverability", book: "norman", kind: .thought,
                 text: "Discoverability is a memory subsidy. Every control you can see is one you don't have to remember.",
                 page: 130, tags: ["design", "memory"], age: .daysAgo(32, hour: 19)),

        NoteSeed(key: "nor.forcing", book: "norman", kind: .thought,
                 text: "Forcing functions are the humane version of discipline — they make the wrong thing impossible rather than shameful.",
                 page: 220, tags: ["design", "habit"], age: .daysAgo(30, hour: 7)),

        // Meditations.

        NoteSeed(key: "mar.present", book: "aurelius", kind: .quote,
                 text: "Confine thyself to the present.",
                 page: 12, tags: ["stoicism", "attention"], age: .daysAgo(29, hour: 6)),

        NoteSeed(key: "mar.weather", book: "aurelius", kind: .thought,
                 text: "The whole book is one instruction written down over and over: notice what is yours to decide, and let the rest be weather.",
                 page: 14, tags: ["stoicism", "control"], age: .daysAgo(28, hour: 21)),

        NoteSeed(key: "mar.mind", book: "aurelius", kind: .quote,
                 text: "You have power over your mind — not outside events. Realize this, and you will find strength.",
                 page: 47, tags: ["stoicism", "control"], age: .daysAgo(26, hour: 7), starred: true),

        NoteSeed(key: "mar.planning", book: "aurelius", kind: .thought,
                 text: "Half of what I plan for is weather. The planning is still worth doing; the anxiety attached to it isn't.",
                 page: 51, tags: ["stoicism", "control", "attention"], age: .daysAgo(24, hour: 22)),

        NoteSeed(key: "mar.beone", book: "aurelius", kind: .quote,
                 text: "Waste no more time arguing about what a good man should be. Be one.",
                 page: 88, tags: ["stoicism", "craft"], age: .daysAgo(23, hour: 8)),

        NoteSeed(key: "mar.repetition", book: "aurelius", kind: .thought,
                 text: "Marcus writes the same lesson down again and again, which is the point — he clearly hadn't learned it either. Repetition isn't a failure to progress. It's what progress looks like from the inside.",
                 page: 96, tags: ["stoicism", "habit", "memory"], age: .daysAgo(22, hour: 20)),

        NoteSeed(key: "mar.opinion", book: "aurelius", kind: .quote,
                 text: "Everything we hear is an opinion, not a fact. Everything we see is a perspective, not the truth.",
                 page: 140, tags: ["stoicism", "attention"], age: .daysAgo(21, hour: 12)),

        NoteSeed(key: "mar.memento", book: "aurelius", kind: .thought,
                 text: "Memento mori reads as morbid right up until you notice it's a prioritization algorithm.",
                 page: 198, tags: ["stoicism", "attention"], age: .daysAgo(20, hour: 23)),

        // Zen and the Art of Motorcycle Maintenance, and Thinking, Fast and Slow —
        // both open at once, and the second keeps arguing with the first.

        NoteSeed(key: "pir.truth", book: "pirsig", kind: .quote,
                 text: "The truth knocks on the door and you say, go away, I'm looking for the truth, and so it goes away.",
                 page: 24, tags: ["quality", "attention"], age: .daysAgo(19, hour: 9)),

        NoteSeed(key: "kah.system1", book: "kahneman", kind: .quote,
                 text: "System 1 operates automatically and quickly, with little or no effort and no sense of voluntary control.",
                 page: 20, tags: ["attention", "systems"], age: .daysAgo(18, hour: 21)),

        NoteSeed(key: "kah.cost", book: "kahneman", kind: .thought,
                 text: "System 1 and System 2 aren't two people living in your head. They're a name for how much it costs to think about something, and what you will quietly do to avoid paying.",
                 page: 24, tags: ["attention", "systems"], age: .daysAgo(17, hour: 8)),

        NoteSeed(key: "pir.stuck", book: "pirsig", kind: .thought,
                 text: "Pirsig's stuckness is the debugger's plateau. The stuck feeling is information — it means the model I brought is wrong, not that I'm slow.",
                 page: 60, tags: ["craft", "quality"], age: .daysAgo(16, hour: 22)),

        NoteSeed(key: "kah.ease", book: "kahneman", kind: .thought,
                 text: "Cognitive ease makes a familiar falsehood feel true. The same mechanism makes a codebase you wrote yourself feel well designed.",
                 page: 45, tags: ["memory", "quality"], age: .daysAgo(15, hour: 20)),

        NoteSeed(key: "inb.filing", book: "inbox", kind: .thought,
                 text: "The best filing system is the one you would still use while tired.",
                 tags: ["systems", "habit"], age: .daysAgo(15, hour: 7)),

        NoteSeed(key: "kah.important", book: "kahneman", kind: .quote,
                 text: "Nothing in life is as important as you think it is while you are thinking about it.",
                 page: 85, tags: ["attention"], age: .daysAgo(14, hour: 23), starred: true),

        NoteSeed(key: "pir.system", book: "pirsig", kind: .thought,
                 text: "The motorcycle you're working on is a system you are part of, not an object sitting across from you. Same with a codebase, and it explains why the ones I inherit feel hostile for the first month.",
                 page: 100, tags: ["systems", "craft"], age: .daysAgo(13, hour: 19)),

        NoteSeed(key: "kah.anchoring", book: "kahneman", kind: .thought,
                 text: "Anchoring is why every estimate meeting should open in silence. The first number said out loud is the only one that matters afterward.",
                 page: 88, tags: ["systems", "error"], age: .daysAgo(12, hour: 9)),

        NoteSeed(key: "pir.cycle", book: "pirsig", kind: .quote,
                 text: "The real cycle you're working on is a cycle called yourself.",
                 page: 160, tags: ["craft"], age: .daysAgo(11, hour: 21)),

        NoteSeed(key: "kah.availability", book: "kahneman", kind: .thought,
                 text: "Availability is a memory bug being read as evidence. Whatever comes to mind fastest gets treated as whatever happens most.",
                 page: 109, tags: ["memory", "error"], age: .daysAgo(10, hour: 8)),

        NoteSeed(key: "pir.gumption", book: "pirsig", kind: .thought,
                 text: "Gumption traps map exactly onto debugging morale. Setbacks are part of the work, not interruptions to it.",
                 page: 161, tags: ["craft", "attention"], age: .daysAgo(9, hour: 22)),

        NoteSeed(key: "kah.hindsight", book: "kahneman", kind: .quote,
                 text: "The idea that the future is unpredictable is undermined every day by the ease with which the past is explained.",
                 page: 201, tags: ["memory", "error"], age: .daysAgo(8, hour: 20)),

        NoteSeed(key: "inb.maintenance", book: "inbox", kind: .thought,
                 text: "Every tool I've abandoned asked me to do maintenance work it could have done itself.",
                 tags: ["design", "habit"], age: .daysAgo(7, hour: 12)),

        NoteSeed(key: "pir.quality", book: "pirsig", kind: .thought,
                 text: "Quality can't be defined but you know it when you see it — which is the same problem as good taste in code review, and the same reason neither survives being turned into a checklist.",
                 page: 184, tags: ["quality", "craft"], age: .daysAgo(6, hour: 21), starred: true),

        NoteSeed(key: "kah.postmortem", book: "kahneman", kind: .thought,
                 text: "Hindsight makes every outage look preventable, which is why a postmortem has to be written against the information available at the time and not the information available now.",
                 page: 203, tags: ["error", "systems", "quality"], age: .daysAgo(5, hour: 9)),

        NoteSeed(key: "pir.care", book: "pirsig", kind: .quote,
                 text: "Care and Quality are internal and external aspects of the same thing.",
                 page: 190, tags: ["quality", "craft"], age: .daysAgo(4, hour: 22)),

        NoteSeed(key: "kah.twoselves", book: "kahneman", kind: .thought,
                 text: "The remembering self and the experiencing self want different books. I keep buying for the first one.",
                 page: 208, tags: ["memory", "attention"], age: .daysAgo(3, hour: 20)),

        NoteSeed(key: "pir.peace", book: "pirsig", kind: .thought,
                 text: "Peace of mind isn't the reward for good work, it's the precondition. You can't see the fault in a machine while you're angry at it.",
                 page: 247, tags: ["craft", "attention"], age: .daysAgo(2, hour: 21)),

        NoteSeed(key: "inb.twobooks", book: "inbox", kind: .voice,
                 text: "Reading two books at once isn't dilution — the second one keeps arguing with the first, and the argument is where the notes come from.",
                 tags: ["attention", "habit"], age: .daysAgo(2, hour: 8)),

        NoteSeed(key: "inb.review", book: "inbox", kind: .voice,
                 text: "Idea for the reading log: weight the daily set toward notes I've never followed up on, rather than notes I've never seen.",
                 tags: ["systems"], age: .daysAgo(1, hour: 23)),

        NoteSeed(key: "pir.romantic", book: "pirsig", kind: .thought,
                 text: "Pirsig calls it romantic versus classical understanding; Norman would call it experience versus mechanism. Both are saying you cannot design well while holding only one of them.",
                 page: 284, tags: ["quality", "design"], age: .daysAgo(1, hour: 20)),

        NoteSeed(key: "inb.stars", book: "inbox", kind: .thought,
                 text: "Note to self: stop starring things. Star everything and you have starred nothing.",
                 tags: ["habit", "systems"], age: .daysAgo(1, hour: 9)),

        NoteSeed(key: "inb.findable", book: "inbox", kind: .thought,
                 text: "A note you can't find is a note you didn't take.",
                 tags: ["systems", "memory"], age: .minutesAgo(41)),

        NoteSeed(key: "kah.budget", book: "kahneman", kind: .voice,
                 text: "Attention is a finite budget and switching costs are paid in comprehension — same as context switching in engineering work.",
                 page: 214, tags: ["attention", "systems"], age: .minutesAgo(2)),
    ]

    // MARK: Connections

    static let edges: [EdgeSeed] = [
        EdgeSeed(a: "nor.errors", b: "nor.systemerror"),
        EdgeSeed(a: "nor.slips", b: "kah.postmortem"),
        EdgeSeed(a: "nor.affordance", b: "pir.romantic"),
        EdgeSeed(a: "nor.discoverability", b: "inb.findable"),
        EdgeSeed(a: "nor.forcing", b: "mar.repetition"),
        EdgeSeed(a: "mar.present", b: "kah.budget"),
        EdgeSeed(a: "mar.memento", b: "kah.important"),
        EdgeSeed(a: "mar.weather", b: "mar.planning"),
        EdgeSeed(a: "kah.cost", b: "kah.anchoring"),
        EdgeSeed(a: "kah.availability", b: "kah.twoselves"),
        EdgeSeed(a: "kah.hindsight", b: "kah.postmortem"),
        EdgeSeed(a: "pir.gumption", b: "kah.budget"),
        EdgeSeed(a: "pir.quality", b: "nor.invisible"),
        EdgeSeed(a: "pir.quality", b: "pir.care"),
        EdgeSeed(a: "pir.stuck", b: "pir.peace"),
        EdgeSeed(a: "inb.filing", b: "inb.findable"),
    ]

    // MARK: Dates

    static func date(for age: Age, now: Date, calendar: Calendar) -> Date {
        switch age {
        case .minutesAgo(let minutes):
            return now.addingTimeInterval(-60 * Double(minutes))
        case .daysAgo(let days, let hour):
            guard let day = calendar.date(byAdding: .day, value: -days, to: now) else { return now }
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
    }
}

import Foundation

/// The sample library — **not** what a fresh install opens onto.
///
/// Since phase 15 a reader's first launch gets the Inbox and nothing else
/// (`docs/decisions.md` §25). This is reached only through `-sampleLibrary 1`
/// and `-tinyLibrary <n>`, and by the tests, and it is the content every App
/// Store screenshot is taken against.
///
/// Forty notes, not twelve, for a reason that outlived the screen it was
/// written for: phase 6 tunes the affinity weights against this content, so the
/// notes need **genuine conceptual overlap across books** rather than forty
/// unrelated sentences. `attention`, `solitude`, `habit`, `doubt` and
/// `conformity` each run through three or four different authors on purpose —
/// that is the signal the embedder is supposed to find without being told, and
/// it is what gives the crossing card anything to show.
///
/// **Everything here is public domain**, including the translations. See the
/// note on `books` below.
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

    /// A note that has already been answered once, so a fresh install shows what
    /// `[+] add a thought` produces rather than only offering it.
    ///
    /// Deliberately few — a library where every note has a thread would misread
    /// as the normal state, and the point of the action is that it's occasional.
    struct FollowUpSeed {
        let note: String
        let text: String
        let age: Age
    }

    // MARK: Books

    /// **Public domain, deliberately.** The sample library ships inside the
    /// binary and appears in every App Store screenshot, and the first version
    /// of it quoted four books that are still in copyright. A reader copying a
    /// passage into their own notes is one thing; redistributing those passages
    /// as app content to every installer, and publishing them on a store page,
    /// is another. `docs/decisions.md` §27.
    ///
    /// Translations carry their own copyright, so the two translated authors
    /// use the ones that are clear: **Marcus Aurelius in George Long (1862)**
    /// and **Montaigne in Charles Cotton (1685)**. Modern translations are not
    /// interchangeable here even though they read better.
    static let books: [BookSeed] = [
        BookSeed(key: "aurelius", title: "Meditations", author: "Marcus Aurelius",
                 status: .finished, pageCount: 254),
        BookSeed(key: "montaigne", title: "Essays", author: "Michel de Montaigne",
                 status: .reading, pageCount: 1344),
        BookSeed(key: "thoreau", title: "Walden", author: "Henry David Thoreau",
                 status: .reading, pageCount: 352),
        BookSeed(key: "james", title: "The Principles of Psychology", author: "William James",
                 status: .reading, pageCount: 1393),
        BookSeed(key: "emerson", title: "Self-Reliance and Other Essays", author: "Ralph Waldo Emerson",
                 status: .queued, pageCount: 176),
        BookSeed(key: "inbox", title: Inbox.title, author: Inbox.author,
                 status: .inbox),
    ]

    // MARK: Notes — grouped by book, ages ascending, so ids read as written

    static let notes: [NoteSeed] = [

        // Meditations — read first, finished. Long's translation.

        NoteSeed(key: "mar.retreat", book: "aurelius", kind: .quote,
                 text: "Men seek retreats for themselves — houses in the country, sea-shores, mountains. But it is in thy power whenever thou shalt choose to retire into thyself.",
                 page: 44, tags: ["solitude", "attention"], age: .daysAgo(45, hour: 7), starred: true),

        NoteSeed(key: "mar.present", book: "aurelius", kind: .quote,
                 text: "Confine thyself to the present.",
                 page: 52, tags: ["attention", "time"], age: .daysAgo(42, hour: 6)),

        NoteSeed(key: "mar.judgement", book: "aurelius", kind: .quote,
                 text: "If thou art pained by any external thing, it is not this thing that disturbs thee, but thy own judgement about it.",
                 page: 118, tags: ["judgement", "control"], age: .daysAgo(38, hour: 21), starred: true),

        NoteSeed(key: "mar.last", book: "aurelius", kind: .quote,
                 text: "Do every act of thy life as if it were thy last.",
                 page: 27, tags: ["time", "attention"], age: .daysAgo(35, hour: 8)),

        NoteSeed(key: "mar.inward", book: "aurelius", kind: .thought,
                 text: "\"Retire into thyself\" is not a holiday. He means an attention you can enter without going anywhere, which is harder than the country house and cheaper.",
                 tags: ["solitude", "attention"], age: .daysAgo(33, hour: 20)),

        NoteSeed(key: "mar.queue", book: "aurelius", kind: .thought,
                 text: "Every time I read the judgement line I want it to be about big things. It is almost always about a queue.",
                 tags: ["judgement"], age: .daysAgo(31, hour: 7)),

        NoteSeed(key: "mar.repetition", book: "aurelius", kind: .thought,
                 text: "He repeats himself constantly and I think that is the form rather than a flaw. A private notebook is allowed to say the same thing until it takes.",
                 tags: ["habit", "memory"], age: .daysAgo(30, hour: 22)),

        NoteSeed(key: "mar.have", book: "aurelius", kind: .quote,
                 text: "Think not so much of what thou hast not as of what thou hast.",
                 page: 163, tags: ["time", "attention"], age: .daysAgo(24, hour: 9)),

        // Essays — Cotton's translation. Still reading; it is not a book you finish.

        NoteSeed(key: "mon.quote", book: "montaigne", kind: .quote,
                 text: "I quote others only in order the better to express myself.",
                 page: 171, tags: ["reading", "self"], age: .daysAgo(34, hour: 19), starred: true),

        NoteSeed(key: "mon.know", book: "montaigne", kind: .quote,
                 text: "What do I know?",
                 page: 393, tags: ["doubt", "judgement"], age: .daysAgo(29, hour: 21)),

        NoteSeed(key: "mon.patchwork", book: "montaigne", kind: .quote,
                 text: "We are all patchwork, and so shapeless and diverse in composition that each bit, each moment, plays its own game.",
                 page: 244, tags: ["self", "doubt"], age: .daysAgo(26, hour: 20), starred: true),

        NoteSeed(key: "mon.belong", book: "montaigne", kind: .quote,
                 text: "The greatest thing in the world is to know how to belong to oneself.",
                 page: 178, tags: ["solitude", "self"], age: .daysAgo(22, hour: 7)),

        NoteSeed(key: "mon.borrow", book: "montaigne", kind: .thought,
                 text: "He quotes more than he writes and it never reads as borrowed. The trick seems to be that he argues with the quote instead of hiding behind it.",
                 tags: ["reading", "self"], age: .daysAgo(19, hour: 21)),

        NoteSeed(key: "mon.doubt", book: "montaigne", kind: .thought,
                 text: "\"What do I know\" is a question he asks himself, not the reader. Completely different sentence from the way it gets quoted at people.",
                 tags: ["doubt"], age: .daysAgo(16, hour: 8)),

        NoteSeed(key: "mon.essayer", book: "montaigne", kind: .thought,
                 text: "Essayer — to try, to attempt. Every one of these is a draft he decided not to finish, which is exactly why they are still alive.",
                 tags: ["reading", "craft"], age: .daysAgo(14, hour: 22)),

        NoteSeed(key: "mon.knowledge", book: "montaigne", kind: .quote,
                 text: "There is no desire more natural than the desire for knowledge.",
                 page: 612, tags: ["reading"], age: .daysAgo(12, hour: 9)),

        // Walden.

        NoteSeed(key: "tho.deliberately", book: "thoreau", kind: .quote,
                 text: "I went to the woods because I wished to live deliberately, to front only the essential facts of life.",
                 page: 90, tags: ["attention", "simplicity"], age: .daysAgo(28, hour: 20), starred: true),

        NoteSeed(key: "tho.simplify", book: "thoreau", kind: .quote,
                 text: "Our life is frittered away by detail. Simplify, simplify.",
                 page: 91, tags: ["simplicity", "attention"], age: .daysAgo(25, hour: 7)),

        NoteSeed(key: "tho.desperation", book: "thoreau", kind: .quote,
                 text: "The mass of men lead lives of quiet desperation.",
                 page: 8, tags: ["conformity"], age: .daysAgo(21, hour: 21)),

        NoteSeed(key: "tho.chairs", book: "thoreau", kind: .quote,
                 text: "I had three chairs in my house; one for solitude, two for friendship, three for society.",
                 page: 140, tags: ["solitude"], age: .daysAgo(18, hour: 19)),

        NoteSeed(key: "tho.tools", book: "thoreau", kind: .quote,
                 text: "Men have become the tools of their tools.",
                 page: 37, tags: ["simplicity", "systems"], age: .daysAgo(15, hour: 20), starred: true),

        NoteSeed(key: "tho.onpurpose", book: "thoreau", kind: .thought,
                 text: "\"Deliberately\" is doing all the work in that sentence. Not slowly — on purpose. You can be deliberate at speed, which is the part people leave out.",
                 tags: ["attention"], age: .daysAgo(11, hour: 8)),

        NoteSeed(key: "tho.cost", book: "thoreau", kind: .quote,
                 text: "The cost of a thing is the amount of what I will call life which is required to be exchanged for it.",
                 page: 31, tags: ["time", "simplicity"], age: .daysAgo(8, hour: 21)),

        NoteSeed(key: "tho.town", book: "thoreau", kind: .thought,
                 text: "He walked into town most days. The cabin was a study rather than an escape, and the book gets worse if you forget that.",
                 tags: ["solitude"], age: .daysAgo(5, hour: 20)),

        NoteSeed(key: "tho.morning", book: "thoreau", kind: .quote,
                 text: "Morning is when I am awake and there is a dawn in me.",
                 page: 94, tags: ["attention"], age: .daysAgo(2, hour: 7)),

        // The Principles of Psychology. Long, and being read in pieces.

        NoteSeed(key: "jam.attend", book: "james", kind: .quote,
                 text: "My experience is what I agree to attend to.",
                 page: 402, tags: ["attention", "self"], age: .daysAgo(20, hour: 21), starred: true),

        NoteSeed(key: "jam.flywheel", book: "james", kind: .quote,
                 text: "Habit is thus the enormous fly-wheel of society, its most precious conservative agent.",
                 page: 121, tags: ["habit", "systems"], age: .daysAgo(17, hour: 20)),

        NoteSeed(key: "jam.overlook", book: "james", kind: .quote,
                 text: "The art of being wise is the art of knowing what to overlook.",
                 page: 369, tags: ["attention", "judgement"], age: .daysAgo(13, hour: 8)),

        NoteSeed(key: "jam.interest", book: "james", kind: .quote,
                 text: "Millions of items of the outward order are present to my senses which never properly enter into my experience. Why? Because they have no interest for me.",
                 page: 402, tags: ["attention"], age: .daysAgo(10, hour: 22)),

        NoteSeed(key: "jam.ally", book: "james", kind: .thought,
                 text: "The habit chapter reads as a warning and a set of instructions at the same time. Make the nervous system an ally rather than an enemy, before it decides for itself.",
                 tags: ["habit"], age: .daysAgo(7, hour: 20)),

        NoteSeed(key: "jam.agree", book: "james", kind: .thought,
                 text: "\"What I agree to attend to\" — agree. He puts it as consent, which makes every distraction something I said yes to.",
                 tags: ["attention", "self"], age: .daysAgo(4, hour: 21), starred: true),

        NoteSeed(key: "jam.stream", book: "james", kind: .quote,
                 text: "Consciousness does not appear to itself chopped up in bits. It is nothing jointed; it flows.",
                 page: 239, tags: ["attention"], age: .daysAgo(1, hour: 9)),

        NoteSeed(key: "jam.after", book: "james", kind: .thought,
                 text: "Reading James after Aurelius is strange. One is a laboratory and one is a notebook, and they arrive at the same place about attention from opposite ends.",
                 tags: ["attention", "reading"], age: .minutesAgo(38)),

        // Self-Reliance — queued, and dipped into out of order anyway.

        NoteSeed(key: "eme.consistency", book: "emerson", kind: .quote,
                 text: "A foolish consistency is the hobgoblin of little minds.",
                 page: 33, tags: ["conformity", "doubt"], age: .daysAgo(9, hour: 21), starred: true),

        NoteSeed(key: "eme.nonconformist", book: "emerson", kind: .quote,
                 text: "Whoso would be a man must be a nonconformist.",
                 page: 29, tags: ["conformity"], age: .daysAgo(6, hour: 20)),

        NoteSeed(key: "eme.trust", book: "emerson", kind: .quote,
                 text: "Trust thyself: every heart vibrates to that iron string.",
                 page: 27, tags: ["self"], age: .daysAgo(3, hour: 8)),

        NoteSeed(key: "eme.misunderstood", book: "emerson", kind: .quote,
                 text: "To be great is to be misunderstood.",
                 page: 34, tags: ["conformity", "doubt"], age: .daysAgo(3, hour: 21)),

        // Inbox — captured without a book, to be filed later.

        NoteSeed(key: "inb.findable", book: "inbox", kind: .thought,
                 text: "A note you can't find is a note you didn't take.",
                 tags: ["systems", "memory"], age: .daysAgo(13, hour: 21)),

        NoteSeed(key: "inb.filing", book: "inbox", kind: .voice,
                 text: "Idea for the reading log: weight the daily set toward notes I've never followed up on, rather than notes I've never seen.",
                 tags: ["systems"], age: .daysAgo(1, hour: 11)),

        NoteSeed(key: "inb.budget", book: "inbox", kind: .voice,
                 text: "Attention is a finite budget and switching costs are paid in comprehension — same as context switching in engineering work.",
                 tags: ["attention", "systems"], age: .minutesAgo(32)),
    ]

    // MARK: Connections

    /// Hand-picked and **cross-book wherever the pairing earns it**, because a
    /// crossing is the one thing the app computes that nothing else does and it
    /// needs real material to find. Pinned, so phase 6's first recompute keeps
    /// them.
    static let edges: [EdgeSeed] = [
        // Attention, running through four authors on purpose.
        EdgeSeed(a: "jam.attend", b: "mar.present"),
        EdgeSeed(a: "jam.attend", b: "tho.deliberately"),
        EdgeSeed(a: "mar.present", b: "tho.deliberately"),
        EdgeSeed(a: "jam.interest", b: "jam.attend"),
        EdgeSeed(a: "inb.budget", b: "jam.attend"),
        EdgeSeed(a: "jam.agree", b: "jam.attend"),

        // Inconsistency — Emerson defending it, Montaigne describing it.
        EdgeSeed(a: "eme.consistency", b: "mon.patchwork"),
        EdgeSeed(a: "mon.know", b: "eme.misunderstood"),

        // Solitude, and what it is actually for.
        EdgeSeed(a: "mon.belong", b: "tho.chairs"),
        EdgeSeed(a: "tho.simplify", b: "mar.retreat"),
        EdgeSeed(a: "mon.belong", b: "eme.trust"),

        // Habit.
        EdgeSeed(a: "jam.flywheel", b: "mar.repetition"),
        EdgeSeed(a: "jam.ally", b: "jam.flywheel"),

        // Judgement, conformity, time.
        EdgeSeed(a: "jam.overlook", b: "mar.judgement"),
        EdgeSeed(a: "tho.desperation", b: "eme.nonconformist"),
        EdgeSeed(a: "tho.cost", b: "mar.have"),
        EdgeSeed(a: "inb.findable", b: "inb.filing"),
    ]

    // MARK: Follow-ups

    /// Three notes that have already been answered, out of forty. Written as
    /// answers rather than restatements — the point of a thread is that the
    /// second thought disagrees with, qualifies, or applies the first.
    static let followUps: [FollowUpSeed] = [
        FollowUpSeed(note: "tho.simplify",
                     text: "Held up for a month, except on the days when the detail was the work. Thoreau has very little to say about the days when the detail is the work.",
                     age: .daysAgo(9, hour: 20)),

        FollowUpSeed(note: "mar.judgement",
                     text: "Read this again on a bad week and it landed as instruction rather than comfort, which I think is how it was meant.",
                     age: .daysAgo(4, hour: 7)),

        FollowUpSeed(note: "jam.attend",
                     text: "Tried treating every notification as something I had agreed to. Lasted two days, which is longer than I expected and shorter than I wanted.",
                     age: .daysAgo(2, hour: 18)),
    ]

    // MARK: A smaller library

    /// The seed cut down to `limit` notes, for `-tinyLibrary`. `nil` is all of
    /// them, which is what a real first launch gets.
    ///
    /// **Spread across books, one at a time, rather than taken off the front.**
    /// The list is grouped by book, so the first four notes are all Norman —
    /// and `ReviewSetBuilder` allows at most two cards per book, so a prefix of
    /// four builds a set of two and lands on the *empty* state no matter how
    /// many notes you asked for. Round-robin gives four notes four books, which
    /// is a full set of four with nothing left over: the exhausted
    /// `[↻] keep going` that has never been seen either.
    ///
    /// Dates come from the seeds themselves, so a tiny library still reads as
    /// one written over weeks rather than in one sitting.
    static func sample(_ limit: Int?) -> [NoteSeed] {
        guard let limit else { return notes }
        guard limit > 0 else { return [] }

        var byBook: [[NoteSeed]] = []
        var index: [String: Int] = [:]
        for seed in notes {
            if let at = index[seed.book] {
                byBook[at].append(seed)
            } else {
                index[seed.book] = byBook.count
                byBook.append([seed])
            }
        }

        var taken: [NoteSeed] = []
        var round = 0
        while taken.count < limit, byBook.contains(where: { round < $0.count }) {
            for book in byBook where round < book.count && taken.count < limit {
                taken.append(book[round])
            }
            round += 1
        }
        // Left in round-robin order. `Library.seed` allocates ids by `createdAt`
        // regardless of how this list happens to be ordered, so `n.01` is still
        // the oldest note in the tiny library too.
        return taken
    }

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

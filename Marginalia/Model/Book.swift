import Foundation
import SwiftData

/// Reading state. Stored as a raw string rather than an enum — SwiftData
/// handles enums poorly across schema changes, and `"reading"` stays readable
/// when you open the store with anything else.
nonisolated enum BookStatus: String, CaseIterable, Sendable {
    case reading, finished, queued, inbox

    var marker: String {
        switch self {
        case .reading: Glyphs.reading
        case .finished: Glyphs.finished
        case .queued: Glyphs.queued
        case .inbox: Glyphs.inbox
        }
    }

    var label: String { rawValue }
}

/// The Inbox's identity, in one place.
///
/// The first-launch seed builds it and so does a capture that arrives to find
/// it missing. Written out twice they would eventually drift, and the user
/// would have two drawers instead of one.
nonisolated enum Inbox {
    static let title = "Inbox"
    static let author = "quick captures, unfiled"
}

/// A book, or the Inbox — which is a book like any other, so unfiled captures
/// are never invisible.
///
/// Every property is defaulted and every relationship optional. Those are
/// CloudKit's requirements, adopted now so enabling sync later is a container
/// configuration change rather than a migration.
@Model
final class Book {
    var title: String = ""
    var author: String = ""
    var statusRaw: String = BookStatus.queued.rawValue
    /// How long the book is, when anybody knows. 0 is unknown, which manual
    /// entry leaves it as often. **Not how far in the reader is** — see
    /// `docs/decisions.md` §17.
    var pageCount: Int = 0
    var isbn: String?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]? = []

    init(
        title: String = "",
        author: String = "",
        status: BookStatus = .queued,
        pageCount: Int = 0,
        isbn: String? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.author = author
        self.statusRaw = status.rawValue
        self.pageCount = pageCount
        self.isbn = isbn
        self.createdAt = createdAt
    }

    /// An unrecognized raw value falls back rather than crashing — a store
    /// written by a later version must still open.
    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    var noteCount: Int { notes?.count ?? 0 }
}

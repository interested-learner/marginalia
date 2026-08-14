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
    var pageCount: Int = 0
    var currentPage: Int = 0
    var isbn: String?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]? = []

    init(
        title: String = "",
        author: String = "",
        status: BookStatus = .queued,
        pageCount: Int = 0,
        currentPage: Int = 0,
        isbn: String? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.author = author
        self.statusRaw = status.rawValue
        self.pageCount = pageCount
        self.currentPage = currentPage
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

    /// `0.4` — how far through the book the reader is, or nil when the page
    /// count is unknown. Manual entry leaves it unknown often enough that this
    /// can't be a plain `Double`.
    var progress: Double? {
        guard pageCount > 0 else { return nil }
        return min(1, max(0, Double(currentPage) / Double(pageCount)))
    }
}

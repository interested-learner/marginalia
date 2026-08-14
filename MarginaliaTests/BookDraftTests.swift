import Testing
@testable import Marginalia

/// What was typed into the book form → what a `Book` stores.
struct BookDraftTests {

    /// A title is the whole requirement. Everything else stays optional,
    /// because a failed lookup must never be a dead end.
    @Test func aTitleIsTheOnlyThingRequired() {
        #expect(BookDraft(title: "Meditations").canSave)
        #expect(!BookDraft(author: "Marcus Aurelius", pages: "254").canSave)
        #expect(!BookDraft(title: "   ").canSave)
    }

    @Test func titleAndAuthorAreTrimmed() {
        let draft = BookDraft(title: "  Meditations  ", author: "  Marcus Aurelius\n")
        #expect(draft.bookTitle == "Meditations")
        #expect(draft.bookAuthor == "Marcus Aurelius")
    }

    /// Unknown is 0, which is what `Book.progress` reads as "no progress bar".
    @Test func anUnknownPageCountIsZero() {
        #expect(BookDraft(title: "Meditations").pageCount == 0)
        #expect(BookDraft(title: "Meditations", pages: "not sure").pageCount == 0)
        #expect(BookDraft(title: "Meditations", pages: "254").pageCount == 254)
    }

    /// People type the label back into the field.
    @Test func theLabelTypedBackIntoTheFieldIsIgnored() {
        #expect(BookDraft(title: "x", pages: "499", current: "p. 214").currentPage == 214)
    }

    /// A book you're 340 pages into that claims 300 pages would draw a progress
    /// bar past its own brackets.
    @Test func theCurrentPageNeverPassesTheLastOne() {
        #expect(BookDraft(title: "x", pages: "300", current: "340").currentPage == 300)
    }

    /// With no page count there's nothing to clamp against, and the number is
    /// still worth keeping — the count can be filled in later.
    @Test func theCurrentPageSurvivesAnUnknownPageCount() {
        #expect(BookDraft(title: "x", current: "214").currentPage == 214)
    }

    // MARK: Round trips

    @Test func theFormOpensOnTheBookItIsEditing() {
        let book = Book(title: "Meditations", author: "Marcus Aurelius",
                        status: .reading, pageCount: 254, currentPage: 47)
        let draft = BookDraft(book)

        #expect(draft.title == "Meditations")
        #expect(draft.pages == "254")
        #expect(draft.current == "47")
        #expect(draft.status == .reading)
    }

    /// A book that has never been opened shows an empty field rather than `0` —
    /// a zero in a page field reads as a value someone entered.
    @Test func unknownCountsOpenAsEmptyFields() {
        let draft = BookDraft(Book(title: "Meditations"))
        #expect(draft.pages.isEmpty)
        #expect(draft.current.isEmpty)
    }

    @Test func aSearchResultFillsTheForm() {
        var draft = BookDraft()
        draft.fill(from: BookCandidate(id: "/works/OL1W", title: "Thinking, Fast and Slow",
                                       author: "Daniel Kahneman", pageCount: 499,
                                       isbn: "9780374533557"))

        #expect(draft.title == "Thinking, Fast and Slow")
        #expect(draft.author == "Daniel Kahneman")
        #expect(draft.pages == "499")
        #expect(draft.isbn == "9780374533557")
    }

    /// What Open Library doesn't know is left alone rather than blanked — the
    /// reader may have typed it already, and losing it would be the lookup
    /// making the form worse.
    @Test func aSparseResultDoesNotBlankWhatWasTyped() {
        var draft = BookDraft(title: "wrong", author: "Marcus Aurelius", pages: "254")
        draft.fill(from: BookCandidate(id: "/works/OL2W", title: "Meditations"))

        #expect(draft.title == "Meditations")
        #expect(draft.author == "Marcus Aurelius")
        #expect(draft.pages == "254")
    }
}

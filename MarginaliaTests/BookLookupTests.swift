import Foundation
import Testing
@testable import Marginalia

/// Open Library, parsed. The fixtures below are trimmed captures of real
/// responses — including the two that matter most, a search result with no
/// author and an edition with no page count. **Lookup failure is routine**, so
/// the interesting cases here are all the ones where a field is missing.
///
/// Nothing in this file touches the network.
struct BookLookupTests {

    // MARK: Search

    /// `/search.json?q=thinking+fast+and+slow`, trimmed to the fields asked for.
    private let search = Data("""
    {"numFound": 2, "docs": [
      {"key": "/works/OL16813953W",
       "title": "Thinking, Fast and Slow",
       "author_name": ["Daniel Kahneman"],
       "number_of_pages_median": 499,
       "isbn": ["0374275637", "9780374533557"]},
      {"key": "/works/OL15043682W",
       "title": "Meditations",
       "author_name": ["Marcus Aurelius", "Gregory Hays"],
       "number_of_pages_median": 254,
       "isbn": ["9780812968255"]}
    ]}
    """.utf8)

    @Test func aSearchResultCarriesTitleAuthorAndPageCount() {
        let found = BookLookup.candidates(fromSearch: search)

        #expect(found.count == 2)
        #expect(found[0].title == "Thinking, Fast and Slow")
        #expect(found[0].author == "Daniel Kahneman")
        #expect(found[0].pageCount == 499)
    }

    /// Several authors are listed; the row has space for one.
    @Test func theFirstAuthorIsTheOneShown() {
        #expect(BookLookup.candidates(fromSearch: search)[1].author == "Marcus Aurelius")
    }

    /// Thirteen digits are what a barcode reads and what the isbn endpoint
    /// takes, so it wins over the ten-digit form when both are offered.
    @Test func theThirteenDigitISBNIsPreferred() {
        #expect(BookLookup.candidates(fromSearch: search)[0].isbn == "9780374533557")
    }

    /// Open Library has plenty of records with no author and no page count.
    /// Both come back blank rather than failing the whole result.
    private let sparse = Data("""
    {"numFound": 1, "docs": [
      {"key": "/works/OL1W", "title": "An Unattributed Pamphlet"}
    ]}
    """.utf8)

    @Test func aResultWithNoAuthorOrPageCountStillParses() {
        let found = BookLookup.candidates(fromSearch: sparse)

        #expect(found.count == 1)
        #expect(found[0].title == "An Unattributed Pamphlet")
        #expect(found[0].author.isEmpty)
        #expect(found[0].pageCount == 0)
        #expect(found[0].isbn == nil)
    }

    /// Open Library holds a separate work record for every translation and
    /// reissue, so searching *Meditations* really does come back like this.
    /// A list you have to read twice to pick from is worse than a short one.
    private let duplicates = Data("""
    {"docs": [
      {"key": "/works/OL1W", "title": "Meditations", "author_name": ["Marcus Aurelius"],
       "number_of_pages_median": 158},
      {"key": "/works/OL2W", "title": "Meditations", "author_name": ["Marcus Aurelius"],
       "number_of_pages_median": 203},
      {"key": "/works/OL3W", "title": "meditations", "author_name": ["marcus aurelius"]},
      {"key": "/works/OL4W", "title": "The Meditations", "author_name": ["Marcus Aurelius"],
       "number_of_pages_median": 148}
    ]}
    """.utf8)

    @Test func repeatsOfTheSameBookCollapseToOne() {
        let found = BookLookup.candidates(fromSearch: duplicates)

        #expect(found.map(\.title) == ["Meditations", "The Meditations"])
        // The first survivor is the most relevant — the order is theirs.
        #expect(found[0].pageCount == 158)
    }

    /// Same title, different author, is a different book.
    @Test func aSharedTitleUnderAnotherAuthorSurvives() {
        let data = Data("""
        {"docs": [
          {"title": "Meditations", "author_name": ["Marcus Aurelius"]},
          {"title": "Meditations", "author_name": ["Rene Descartes"]}
        ]}
        """.utf8)
        #expect(BookLookup.candidates(fromSearch: data).map(\.author)
                == ["Marcus Aurelius", "Rene Descartes"])
    }

    /// A doc with no title is not a book anyone can pick.
    @Test func aResultWithNoTitleIsDropped() {
        let data = Data(#"{"docs": [{"key": "/works/OL2W"}, {"title": "  "}]}"#.utf8)
        #expect(BookLookup.candidates(fromSearch: data).isEmpty)
    }

    /// Open Library answering with something else entirely — a maintenance
    /// page, an error body — ends in an empty list, never a crash.
    @Test func nonsenseParsesToNothing() {
        #expect(BookLookup.candidates(fromSearch: Data("<html>down for maintenance".utf8)).isEmpty)
        #expect(BookLookup.candidates(fromSearch: Data()).isEmpty)
    }

    // MARK: Edition

    /// `/isbn/9780374533557.json`. The authors are **key references**, not
    /// names — which is why resolving one costs a second request.
    private let edition = Data("""
    {"title": "Thinking, Fast and Slow",
     "number_of_pages": 499,
     "isbn_13": ["9780374533557"],
     "isbn_10": ["0374533555"],
     "authors": [{"key": "/authors/OL23919A"}],
     "publishers": ["Farrar, Straus and Giroux"]}
    """.utf8)

    @Test func anEditionCarriesTitlePagesAndISBN() {
        let found = BookLookup.candidate(fromEdition: edition, isbn: "9780374533557")

        #expect(found?.title == "Thinking, Fast and Slow")
        #expect(found?.pageCount == 499)
        #expect(found?.isbn == "9780374533557")
    }

    /// The edition alone doesn't know the author's name, only where to find it.
    @Test func anEditionLeavesTheAuthorToASecondRequest() {
        #expect(BookLookup.candidate(fromEdition: edition, isbn: "9780374533557")?.author == "")
        #expect(BookLookup.authorKey(inEdition: edition) == "/authors/OL23919A")
        #expect(BookLookup.authorURL(for: "/authors/OL23919A")
                == URL(string: "https://openlibrary.org/authors/OL23919A.json"))
    }

    @Test func theAuthorDocumentIsJustAName() {
        let author = Data(#"{"name": "Daniel Kahneman", "personal_name": "Kahneman, Daniel"}"#.utf8)
        #expect(BookLookup.authorName(from: author) == "Daniel Kahneman")
        #expect(BookLookup.authorName(from: Data(#"{"key": "/authors/OL1A"}"#.utf8)) == nil)
    }

    /// When the edition carries its author as prose, that saves the request.
    @Test func aByStatementIsReadAsTheAuthor() {
        let data = Data("""
        {"title": "Meditations", "by_statement": "by Marcus Aurelius", "authors": [{"key": "/authors/OL9A"}]}
        """.utf8)
        #expect(BookLookup.candidate(fromEdition: data, isbn: "9780812968255")?.author
                == "Marcus Aurelius")
    }

    /// Manual entry exists precisely because records look like this.
    @Test func anEditionWithNoPageCountOrAuthorStillParses() {
        let data = Data(#"{"title": "A Slim Volume", "isbn_13": ["9780000000002"]}"#.utf8)
        let found = BookLookup.candidate(fromEdition: data, isbn: "9780000000002")

        #expect(found?.title == "A Slim Volume")
        #expect(found?.pageCount == 0)
        #expect(found?.author == "")
        #expect(BookLookup.authorKey(inEdition: data) == nil)
    }

    /// The isbn scanned is kept when the record doesn't repeat it — it's the
    /// one fact the barcode is certain about.
    @Test func theScannedISBNIsKeptWhenTheRecordOmitsIt() {
        let data = Data(#"{"title": "A Slim Volume"}"#.utf8)
        #expect(BookLookup.candidate(fromEdition: data, isbn: "978-0-00-000000-2")?.isbn
                == "9780000000002")
    }

    @Test func anEditionWithNoTitleIsNoBook() {
        #expect(BookLookup.candidate(fromEdition: Data("{}".utf8), isbn: "9780374533557") == nil)
    }

    // MARK: URLs

    @Test func theSearchURLEscapesWhatWasTyped() throws {
        let url = try #require(BookLookup.searchURL(for: "  thinking, fast & slow  "))
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(url.host() == "openlibrary.org")
        #expect(url.path() == "/search.json")
        #expect(query.first { $0.name == "q" }?.value == "thinking, fast & slow")
        #expect(url.absoluteString.contains("%26"))   // the ampersand, escaped
    }

    @Test func anEmptyQueryHasNoURL() {
        #expect(BookLookup.searchURL(for: "   ") == nil)
    }

    @Test func theEditionURLNormalizesTheISBNFirst() {
        #expect(BookLookup.editionURL(for: "978-0-374-53355-7")
                == URL(string: "https://openlibrary.org/isbn/9780374533557.json"))
        #expect(BookLookup.editionURL(for: "not an isbn") == nil)
    }

    /// A key that isn't an author key doesn't get followed.
    @Test func onlyAnAuthorKeyBecomesAnAuthorURL() {
        #expect(BookLookup.authorURL(for: "/works/OL1W") == nil)
        #expect(BookLookup.authorURL(for: "") == nil)
    }
}

/// What comes off a barcode, and what a reader types.
struct ISBNTests {

    @Test func hyphensAndSpacesComeOut() {
        #expect(ISBN.normalized("978-0-374-53355-7") == "9780374533557")
        #expect(ISBN.normalized(" 978 0 374 53355 7 ") == "9780374533557")
    }

    @Test func theTenDigitFormSurvivesItsTrailingX() {
        #expect(ISBN.normalized("080442957X") == "080442957X")
        #expect(ISBN.normalized("080442957x") == "080442957X")
    }

    /// Thirteen digits are only an isbn under Bookland. The EAN off a cereal
    /// box is a valid barcode and not a book, and saying so beats a lookup that
    /// fails for no visible reason.
    @Test func aThirteenDigitEANThatIsNotBooklandIsNotAnISBN() {
        #expect(ISBN.normalized("0123456789012") == nil)
        #expect(ISBN.normalized("5901234123457") == nil)
        #expect(ISBN.normalized("9791234567896") != nil)   // 979 is Bookland too
    }

    @Test func theWrongNumberOfDigitsIsNotAnISBN() {
        #expect(ISBN.normalized("12345") == nil)
        #expect(ISBN.normalized("") == nil)
        #expect(ISBN.normalized("Meditations") == nil)
    }
}

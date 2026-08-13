# marginalia — v1 design spec

**2026-08-13** · approved · supersedes `docs/prototype/Marginalia.dc.html` turn `2a` where they differ

The prototype established the look and the three-tab shape. This spec establishes what v1 actually does. Where the two disagree — the review tab, most notably — this document wins.

---

## Scope

**In:** three tabs (stream / books / review) · text, voice, and camera-OCR capture · book search and ISBN scan · zettel note links · threaded follow-ups · stars · full-text search · Markdown export · one daily notification · light and dark.

**Out of v1:** iCloud sync (designed for, not enabled) · Kindle and Apple Books import · widgets · Share extension · iPad · any account system · any paid tier.

**Done means:** builds clean, tests pass, runs on the simulator and on Nathaniel's iPhone. App Store submission is a later pass.

---

## Screens

### Stream

The home tab. Every note across every book, newest first, grouped under `today · wed aug 13` / `yesterday` / `earlier` headers. Tag chips filter the feed; `all` is the default chip.

Each row is a note: a 48pt id gutter, then type and relative time, the body (quote-blocked if it's a quote), and a source line of book · page · tags that opens the book when tapped. Note links (`→ n.09`) sit on the source line and jump to the linked note's book.

The **capture bar is pinned to the foot** and present the whole time — that persistence is the point. Type into it and `[+]` files a thought; `[●]` records one.

### Capture

Four types: `[q] quote`, `[t] thought`, `[v] voice`, `[s] scan`.

**From the stream bar** — the fast path. Text or voice only, no book, no page, no tag. The note lands in **Inbox** to be filed later. Two taps from launch to a saved thought.

**From a book** — `[+] add note` on book detail opens the full sheet: type selector, book picker (pre-filled), body, page, tags.

**Voice** follows the prototype's flow exactly: tap `[●]` → live waveform and elapsed timer → `■ stop` → `[↻] transcribing…` → the text lands in the field, **editable before saving**. Transcription is on-device (`requiresOnDeviceRecognition = true`), so it works on a plane and never leaves the phone.

**Scan** opens VisionKit's text scanner. Point at the page, tap the passage, correct it if OCR fumbled a word, save as a quote. Page number is typed, not inferred — inferring it would be wrong often enough to be worse than useless.

Permissions are requested at first use of each feature. Never at launch.

### Books

The library: status marker, title, author, note count. Filterable by reading / finished / queued. Inbox is a book like any other, so unfiled captures are never invisible.

**Book detail** is the header (title, author, note count · status · progress) over that book's notes, with `[+] add note`.

**Adding a book** — three ways, in order of how often they'll be used:

1. **Search** — type a title, hit Open Library `/search.json`, pick a result. Fills title, author, page count.
2. **Scan the barcode** — VisionKit in barcode mode reads the ISBN off the back cover, then `/isbn/{isbn}.json`.
3. **Manual** — always available. Lookup failing is routine, not exceptional, and must never be a dead end.

Cover art is fetched by neither. See `docs/decisions.md` §7.

### Review

**One note per screen, swiped vertically.** A daily set of up to 8, chosen once per calendar day.

Each card: metadata, the note at 17/1.7, the source, linked notes, then the action row — `✎ add a thought` · `★ star` · `→ open book` · share. Progress bar and `↑ swipe up for next` at the foot.

`✎ add a thought` attaches a **threaded follow-up** under the original note, typed or spoken. This replaces the prototype's `keep / skip / later` entirely. Follow-ups appear beneath their parent everywhere the note is shown.

The set ends on a closing card with `[↻] keep going`, which extends past the day's eight for anyone who wants more.

### Search

One field, full-text across note bodies, follow-ups, book titles, authors, and tags. Results are note rows grouped by book. `#tag` in the query filters by tag.

### Settings

Notification time and on/off · Markdown export · appearance (system / light / dark) · about.

---

## Review set algorithm

`Features/Review/ReviewSetBuilder.swift`. **Pure** — takes `[Note]` and a `Date`, returns `[Note]`. No SwiftData inside it; that's what makes it testable.

```
seed        = calendar day  → the same day always yields the same set
score(note) = daysSinceLastSurfaced   (never surfaced ranks highest)
            + starBonus if isStarred
            + jitter(seed, note.id)   (small, keeps it from feeling mechanical)

take highest-scoring, subject to:
  - at most 8 total
  - at most 2 per book
  - at least 1 from a book with status .reading, when one exists
```

`lastSurfacedAt` and `surfaceCount` are written **only when a card is actually paged past**, never when the set is built. Building a set must not change what future sets look like.

Under 8 notes total, the set is however many exist. Under 3, review shows an empty state pointing at capture instead.

---

## Data model

SwiftData. Every property defaulted, every relationship optional, no unique constraints — CloudKit's requirements, adopted now so sync is a configuration change later rather than a migration.

```swift
@Model final class Book {
  var title: String = ""
  var author: String = ""
  var statusRaw: String = "queued"        // reading | finished | queued | inbox
  var pageCount: Int = 0
  var currentPage: Int = 0
  var isbn: String?
  var createdAt: Date = Date.now
  @Relationship(deleteRule: .cascade, inverse: \Note.book) var notes: [Note]? = []
}

@Model final class Note {
  var shortID: Int = 0                    // rendered "n.11"
  var kindRaw: String = "thought"         // quote | thought | voice | scan
  var text: String = ""
  var page: Int?
  var tags: [String] = []
  var createdAt: Date = Date.now
  var lastSurfacedAt: Date?
  var surfaceCount: Int = 0
  var isStarred: Bool = false
  var book: Book?
  @Relationship var links: [Note]? = []
  @Relationship(deleteRule: .cascade, inverse: \FollowUp.note) var followUps: [FollowUp]? = []
}

@Model final class FollowUp {
  var text: String = ""
  var createdAt: Date = Date.now
  var note: Note?
}
```

`statusRaw` and `kindRaw` are stored as strings with typed computed accessors — SwiftData handles enums poorly across schema changes, and raw strings stay readable in the store.

**Inbox** is a real `Book` with `status == .inbox`, created on first launch. Quick captures go there.

**`shortID`** comes from a monotonic counter in `UserDefaults`. Ids are never reused after a delete, because a dangling `→ n.07` pointing at a different note would be worse than one pointing at nothing.

**Seed data** on first launch: the prototype's five books and eleven notes, so a fresh install has something to look at and the design can be judged against real content.

---

## Services

| Service | Framework | Notes |
|---|---|---|
| `SpeechTranscription` | `Speech` + `AVFoundation` | `SFSpeechRecognizer`, on-device only. `AVAudioEngine` tap drives the live waveform |
| `TextScanner` | `VisionKit` | `DataScannerViewController`, text mode, tap-to-select |
| `BarcodeScanner` | `VisionKit` | Same controller, `.barcode(symbologies: [.ean13])` |
| `BookLookup` | `URLSession` | Open Library. No key, no attribution required. Manual entry always available |
| `NotificationScheduler` | `UserNotifications` | One per day at the user's chosen time, 7 scheduled ahead, refreshed each launch |
| `MarkdownExport` | — | One section per book, `[[n.05]]` wiki-links, follow-ups as nested blockquotes. Delivered by `ShareLink` |
| Share card | `ImageRenderer` | A SwiftUI quote card rendered at 3× |

Notification bodies carry **the note's actual text**, so they're readable from the Lock Screen without opening the app — often that's the whole interaction. Tapping deep-links to that note in review.

`Info.plist` needs `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription`.

---

## Testing

Swift Testing (`@Test` / `#expect`), covering the logic that's worth isolating:

- `ReviewSetBuilder` — stability within a day, the 8 cap, the 2-per-book cap, starred weighting, currently-reading inclusion, and behavior with fewer than 8 notes
- `BookLookup` — Open Library response parsing against captured fixtures, including missing-author and missing-page-count responses
- `MarkdownExport` — output shape, link rendering, follow-up nesting
- `shortID` allocation — monotonic across deletes

Views aren't unit tested. They're verified by screenshot in both appearances against the archived prototype.

---

## Build order

Each phase ends in something runnable, so the look can be judged before more is built on it.

0. Documentation — `CLAUDE.md`, `README.md`, this spec, `docs/design-system.md`, `docs/decisions.md`
1. Scaffold, fonts, `Theme`, `Glyphs`, components, static three-tab shell → **screenshot both appearances against the prototype before continuing**
2. Models, seed data, Inbox, stream feed, tag chips, note links
3. Capture bar — text, then voice with waveform and on-device transcription
4. Books — list, detail, add by search and ISBN, full capture sheet
5. Review — paged cards, `ReviewSetBuilder`, stars, follow-ups, share card
6. Search, Markdown export, settings, daily notification
7. Camera OCR capture
8. App icon, empty states, haptics, Dynamic Type, install on device

---

## Risks

**The name.** "Marginalia" is a natural fit and likely contested on the App Store. Worth checking before the listing pass. Doesn't block anything now — the bundle id can change.

**On-device transcription quality** varies by device and language. If `SFSpeechRecognizer` disappoints in real use, the fallback is `SpeechAnalyzer`, which would raise the deployment target to iOS 26.

**OCR accuracy on printed pages** is good but not perfect, especially on tight leading or yellowed paper. Mitigated by making the transcription editable before saving — which it is for voice too, for the same reason.

**Notification fatigue.** One per day is deliberately conservative. If it gets muted, the app loses its only pull-back mechanism, and a muted app is worse than a quiet one.

# marginalia — v1 design spec

**2026-08-13** · approved · supersedes `docs/prototype/Marginalia.dc.html` turn `2a` where they differ

The prototype established the look and the three-tab shape. This spec establishes what v1 actually does. Where the two disagree — the review tab, most notably — this document wins.

---

> **Revised 2026-08-13**, same day, after review. Two additions changed the shape of the app: **links are now created automatically by the app rather than by the user**, and a **map** was added as a fourth tab. Four visual revisions to the prototype were also confirmed. See `docs/decisions.md` §10–12.

## Scope

**In:** four tabs (stream / books / map / review) · text, voice, and camera-OCR capture · book search and ISBN scan · **automatic semantic linking** · threaded follow-ups · stars · full-text search · Markdown export · one daily notification · light and dark.

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

### Map

A fourth tab, two views over one renderer.

**Global** — the whole library as one shape. Notes are nodes; **each book is a hub node its notes attach to**, which is what makes the view meaningful on day one instead of a scatter of lonely dots. Above ~150 nodes it collapses to book hubs and expands one on tap.

**Local** — reachable from any note. Two hops out, capped around 25 nodes. Legible at any library size, and it answers the question you actually have while reading a note.

Selecting a node previews its note in a panel at the foot; tap through to open it. Holding an edge deletes that connection, permanently — the pair goes on a suppression list so it isn't re-suggested.

Visual language is in `docs/design-system.md` under *Map*. In short: nodes are the note id in mono type, books are bracketed and bolder, edges are hairlines, and selection inverts to filled ink. No color, no circles, no shadows.

`GraphLayout` is force-directed (spring-electrical, ~300 iterations), **pure**, and runs on a background actor. Positions are cached and recomputed only when the graph changes. Plain O(N²) repulsion is fine under ~2,000 nodes; above that, bucket it on a grid.

### Search

One field, full-text across note bodies, follow-ups, book titles, authors, and tags. Results are note rows grouped by book. `#tag` in the query filters by tag.

### Settings

Notification time and on/off · Markdown export · appearance (system / light / dark) · about.

---

## Automatic linking

**The user never links anything.** Notes connect themselves as they're written; there is no prompt, no accept/dismiss flow, no syntax to learn.

### Embedding

`NoteEmbedding` vectorizes each note with **`NLContextualEmbedding`** (iOS 17+), which captures meaning rather than vocabulary — a passage on impermanence can connect to a note on anchoring without sharing a word. Entirely on-device: no network, no key, nothing sent anywhere.

It requires a one-time asset download (`requestEmbeddingAssets`). Until that completes, fall back to `NLEmbedding.sentenceEmbedding(for: .english)` — lower quality, no setup, present since iOS 14. **The app must work on first launch either way.**

Vectors are mean-pooled to a single sentence vector and stored on `Note` as `Data` (packed `Float32`), which keeps the model CloudKit-safe.

### Scoring

```
score = 0.8 · cosine(a, b) + 0.2 · tagOverlap(a, b)
```

Same-book is deliberately **not** boosted — books are already hub nodes in the map, so rewarding it again would clump each book into a ball.

Three constraints keep the graph readable rather than a hairball:

| | |
|---|---|
| **Floor** | an edge needs `score ≥ 0.55` |
| **Mutual k-NN** | each note must be in the other's top 8 — this is what stops one broadly-worded note attaching to everything |
| **Degree cap** | at most 6 edges per note, strongest kept |

Recomputation is incremental on save: embed the new note, compare against every stored vector. At 5,000 notes that's a few million float operations — microseconds. A full rebuild is O(N²) but still seconds on a background actor, offered in settings as *rebuild connections*.

`AffinityEngine` takes vectors and tags and returns edges. **No SwiftData inside it.**

### One kind of link

Automatic and manual links **render identically**. No dotted lines, no "suggested" badge, nothing to interpret. The state exists only so override works:

- `isPinned` — user-created; never pruned by a recompute
- `isSuppressed` — user-deleted; never re-suggested

Neither is ever surfaced in the UI.

Manual creation lives on the keyboard accessory bar while composing (`→ link · # tag · p. page`) and on the review card, opening a search sheet over notes.

**Backlinks always show.** Edges store direction but display both ways, or half of every note's connections are invisible.

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
  var embedding: Data?                    // packed Float32
  var embeddedAt: Date?                   // nil ⇒ needs (re)embedding
  var book: Book?
  @Relationship(deleteRule: .cascade, inverse: \FollowUp.note) var followUps: [FollowUp]? = []
}

@Model final class FollowUp {
  var text: String = ""
  var createdAt: Date = Date.now
  var note: Note?
}

@Model final class NoteEdge {
  var from: Note?
  var to: Note?
  var score: Double = 0                   // 0 for manual
  var isPinned: Bool = false              // user-created; never pruned
  var isSuppressed: Bool = false          // user-deleted; never re-suggested
  var createdAt: Date = Date.now
}
```

Connections are their own model rather than a bare `[Note]` relationship, because they now carry score and override state.

`statusRaw` and `kindRaw` are stored as strings with typed computed accessors — SwiftData handles enums poorly across schema changes, and raw strings stay readable in the store.

**Inbox** is a real `Book` with `status == .inbox`, created on first launch. Quick captures go there.

**`shortID`** comes from a monotonic counter in `UserDefaults`. Ids are never reused after a delete, because a dangling `→ n.07` pointing at a different note would be worse than one pointing at nothing.

**Seed data** on first launch: the prototype's five books and eleven notes, so a fresh install has something to look at and the design can be judged against real content.

---

## Services

| Service | Framework | Notes |
|---|---|---|
| `NoteEmbedding` | `NaturalLanguage` | `NLContextualEmbedding` with an `NLEmbedding` fallback. On-device |
| `AffinityEngine` | — | Pure. Vectors + tags → edges |
| `GraphLayout` | — | Pure. Nodes + edges → positions. Background actor |
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

- `AffinityEngine` — the floor; mutual k-NN rejecting a hub note that's mildly similar to everything; the degree cap; pinned edges surviving a recompute; suppressed pairs never returning
- `GraphLayout` — deterministic given a seed, no overlapping nodes, convergence inside the iteration budget
- `ReviewSetBuilder` — stability within a day, the 8 cap, the 2-per-book cap, starred weighting, currently-reading inclusion, and behavior with fewer than 8 notes
- `BookLookup` — Open Library response parsing against captured fixtures, including missing-author and missing-page-count responses
- `MarkdownExport` — output shape, link rendering, follow-up nesting
- `shortID` allocation — monotonic across deletes

Views aren't unit tested. They're verified by screenshot in both appearances against the archived prototype.

**Tests cannot tell you whether the links are any good.** They prove `AffinityEngine` respects its constraints; whether the connections are *defensible* needs a human. Phase 6 ends by dumping each seed note's top 5 connections and reading them — if they don't hold up, the weights or the floor get tuned before the map is built on top.

Seed data expands to **~40 notes**. A twelve-note map proves nothing about whether the layout works.

---

## Build order

Each phase ends in something runnable, so the look can be judged before more is built on it.

0. Documentation — `CLAUDE.md`, `README.md`, this spec, `docs/design-system.md`, `docs/decisions.md`
1. Scaffold, fonts, `Theme`, `Glyphs`, components, static four-tab shell → **screenshot both appearances against the prototype before continuing**
2. Models, seed data, Inbox, stream feed with the margin rule, tag chips
3. Capture bar — text, then voice with waveform and on-device transcription
4. Books — list, detail, add by search and ISBN, full capture sheet
5. Review — paged cards, `ReviewSetBuilder`, stars, follow-ups, share card
6. Linking — `NoteEmbedding`, `AffinityEngine`, embed-on-save, backfill, backlinks in the UI → **read real output before continuing**
7. Map — `GraphLayout`, `Canvas` renderer, local view, global view, hub collapse, edge deletion
8. Search, Markdown export, settings, daily notification
9. Camera OCR capture
10. App icon, empty states, haptics, Dynamic Type, install on device

---

## Risks

**Nobody types a link, so nobody learns the habit.** If automatic linking underdelivers there's no fallback behavior to lean on — which is exactly why phase 6 gates on reading real output before phase 7 builds the map on top of it.

**`NLContextualEmbedding` assets may be unavailable on a fresh device.** The `NLEmbedding` fallback covers it at lower quality. Worth checking what a genuinely first-launch device does.

**Embeddings are English-first.** Notes in other languages will link poorly. Acceptable for v1, but state it plainly if it ever reaches a listing.

**Four tabs pushes against "simple."** Still the iOS norm, but the map has to earn its place. If it doesn't, it moves back inside Books as a view toggle.

**The name.** "Marginalia" is a natural fit and likely contested on the App Store. Worth checking before the listing pass. Doesn't block anything now — the bundle id can change.

**On-device transcription quality** varies by device and language. If `SFSpeechRecognizer` disappoints in real use, the fallback is `SpeechAnalyzer`, which would raise the deployment target to iOS 26.

**OCR accuracy on printed pages** is good but not perfect, especially on tight leading or yellowed paper. Mitigated by making the transcription editable before saving — which it is for voice too, for the same reason.

**Notification fatigue.** One per day is deliberately conservative. If it gets muted, the app loses its only pull-back mechanism, and a muted app is worse than a quiet one.

# Decisions

What was chosen, and why. The reasoning matters more than the choice — when a decision is revisited it should be because a premise changed, not because the reasoning was forgotten.

Newest last.

---

## 1. Native SwiftUI, not React Native

**2026-08-13 · settled**

Everything that separates a good book-notes app from a mediocre one is a platform capability: on-device speech transcription, camera OCR against a printed page, barcode scanning, Lock Screen widgets, a Share extension, free iCloud sync. All are first-party on iOS and all are third-party wrappers in React Native, where widgets and extensions in particular get genuinely painful.

The usual argument for React Native — cross-platform layout and reusing web skills — buys us little here, because the design is entirely custom. It borrows nothing from native iOS chrome and nothing from web idiom. Building it in SwiftUI costs no more than building it in RN.

**Cost accepted:** Nathaniel works in web, so this is Swift rather than TypeScript.

## 2. Deployment target iOS 18.0

**2026-08-13 · settled**

Every API the app needs is available at 18.0: SwiftData, `SFSpeechRecognizer` with on-device recognition, VisionKit's `DataScannerViewController` for both text and barcodes, Observation. Targeting 18 keeps App Store reach broad for a new app with no installed base to protect.

The alternative was iOS 26 to reach `SpeechAnalyzer`, Apple's newer transcription API. Not worth the reach it costs unless the older recognizer proves inadequate in practice — see the note in `CLAUDE.md`.

## 3. Local-first SwiftData, CloudKit deferred

**2026-08-13 · settled**

Sync requires a paid Apple Developer account, which isn't confirmed yet, and a cloud backend with accounts is real infrastructure that proves nothing about whether the app is good. Local SwiftData gets a working app on the phone now.

**The cost of deferring is paid up front instead:** every `@Model` is written to CloudKit's constraints from day one — defaults on every property, optional relationships, no `@Attribute(.unique)`. Enabling sync later is then a container-configuration change rather than a schema migration.

## 4. Review is a scroll, not a drill

**2026-08-13 · settled** · supersedes the prototype's review tab

The prototype offered `keep / skip / later` beneath each note, with kept notes resurfacing in seven days. Nathaniel's objection, and it's the right one: it's confusing. It asks you to make a scheduling decision about a note you just read, in vocabulary borrowed from flashcard software, about a thing that isn't a flashcard. You're not trying to memorize your own notes.

What review is actually for is **running into your own thinking again**. So:

- **One note per screen, swipe up for the next.** Each note gets a beat of attention rather than scrolling past in a list.
- **A daily set of ~8**, fixed per calendar day so leaving and returning doesn't reshuffle it. The boundary matters twice over: it makes review a ritual with an end rather than another infinite feed, and it's what distinguishes Review from Stream, which is newest-first and unbounded. An endless shuffle would have competed with Stream for the same instinct.
- **The judgment buttons are replaced by `✎ add a thought`** — a threaded follow-up under the original. Instead of judging a note you grow it, and over time the good notes accumulate a conversation with yourself. That's what a zettelkasten is supposed to do, and unlike keep/skip/later it needs no explanation.
- **`★ star` is the honest version of "keep"** — one tap, unambiguous meaning, no scheduling vocabulary. Starred notes score higher in future sets.

Scoring lives in `ReviewSetBuilder`, which is pure and tested: favor notes not surfaced recently, weight starred ones up, cap at 2 per book, always include something from a book currently being read.

## 5. Book search and ISBN scan are v1, not later

**2026-08-13 · settled**

The prototype never showed how a book gets added, which hid the app's worst friction point. Typing a title, an author, and a page count by hand — before you can record a single note — is exactly where a reading app loses someone on day one.

Open Library's API is free, needs no key, and imposes no attribution requirement. Barcode scanning reuses the same VisionKit scanner as OCR capture, so it's nearly free once that exists. Manual entry stays available as a fallback, and lookup failure is treated as routine rather than exceptional.

## 6. Camera OCR capture

**2026-08-13 · settled**

Point the camera at a printed page, tap the passage, it becomes a quote. This is the marquee feature for people reading physical books, and it's the clearest separation from Readwise, which is built around Kindle highlights and treats paper as an afterthought.

Adds a fourth capture type, `[s] scan`, alongside quote, thought, and voice.

## 7. No cover art

**2026-08-13 · settled**

Books are title, author, status marker, and note count. No thumbnails, no cover grid — the prototype contains no imagery at all, and that restraint *is* the identity. A row of colorful cover thumbnails would read as a different app entirely, and it would be the one visual element the design deliberately excludes.

Considered and rejected: small covers in the books list only. It makes the library more scannable, which is a real benefit, but it's the thin end of the wedge on the app's only distinguishing visual commitment.

## 8. JetBrains Mono

**2026-08-13 · settled**

The design system specifies Berkeley Mono, which is a paid commercial face. JetBrains Mono is the substitute the system itself names as its fallback, which means the prototype has effectively been rendering in it all along. It's SIL OFL, so it redistributes inside an App Store binary with no legal work.

Font selection is isolated to `Design/Typography.swift` — swapping to Berkeley Mono later, if it's licensed, is two lines.

## 9. Light and dark, at the prototype's exact values

**2026-08-13 · settled**

Both appearances ship. Reading apps get used in bed, App Store reviews punish light-only apps, and retrofitting dark mode means auditing every hardcoded color in the project.

The palette is the prototype's `#fdfcfc` / `#201d1d`, inverted for dark — not pure `#ffffff` / `#000000`. The difference is about 1% and invisible side by side, but the faint warmth is what keeps long reading sessions from feeling harsh, and it's why the hairlines and `surfaceSoft` blocks sit so comfortably against the page. Pure black in dark mode also smears on OLED while scrolling.

**This decision is enforced by a rule, not by discipline:** no view may contain a color literal. Everything resolves through `Theme`, which defines both appearances on adjacent lines.

## 10. Links are made by the app, not by the user

**2026-08-13 · settled** · answers the biggest hole in the original spec

The prototype *displayed* links (`n.01 → n.07`) but never showed anyone creating one. That omission hid the hardest problem in the app: linking is where every zettelkasten tool either succeeds or quietly becomes a chore nobody keeps up with.

Nathaniel's answer was to remove the chore entirely — the web should build itself, with manual control available but never required.

**Engine.** `NLContextualEmbedding` (iOS 17+) turns each note into a vector capturing meaning rather than vocabulary, so a passage on impermanence can connect to a note on anchoring without sharing a word. On-device, no network, no key, no per-user cost — which also preserves the privacy story. Falls back to `NLEmbedding.sentenceEmbedding` when Apple's assets haven't downloaded; the app has to work on first launch either way.

Considered and rejected: **naive keyword overlap** (cheap and explainable, but "shares distinctive words" misses conceptual links, which are the only interesting ones); **Foundation Models**, Apple's on-device LLM, which could reason about *why* two notes connect and write that reason onto the edge — genuinely better, but it's iOS 26-only and would reverse decision §2 and the App Store reach that came with it. Worth revisiting when iOS 26 adoption is high.

**Constraints.** Scoring is `0.8 · cosine + 0.2 · tagOverlap`. Same-book is deliberately not boosted — books are already hub nodes in the map, so rewarding it twice would clump each book into a ball. Three rules keep the graph from becoming a hairball: a floor of `0.55`, mutual k-NN (each note in the other's top 8), and a degree cap of 6. Mutual k-NN is the important one — it's what stops a broadly-worded note from attaching itself to everything.

**One kind of link.** Automatic and manual links render identically. The alternative — dotted for the app's, solid for yours — would preserve the ability to ask "which of these did I actually notice?", which is arguably what a zettelkasten is for. It was rejected as a distinction the user shouldn't have to interpret. `isPinned` and `isSuppressed` are stored so override works (manual links survive recomputes, deleted pairs never return), but they are never surfaced.

**Known risk:** because nobody types a link, nobody learns the habit. If automatic linking underdelivers there's no fallback behavior to lean on — which is why phase 6 gates on a human reading real output before the map gets built on top of it.

## 11. A map, as a fourth tab

**2026-08-13 · superseded by §21** — the tab is gone; the escape clause at the foot of this section is what §21 invoked

An Obsidian-style graph of the library. Both a **global** view — everything as one shape — and a **local** one reachable from any note, two hops out. Both exist because a global graph is only legible in a narrow band: sparse and sad at twelve notes, an unreadable hairball at five thousand. A local graph reads clearly at any size and answers the question you actually have while reading a note.

**Books are hub nodes, not just notes.** This solves cold start: a new library with twelve notes and three links would otherwise be lonely dots, but book hubs produce real clusters on day one, and those clusters mean something — they're what you read. Tags as nodes were rejected: a tag on twenty notes becomes a giant hub that dominates the layout and drowns out the links the app actually drew.

**Drawing a graph in a system with no color is the interesting constraint.** Nodes are the note id itself in mono type (`n.07`), not a dot with a label beside it. Books are bracketed and bolder. Edges are hairlines at the same 12% as every divider in the app. Selection inverts the node to filled ink and brings its edges to full opacity while everything else stays hairline — that's the entire interaction vocabulary. Connection count shows as font weight rather than node size.

**Fourth tab**, over a toggle inside Books. If the self-building web is a defining feature it has to be one tap away; buried a level down it becomes a novelty visited twice. Four tabs is still the iOS norm. It does push against "simple" — if the map doesn't earn its place in use, it moves back inside Books.

Above ~150 nodes the global view collapses to book hubs and expands one on tap. That's the answer to the hairball, and it needs to exist before the map ships, not after.

## 12. Four visual revisions to the prototype

**2026-08-13 · settled** · overrides the prototype

Made after the intent behind the design was clearer, not as second-guessing.

**One header per screen.** Books and review stacked a wordmark row above a title row — roughly 50pt on every screen restating what the tab bar already said. The wordmark now appears on stream only. Recovers about two more rows of content everywhere else, and most on review, where a single note is meant to fill the frame.

**The id column becomes a real margin.** A hairline runs down its trailing edge so it reads as an actual margin with the id annotating the text beside it. The app is *named* after marks made in a margin and nothing in the design evoked one; this ties the name to the page and turns 48pt of unexplained space into the most distinctive thing about the layout. Rejected alternative: reclaiming the space entirely for text — more efficient, three more characters per line, but it makes the layout an ordinary feed.

**Quotes get a rule, not a fill.** A 2pt ink rule on the leading edge replaces the gray block. The filled block was the one element borrowed from messaging UI rather than print; a rule beside quoted matter is the printer's convention and what you'd actually draw next to a passage. It also drops a surface color from the system and reads better in dark, where a fill competes with the page. Quote text moves to `ink` and thought bodies stay `textBody`, so the two stay distinct without the block.

**Type up one step.** Body 14→15, metadata 12.5→13, review 17→18, buttons 14→15. The prototype's sizes came from a browser mockup about 410px wide; on a phone they're tight for an app you read in, and 12.5pt metadata is genuinely hard for anyone over about forty — a real consideration for this audience. Dynamic Type support throughout, which App Store review increasingly expects.

## 13. No dingbats either

**2026-08-13 · settled** · clarifies §the glyph rule, after violating it

The first pass at the review card used `★` for star and `✎` for add-a-thought. Both are dingbats, and a dingbat is a picture — which makes them icons, which this system doesn't have. The rule was "ASCII markers, not SF Symbols," and the letter of it was satisfied while the spirit wasn't.

Every marker is **bracket-plus-character**: `[ ] star`, `[*] starred`, `[+] add a thought`. Box-drawing and block characters stay allowed — `▁▂▃▄▅▆▇`, `█░`, `■`, `→` — because they're terminal furniture rather than pictures, and the prototype already used them.

Recorded because it's an easy rule to satisfy superficially, and the failure looks fine in isolation. It only reads wrong beside the rest of the vocabulary.

## 14. A vector belongs to the model that made it — and the recompute is whole

**2026-08-14 · settled** · extends §10, after building it

Three choices phase 6 had to make that §10 didn't cover, recorded because each one is invisible until it's wrong.

**The source is stored with the vector.** `NLContextualEmbedding` and `NLEmbedding.sentenceEmbedding` produce two different spaces, and a cosine between them is a number with no meaning — not a weaker signal, a meaningless one. So `Note.embeddingSourceRaw` records which model produced each vector, and a note whose source isn't the one loaded today counts as unembedded. The alternative — trusting `embeddedAt` alone — works perfectly until the day Apple's assets finish downloading, at which point half the library is in one space and half in another and every score is quietly garbage. That's a bug that would have looked like "the linking got worse for no reason."

**The recompute is full, not incremental.** The spec said to embed the new note and compare it against every stored vector, which is right about the new note and blind about everyone else: mutual k-NN and the degree cap are properties of the *whole* graph, so an arrival can displace somebody's eighth-best neighbour or take their sixth slot, and a delta never notices. A whole pass is O(N²) and, at any library this app currently holds, free. It stops being free somewhere in the low thousands of notes, and that's written down in `docs/issues.md` §15 rather than pretended away — the fix is the incremental path plus a background `ModelActor`, and it belongs with *rebuild connections* in phase 8.

**Pinned edges spend degree budget; suppression beats pinning.** A pinned edge is never pruned, but the cap exists to control how many lines meet at a node on the map, and a hand-made line is still a line — so pinned pairs are counted before the automatic ones are allocated. Where a pair is somehow both pinned and suppressed, suppression wins: deleting is the more recent deliberate act, and the cost of being wrong is a missing line rather than one the reader has already said they don't want.

**The thing §10 warned about happened, in a form nobody predicted.** §10 said phase 6 gates on a human reading real output. It does, and the output couldn't be read: `NLContextualEmbedding` cannot compile its assets in the simulator (`docs/issues.md` §14), so every connection anyone has looked at came from the fallback — which measurably does not measure meaning at note length. The floor, the weights and `k` were therefore left exactly where the spec put them. Tuning them against a model the app abandons the moment the assets compile would be fitting the numbers to the wrong thing, twice.

## 15. A deleted connection is kept, and the map is drawn where it will be read

**2026-08-14 · settled** · extends §11, after building it

Three choices phase 7 had to make that §11 didn't cover.

**Deleting a connection doesn't delete the edge.** `Eraser.suppress` sets `isSuppressed` and leaves the row where it is. The obvious implementation — remove it, like everything else `Eraser` touches — works until the next recompute, which is *every* recompute, because `LinkWriter` does a full pass rather than a delta (§14). That pass scores the same pair, finds it just as strong as it was a minute ago, and draws the line straight back. **The stored edge is the memory of the rejection**, and it's the only place that memory can live. It is the one delete in the app that leaves its subject in the store, which is exactly why it's written down here.

**A note's line to its book is drawn, and it is not a connection.** Books are hub nodes because a young library would otherwise be lonely dots (§11) — but a hub that gathers nothing visible gathers nothing. So the attachment is drawn, at the same hairline as everything else, because there is one line weight in this system. It is still not something the app *found*: it can't be held down on and deleted, and it doesn't count toward either end's weight. Counting it would make every note in a well-stocked book read as better connected than it is, which is precisely the false signal the same-book rule in §10 exists to avoid.

**The layout is told the shape of the box and the size of every label.** Both were rejected as over-engineering at the start and both were forced by a screenshot within the hour. A graph laid out in a square and drawn into a box twice as tall has every horizontal gap halved on the way to the screen; a `[Meditations]` spaced as though it were a point sits straight through the note beside it. The alternative — leave the layout abstract and nudge labels afterwards — moves nodes away from where the forces put them, which is the one thing a force-directed layout is for. Rejected. The layout is geometry, and a label's width is geometry.

## 16. A scan is a quote in everything but its marker

**2026-08-14 · settled** · extends §6, after building it

Three choices phase 9 had to make that §6 didn't cover.

**A scanned note is drawn with the quote rule, and its metadata still says `[s] scan`.** §6 says a scan "becomes a quote", which reads two ways: the same *kind* as a typed quote, or the same *appearance*. It's the appearance. `NoteKind.isPassage` covers `.quote` and `.scan` and is what the rule keys on; the marker stays `[s]`. Collapsing scan into quote at save time would be simpler and it would throw away how the note arrived, which the app has treated as a fact about a note since voice landed in phase 3 — an edited transcript is still `[v] voice`. Rejected for the same reason.

**The passage is built by tapping lines, and the page number is never one of them.** VisionKit recognizes a page a line at a time, so a passage is several taps and `ScannedPassage` joins them — including rejoining a word the typesetter broke at the margin, which is the one correction a reader would otherwise make on every scan. What it will not do is look for a folio and fill the page field in. §6's own words are that inferring it "would be wrong often enough to be worse than useless", and the file that could break that rule is the file that says so.

**No camera, no dead end.** Where `DataScannerViewController` isn't available the screen says `[x] no camera here — type the passage in as a quote instead` and drops the `use it` button entirely, since nothing on that machine could enable it. It's the same rule the barcode follows — a lookup failing is routine, not exceptional — and it's why manual entry is never buried behind a failure anywhere in this app.

## 17. Reading progress comes out; the page on a note stays

**2026-08-18 · settled** · supersedes the spec's `Book.currentPage` and the progress bar on book detail

`Book.currentPage` existed from phase 2 and moved exactly once in the app's life: `docs/planning.md` §phase 4 records that *editing a book was added on top of the phase's brief, because without it `currentPage` and `status` were unreachable and the progress bar could never move.* That is the whole case against it. The only way to say where you were in a book was to open the book, tap `edit`, find the `on p.` field, type a number and save — four taps to maintain a decoration, every reading session, forever. Nobody does that, and a progress bar that is always wrong is worse than no progress bar: it makes a confident claim about something the app does not know.

Three options were weighed and one was picked:

- **Derive it from the notes.** Saving a note at `p.214` would advance the book to 214. Tempting, and it costs the reader nothing — but it is quietly false. Where you took a note is not where you stopped reading, and the gap is largest for exactly the readers this app is for: somebody who annotates heavily early and then reads a hundred pages without writing anything would be shown as stalled. It would also be the app's first inference about the reader's behaviour, in a design whose one strong rule about page numbers is that **the page number is typed, never inferred** (§6, and `ScannedPassage`).
- **Keep it manual, make it faster.** A tappable progress line, one tap instead of four. Cheaper to build and it does not lie — but it leaves a feature whose upkeep is a chore in an app that has no other chores. Nothing else in marginalia asks the reader to maintain a number.
- **Take it out.** Chosen.

**What goes:** `Book.currentPage`, `Book.progress`, the `on p.` field on the book form, and the `[████░░░░░░] p.214 / 499` line on book detail.

**What stays, and why:** `Book.pageCount`. Open Library fills it, the form takes it, and it is a fact about the book rather than a claim about the reader — so it costs nothing to be right about. It moves into book detail's byline as `Daniel Kahneman · reading · 499pp`, because a stored value that nothing displays is the kind of thing that rots. `ASCIIProgressBar` stays too: review uses it for position in the day's set, which is a number the app actually knows.

**And `Note.page` is untouched.** Per-note pages are the useful half — they are typed at the moment they are true, by somebody looking at the page, and they are what makes a quote citable. That was never the part that didn't work.

The status marker is what carries "where am I with this book" now, which is what it was already doing: `reading`, `queued`, `finished`. One honest fact instead of two, one of which was a fiction.

## 18. The capture bar doesn't name a book; `→ full note` does

**2026-08-18 · settled** · reverses the picker added earlier the same day, and supersedes the spec's "a book can be named on the way past"

Phase 11's stage 2 put a `BookPickerField` in the stream's capture bar, visible once the field had focus. It shipped and was used, and the second hands-on pass came back with three complaints that are all the same complaint:

- **The picker was too small to use.** Rows were 13pt type in 12pt of padding — about 40pt, under the 44pt minimum — in a 240pt box wedged between the field and the keyboard. At eight seed books it was tight. At a real library it was a lottery.
- **Its closed state answered a question nobody had been asked.** `book · Inbox` reads as a book the reader chose. They chose nothing; the Inbox is where a note goes when nobody says otherwise.
- **The bar is where notes actually get written, and it was the weaker of the app's two capture surfaces.** Everything worth saying about a note — a page, a tag, a quote rather than a thought — lived behind a book on the other side of the app.

The third point argued for the bar becoming `CaptureSheet`. That was rejected: the bar's persistence *is* the stream, and the spec's oldest rule about it is that the fast path is not allowed to get slower. A sheet costs a tap, an animation, and the always-there line that makes the screen feel like a notebook rather than a form.

**What was built instead is an escalation.** Focused, the bar grows one thing: `→ full note`, a link under the field. It hands the typed text and how it was captured to `CaptureSheet`, which opens with the words already in it and the whole screen to spend. Two taps for a thought; three for a note with a book, a page and tags on it. The bar goes back to one line and two buttons.

Escalating is never destructive. The bar keeps its draft until `CaptureSheet` reports that a note was written, so cancelling the sheet puts the reader back in front of what they wrote. That is why `CaptureSheet` gained an `onSaved` callback rather than the bar clearing itself on the way out.

**And the Inbox stopped being one of the choices.** A note reached it two indistinguishable ways — `book == nil`, and picking the Inbox's own row — which is the same duplication `NoteWriter` and `Eraser` exist to prevent one level down. `BookPickerField` now filters the Inbox out of its list, offers `— no book —` at the top, and says `book · none` when nothing is named. Where the note lands is unchanged: `NoteWriter.save` still falls back to the Inbox, and the Inbox is still a `Book` on the books screen, which is what keeps unfiled captures visible.

**Not built, and worth watching for:** if naming a book from the stream turns out to be the common case rather than the rare one, the answer is a row of recently-used books in the bar — one tap, no list — and not the picker back. That is a thing to see happen before building.

---

## 19. The map lets the book lines be subtracted, and stays at one line weight

**2026-08-18 · superseded by §21** · answered a question §15 didn't ask; overturned nothing in §11 or §15. The screen it describes is deleted

A reader looking at the map asked whether it was "just linking the book to the notes connected to it," and said they had thought the point was to connect ideas *across* books. Both halves of that are worth taking seriously, because the first is wrong and the second is exactly what the app does.

`MapGraph` has emitted two kinds of line since phase 7. A **connection** is note-to-note, scored on meaning by `AffinityEngine`, and same-book is deliberately not boosted (§10) so that a line between two books means something. An **attachment** is a note to the book it was written from. On the seed library that is **46 connections against 40 attachments** — the cross-book idea graph was the larger half of what was on screen the whole time.

**So the failure was one of drawing, not of linking.** §15 says the attachment is drawn at the same hairline as everything else "because there is one line weight in this system," and that rule is right and stays. But it left the reader no way to tell the two apart, and force-directed layout pulls each note toward its hub — so forty structural lines and forty-six meaning lines resolved into one impression: a star per book.

**The fix is subtraction, not decoration.** A chip row under the header — `all lines` / `connections only` — stops the attachments being drawn. Considered and rejected: **dashing the attachments**, and **lightening them to a second tint**. Both would have been the app's first dashed line and its first second line weight, and §10 already rejected dotted-vs-solid for manual-vs-automatic links on the grounds that a *drawn* distinction is one the reader has to sit and interpret. A filter asks nothing of anyone. When it is off the screen is byte-for-byte what it was.

**It filters at the stroke and not in the graph**, which is not an implementation detail. `GraphLayout` goes on being told about every edge, so no node moves when the filter changes — confirmed by comparing the dark-pixel distribution of both states across 1300 rows of canvas: zero rows differ. Filtering in `web` instead would re-key the layout task and reshuffle the screen on a tap, which is the exact loop phase 11 removed (§15, `docs/issues.md` §5), and it would also stop the hubs gathering their clusters, because the attachment is the force doing the gathering.

**What this does not fix.** The connections themselves are still the fallback embedder's, and about half of them are indefensible. Being able to see the idea graph clearly is not the same as the idea graph being good — that waits on a device run and `docs/issues.md` §6. This change makes the *next* judgement possible, and it should not be mistaken for the judgement.

## 20. The map becomes a summary; the graph is demoted to bounded views

**2026-08-18 · superseded by §21, one day later** · invoked §11's own escape clause; amended §15 and §19 by reference. Its diagnosis of the *drawing* was right and is worth reading; its diagnosis of why nobody opened the tab was not

§19 made the idea graph legible and said plainly that legible is not the same as good. Read once more with a finger on it, the tab still had no takeaway — and the reason turned out to sit underneath every drawing question either §15 or §19 asked.

**Every node on the map is an opaque handle.** `n.07` says nothing. So a screen showing forty-six nodes is showing forty-six things nobody can read, and every fact the shape might carry has to be decoded one tap at a time. §11 chose that deliberately — "nodes are the note id itself in mono type, not a dot with a label beside it" — and it is the most distinctive drawing in the app. It is also why the tab is inert. **The stream shows you notes; the map showed you ids.**

Four things followed from it, and none of them is fixable by drawing better:

- **No region is named.** Force-directed layout answers *who is near whom*. Nothing on the screen said what a cluster **was**, so the reader was asked to infer a theme from the spatial position of numbers.
- **The collapsed hub view is a picture of the bookshelf**, which the books tab already gives with full titles, statuses and counts.
- **Density is fixed.** There is no zoom and no pan, and `docs/issues.md` §24 has the arithmetic for why the 44pt hit floor can't be raised either: a hundred and twenty nodes at 44pt need essentially the whole canvas.
- **It is dominated on every axis it competes on.** Lookup — search is better. Browse — stream and books are better. Its only unique claim was the shape of the reader's thinking, and a shape made of unreadable labels does not deliver it.

§11 wrote the escape clause itself: *"if the map doesn't earn its place in use, it moves back inside Books."* **This is that call, answered by rebuilding rather than by demoting.** The tab stays, and stays called `map` — it was never named after the force-directed drawing, it was named after what the drawing was for, so moving the drawing down a level doesn't falsify the name.

**The tab's top level is now a summary the reader can read**: themes, ranked, each named and each quoting the note at its centre; then `crossings`, the individual connections that span two books; then `loose`, the notes connected to nothing. It is a list, so Dynamic Type, VoiceOver and the accessibility sizes all work on it — none of which the canvas could ever honestly claim.

**The canvas survives at the two sizes where a graph is legible and answers a real question**: one theme's notes, and two hops from one note. The whole-library view and the book-hub collapse are deleted, along with `collapseAbove` and `-mapCollapse`. §19's chip row survives untouched and still earns its place, because a theme spans books and its attachments are still drawn.

### Grouping is ranked, never thresholded

This is the part that would have been got wrong quietly.

A theme is a cluster of meaning, so the obvious build is agglomerative clustering of the vectors cut at a similarity threshold. **Rejected, and it is important to say why: an absolute threshold is a number tuned to a model the app is designed to abandon.** On today's fallback embedder two paraphrases about attention score `0.267` against each other and `0.274` against an unrelated note about a kitchen tap (`NoteEmbeddingTests` records it). A cut at `0.45` yields **zero themes**. The day `NLContextualEmbedding`'s assets finally compile, the magnitudes move wholesale and the same constant could yield one blob. That is precisely the mistake phase 6 refused when it left the floor, the weights and `k` at the spec's values rather than fitting them to the fallback.

So `ThemeEngine` ranks instead of thresholding. Each note ranks every other by `AffinityEngine.score` — **reused, not re-derived, so there is one definition of similarity in the app** — pairs are kept where each is in the other's top six, and communities are found by greedy modularity merging on that sparse graph until no merge improves it. Ties break on note id, as `AffinityEngine` and `MapGraph` both already do, and for the reason phase 6 gave: a map that reshuffled on every launch would read as the app changing its mind.

What that buys:

- **No magic number anywhere.** Modularity carries its own stopping point, which also bounds the theme count — a summary showing sixty themes is not a summary.
- **It is independent of the floor, the mutual k-NN at 8 and the degree cap of 6**, which is the point. Those three constants exist to keep a *drawing* legible; grouping is a different job and reusing them for it is reusing the wrong tool.
- **It fixes the documented miss.** `n.03` "good error messages assume the system is at fault" and `n.04` "human error is system error" score `0.448` — a near-restatement rejected by the **floor**, not by k-NN. `docs/planning.md` calls that "the worse half" of what reading phase 6's output said. With no floor they land in one theme.
- **It survives the embedder swap**, because rankings do and magnitudes don't.

### A theme's name is extracted, and never comes from a tag

**Amended 2026-08-18, the same day, after a reader looked at the screen.** The rule shipped as *tag first, extracted terms otherwise*: if a majority of a theme's notes shared a tag, that tag named it. The grouping never needed tags — a wholly untagged library produces exactly the same themes — but the screen **read** as though tagging were the mechanism, because six of the seven seed themes came out tag-named. `SeedLibrary` is deliberately heavily tagged (phase 6 built it that way to tune against), so the sample was misrepresenting the feature to everybody who looked at it, including the people who wrote it.

**So tags name nothing.** They remain 20% of `AffinityEngine.score`, which is part of what pulls two notes together in the first place, but no label on this screen depends on the reader having typed anything. A name is extracted from the notes' own words by `ThemeName`, or there is no name and the exemplar leads.

**Single distinctive words read as keyword salad** — `error · systems · blame` — so `NounPhrases` extracts noun phrases as well as bare nouns, and a phrase beats a bare noun on a tie. It is a separate file because it runs `NLTagger`: the impure half, exactly as `TextScanner` is to `ScannedPassage`. **No two parts of a name may share a word**, or it comes out `human error · system error · error messages`, which is one idea said three times.

**What that cost, measured rather than assumed.** On the seed library the tag rule gave `#error`, `#stoicism`, `#craft`, `#design`; extraction gives `error · system`, `truth · weather`, `system`, `mechanism`, and three themes with no name at all. That is **worse**, and it is worth writing down why: a tag is a human's own one-word summary of a note, and extraction from forty short sentences cannot beat one. Shared multi-word phrases turn out to be vanishingly rare at that size — `human error` appears in exactly one note — so the extractor degrades to generic single nouns.

**It was accepted anyway, and for a reason that outranks name quality.** The screen must not make the reader feel they have to tag things for it to work. What the untagged output shows is simply the truth about an untagged library, which the tag rule had been hiding behind good seed data.

**A weak name is left in place rather than suppressed.** Requiring two distinct terms — "one generic noun is not a name" — would drop `system` and `mechanism` and leave five of seven themes unnamed, at which point the section stops reading as themes and starts reading as a list of notes with counts. Considered, not taken; revisit it when the grouping is better.

**And naming quality is downstream of grouping quality.** `truth · weather` is a poor name because the group it names is itself only loosely coherent. No extractor names a bad cluster well. That waits on the same device run everything else here waits on.

### Two things this deliberately does not carry

**The weight bar came out too**, a day after going in. It encoded theme size against the largest theme, which the sort order and the note count each already carried — a third encoding of one fact, drawn as `ASCIIProgressBar`, whose form means *how far through something you are*. A theme is not in progress, and the largest one always filled every cell, which reads as 100% of nothing.

**A quotes-versus-thoughts bar and a "most thought with" book ranking** were both considered and cut. They answer *what are my books like*, which is a different question from *what are my ideas like*, and they are the closest thing here to vanity metrics. A counter is not a takeaway. One orientation line in the header — `46 notes · 7 books · 12 themes` — is the whole of it.

### What this does not fix, again

**Rank-invariance fixes scale, not signal.** If the embedder cannot measure meaning at note length — and the fallback demonstrably cannot — then the rankings are noise too and the themes are well-formed nonsense. This change makes the summary well-*formed*; the device run makes it *true*. `ThemeDumpTests` prints every theme and its notes so the judgement can be made by reading, the same device `AffinityDumpTests` was built as in phase 6, and it should be read the same evening 12b happens. **A confidently wrong theme name is a louder mistake than a wrong line on a graph** — the exemplar quote and the tag-naming are the two hedges against that, and they are why this was worth building before the verdict rather than after.

## 21. The map comes out; a crossing becomes a card

**2026-08-18 · settled** · supersedes §11, §19 and §20 · full reasoning in `docs/specs/2026-08-18-crossings-design.md`

The map was read on a device for the first time. The complaint that came back was **not** that the themes were wrong.

It was that there was **no reason to open it**, and that it **read as a feature rather than a use**.

That is a different failure from the one this repo had been braced for, and it outranks it for a reason worth being exact about: **a perfect embedder does not fix it.** Verified `NLContextualEmbedding` output would have produced better themes on a screen nobody visits. Since phase 6 every decision about the map has waited on a measurement — `docs/issues.md` §14 proves the simulator cannot run the model at all, §6 ranks a device run as the most valuable open item in the project — and that measurement could not have changed this verdict.

**§20 answered the same complaint one level shallower and rebuilt the room.** It recorded *"the tab still had no takeaway"*, diagnosed it as illegibility — every node an opaque handle — and replaced the canvas with a summary that a reader could actually read. That diagnosis was right about the drawing and it produced a better screen. It was answering the wrong question. Legibility was never the thing keeping anyone out; **the tab had no moment in a day that wanted it.**

**The map and review want the same thing, and only one of them has a reason to be opened.** §4 says review exists for *running into your own thinking again*, and gives it the two properties that make somebody come back: it is a **ritual**, and it **ends**. The map has been a second surface competing for that same instinct with neither property — unbounded, always available, never different, therefore never urgent.

A **crossing** — the same idea reached from two different books, months apart — *is* running into your own thinking again. It sat in `MapView.crossingRows` as a computed property on a screen nobody opened, and it is the best thing the linking engine computes. So it moves to where the reader already is.

**The crossing card.** One card in the daily review that is two notes rather than one, read-only, appended after the eight and before the closing card. At most one a day, and only when an unshown crossing exists — punctuation in the set, not half of it. Three things carry it and **none of them is a claim the model makes**: two books (a fact about where), the gap in time (a fact about when, and the one that lands — *you thought this in August and again in March and never noticed*), and a hairline between the halves rather than an arrow, because `NoteEdge` stores a direction and the app has displayed both ways since phase 6. `Glyphs.tabMap` is free once the tab dies, so `[◇]` becomes `Glyphs.crossing` and the vocabulary does not grow.

**Day-stable and rotating.** `CrossingFinder` ranks every cross-book connection once, and the day picks `crossings[daySeed % count]`. Rejected: a `lastShownAt` on `NoteEdge` — a schema change bought for a rotation — and always showing the strongest, which shows one pair every day until it is suppressed. The same rotation is the fallback when every candidate overlaps the day's own eight notes: **not the strongest**, for exactly that reason, and a small library is precisely where the overlap happens.

**`[x] not related` is the first feedback loop in the linking system.** Since phase 6 the app has guessed at meaning and the reader has had no way, anywhere, to say it guessed wrong. It calls `Eraser.suppress` through `ConfirmSheet` — every delete goes through one door — and suppression is what makes the answer stick, because every recompute is a full one (§15). Given §14, no human has ever seen output from the model this design is built on; a reader's own "no" is worth more than any amount of tuning the floor, which §10's own reasoning forbids anyway. It is an affordance, never a question: it does not gate paging, it is not asked for, and skipping it costs nothing. **Zero-work stays zero-work.**

**Three tabs: stream · books · review.** What comes out is `Features/Map/` entire, `ThemeEngine`, `ThemeName`, `NounPhrases`, `GraphLayout`, the `map` tab, the cross-tab `web` route, `[◇] connections` in both places it was offered, and eight launch arguments — 4,082 lines and 90 tests. `GraphLayoutTests` is the loss worth naming: nineteen tests over genuinely hard geometry, all correct, none with a consumer any more. **What survives gets more load-bearing**, not less: `NoteEmbedding`, `AffinityEngine`, `LinkWriter`, `ConnectionIndex`, `NoteEdge`, `Eraser.suppress`, `AffinityDumpTests`, and the backlinks drawn under every note on stream, book detail and the review card. `NotePicker` and `→ link` stay — the manual override outlives the screen it was built beside.

**The argument against, recorded rather than answered: §20 is one day old.** Deleting it the next morning is either good judgment or thrash, and the difference is whether *no reason to open it* is a durable read or a first impression. It was taken as durable, because it is the same complaint §20 recorded about *its* predecessor, answered one level deeper. §11 wrote the escape clause — *"if the map doesn't earn its place in use, it moves back inside Books"* — §20 invoked it by rebuilding, and this invokes it as written.

**And the honest failure mode, which is not a screen problem.** If the crossing card is opened for a month and skipped every time, the conclusion is not that it needs a better card. It is that automatic linking is interesting to build and not interesting to read — which is §10's own flagged risk coming true: *because nobody types a link, nobody learns the habit; if automatic linking underdelivers there is no fallback behavior to lean on.* That would be worth knowing, and there is now one screen where it can be observed instead of three where it could not.

## 22. The app stops saying things twice, and starts saying the one thing it wasn't

**2026-08-19 · settled** · touches §10, §13 and §21

Three complaints against the review tab, read together because they are the same complaint: the app repeats itself where it has nothing to add, and stays quiet where it does.

### `[t] thought` becomes `thought`

**The marker is redundant exactly when the word beside it is the marker's own name.** Run the vocabulary through that test and it sorts itself: `[+] add a thought`, `[ ] star`, `[x] not related`, `[↻] keep going`, `[x] cancel` are all a glyph and a **verb**, where the bracket is the affordance and, in `[ ]` / `[*]`, literally the checkbox. `[~] stream` and `[=] books` are a tab's identity, and the glyph is the only mark it has. `[t] thought` is a glyph and **the glyph's own name** — one fact, spelled twice, and the word spells it better than the letter does.

It isolates to a single line: `RowMapping.swift`'s `meta` was the only place in the app where a kind marker was glued to its own label as a plain label. Everything else that pairs one with a word is a control.

**This is house precedent, not a new idea.** `MarkdownExport` has said since it was written that the export emits *"the word, not the marker — a bracketed glyph is a thing the app draws, not a thing a document says"*, and `MarkdownExportTests` asserts the export contains no `[t]`. The only thing decided here is that the same reasoning applies to what the app draws.

**Rejected: taking the glyphs out of the capture sheet's type selector too.** There they are a segmented *control*, the bracket is the option's mark, and it is the one place in the app a reader ever learns what `[t]` means. `BookFormSheet`'s status markers stay for the same reason. §13's rule is unchanged: every marker is still bracket-plus-character, and there are still no dingbats.

**The cost, named:** `[t] thought · 1 hr` is drawn by the archived prototype, and `CLAUDE.md` names the prototype as the authority on **look**. This is a deliberate override of that authority — the first one — and it is recorded here rather than left to drift. The prototype stays the authority on everything it has not been overridden on.

### `→ n.11` comes off every row

A bare id is a bad link label. It gives the reader nothing to decide with: you cannot tell what is behind `→ n.11`, so tapping it is a coin flip, and on the review card it was a fifth thing competing with five actions. The prototype never drew them — they arrived in phase 2 — and no screen ever showed the reader what one pointed at without navigating there.

**The linking engine does not become invisible, and that is what made this affordable.** The export still writes every connection as `[[n.03]] · [[n.09]]`, settings still prints a live count, `NotePicker` still filters on the graph, and the crossing card is still the app's own reading of it. `AffinityEngine`, `LinkWriter`, `NoteEdge` and `ConnectionIndex` are untouched. What stopped is the drawing, not the computing.

**It also removed real work from three `body` passes.** `StreamView`, `SearchView` and `BookDetailView` each held a live `@Query` over every edge in the library and rebuilt an O(edges) index on every redraw, to render a line of ids. All three queries are gone. That is the same rule that caught `ImageRenderer` in phase 11 — `CLAUDE.md`, *nothing expensive in a `body`*.

**`NoteLink` lost its note form** with the last producer of it: no `passim://note/11`, no `.onOpenURL`. `passim://book/11` behind a book title is the whole scheme now. Opening a note by id still happens — from `-openNote` and from a tapped reminder — and neither ever went through a URL.

**The accepted cost:** `→ link` on a review card now writes an edge whose effect is invisible until a future crossing rotation reaches it, and only if the pair crosses books. That is an action with no feedback, it is known, and it is not being solved by putting the ids back. If manual linking turns out to matter, the answer is a surface that shows a note's connections as *notes* — which is what `→ n.11` never was.

**§21 is not being re-litigated.** It listed the backlinks under every note among what survived the map's deletion; that was an inventory of what still existed, not an argument that it earned its place. The argument that killed the map — *no reason to open it* — is the same one applied here one level smaller: no reason to tap it.

### The crossing card says what it is

The card's only claim that its two notes were related was `n.08 · n.40 · [◇] crossing` at 13pt `textAsh`: the palest text on the card, in the position the eye skips, arriving **before** either note, so *crossing* had nothing yet to attach to. And the thing physically between the two halves was a bare `Hairline` — the same 12% rule the app uses everywhere else to mean *these are separate items*. The strongest visual signal on the card argued against the card.

Meanwhile `29 days apart` — which §21 calls the fact that lands, *you thought this in August and again in March and never noticed* — sat in the foot, below both notes, beside a destructive action, reading as chrome.

**So the claim moved into the seam.** `LabeledRule` replaces the bare hairline: `──── 29 days apart ────`. A labeled break is what turns a divider from a boundary into a relationship, it is standard terminal furniture rather than a new idiom, it is still `Theme.hairline` at 12%, and **it is still not an arrow** — §21's rule holds, because a label is not a direction. `design-system.md` used to end that rule with *this card adds no vocabulary*; the honest correction is that the bare hairline was the **wrong** vocabulary, not none.

**The head names the claimant, not the claim.** `[◇] crossing` over `the app connected these two notes`. §21 is exact that the three things carrying this card are facts and *none of them is a claim the model makes* — and *the same idea, in two books* would have been one, on scores `issues.md` §14 says nobody has ever verified. That the app drew a line is a fact. It is also the fact `[x] not related` operates on: a reader can contradict the app, not an idea.

**The two ids came off the head** for the same reason they came off every row.

**The head stops growing, and it is the fifth and last thing in the app that does.** Uncapped, the sentence took four lines at `accessibility-extra-extra-extra-large` and pushed the seam off the bottom of the screen — the card explaining itself at the price of not showing what it was explaining. `chromeTypeSize()` puts it back at the fold `issues.md` §25 recorded, and the seam now lands *above* that fold, where the gap in the foot never did. Both notes stay uncapped. This is the rule working as written: a signpost that fills the room it points out of is worse at its job.

**`disconnect n.07 and n.11?` became `disconnect these two notes?`** — the card no longer shows those ids, so naming them was precision about something the reader had never seen. What actually goes is in the consequence line, which is what the question is for.

### What was deliberately not done

**No color, no dingbat, no badge, no box around the pair, and no explanatory paragraph.** Phase 12's standing warning is that there have been three drawings of this idea and each was better than the last and none was opened; a fourth would be the same mistake with a different shape. This adds one rule and one sentence, and if the card is skipped for a month the conclusion is still the one §21 wrote down — not that it needs a better card.

## 23. The day's set becomes a stored fact, not a re-derivation

**2026-08-19 · settled** · fixes §4 rather than changing it

§4 has said since phase 5 that the day's set is "**fixed per calendar day so leaving and returning doesn't reshuffle it**." That was implemented as *held in `@State`* — and `RootView` is a `switch tab` rather than a `TabView`, so leaving the tab tears `ReviewView` down and destroys the set, the position, the crossing and the reject flag together. Every return rebuilt from scratch at card 1. Reported from a device: *"doesn't seem to stay updated to the swipe the person was on or if they finished for the day."*

**The rebuild was not even the same set, and that is the part worth writing down.** `ReviewSetBuilder` scores mostly on `daysUnseen`, which reads `lastSurfacedAt`; paging past a card writes exactly that field. So every card the reader *actually read* scored ~0 on the way back and dropped out of the top eight, and unread notes took its place. **The more of the set you read, the less of it came back.** The builder is day-stable over a library that hasn't been read — which is not the library anybody has after opening review. No amount of tuning the builder fixes this: the day's set has to be *remembered*, not recomputed.

So `ReviewSession` stores the day, the ordered ids, the position and the crossing's pair in `UserDefaults`, for the reason `Preferences` gives — none of it is a note, and none of it should sync to another device as content. `ReviewSetBuilder` and `ReviewWriter` are untouched and still pure.

- **The resume is literal.** Wherever the reader was standing, including the closing card, which is how "finished for the day" is remembered — there is no separate completion flag and no furthest-read tracking. Nathaniel's framing, and it is the right one: *"like a normal app would do."*
- **The crossing card comes back too, rejection and all.** `CrossingFinder.find` deliberately does *not* filter suppressed edges, unlike `all`: `ReviewView` already refuses to remove the card or re-pick the pair within a session, and coming back from another tab must not put a fresh claim under a thumb that just answered the question. The suppression lands on tomorrow's `pick`, where it always did.
- **A set that lost notes to a delete is discarded below the minimum**, rather than restored short — three surviving cards of eight would otherwise draw "not enough notes to review yet" over a library of forty.
- **Midnight now resets the cards, including for an app left open.** This supersedes `docs/issues.md` §11, which called the gap harmless and asked nobody to chase it. That was true of a set obviously rebuilt on every arrival; it stopped being true the moment the position became something the app remembers on purpose — `.task` runs on *appear*, and a phone left on review overnight foregrounds rather than re-appearing, so it would have woken on yesterday's eight at yesterday's card, looking deliberate. A `scenePhase` check rebuilds when the stored day isn't today.
- **The accepted cost**, taken knowingly: mid-set at 11:58pm, away three minutes, back at 12:01am is a new set at card 1. Correct per "fixed per calendar day," and a conditional to dodge it would be the kind of cleverness that becomes the next bug.

**Rejected: keeping `ReviewView` alive across tab switches** (a real `TabView`, or `ZStack` + `.opacity`). It fixes the position in a few lines, but not the set across a relaunch, and it leaves all three tabs' `@Query`s live and re-evaluating bodies on every `context.save()` — the class of defect §23 of `docs/issues.md` was written about. Persistence, not view lifetime.

---

## 24. A note can be edited, and the edit is silent

**Phase 15.** Nothing in the app could correct a note. A typo was permanent, and so were the two things the app itself warns are unreliable: a transcript from on-device recognition and a line of OCR off a printed page. The app is careful to land both in an *editable field before the save* — `docs/planning.md` phase 3 and phase 9 both say so — and then offered nothing after it. Delete and retype was the only recovery, behind a long press with no visible affordance.

For an app whose whole premise is that a note is worth meeting again in six weeks, a note you can't correct is the wrong kind of permanent.

`NoteWriter.update` is the one path a note takes to change its own words, for the same reason `save` is the one path it takes to exist and `refile` the one path it takes to change books. `EditNoteSheet` is the only thing that calls it, reached from `edit` on a row's long press — the same menu as `move to book…` and `delete`, and `edit` sits first because it's the only one of the three that is neither destructive nor a move.

- **The type selector, the recorder and the scanner are not on it.** They're capture-time controls. How a note was captured is a fact about the note rather than about the keystrokes — the same rule that already keeps an edited transcript a `voice` — so `update` doesn't take a kind and a draft carrying one can't smuggle it in.
- **The book isn't on it either.** `move to book…` is its own path through `refile`, on the same long press. Folding it in would be a second way to do one thing.
- **The edit is silent.** No `editedAt`, no `edited` on the row, and `createdAt` is untouched, so the note holds its id and its place in the stream. §22's rule — the app doesn't spend a line saying what the reader already knows they just did — and it kept the schema at V1 on the day V1 was named.
- **A changed body clears the embedding; a changed page or tag doesn't.** `AffinityEngine` scores tags as their own term and never reads a page, so only words are worth re-embedding a library over.

**Both halves of the embedding get cleared, and the reason is not one reason twice.** `docs/planning.md` had been carrying a prescription for this since phase 6 — clear `embeddedAt`, "the queue is the only thing that would notice" — and it was half the answer:

- `embedding` is what `LinkWriter.embed` reads as `hasVector`, and it skips every candidate that has one. Keep it and the re-embedding pass skips the single note that needed it, while `vector(from:)` goes on scoring the reader against words they deleted.
- `embeddedAt` is what `.linking()` counts as `pending`. An edit changes neither the library's note count nor its pending count on its own, so the modifier's `queue` compares equal and **the recompute never fires at all.**

Clear only the second and you re-trigger a pass that re-embeds nothing. Clear only the first and nothing triggers the pass. `NoteWriterTests` asserts each field with its reason written beside it, because a regression in either is silent.

**Book detail was consolidated to one `.sheet` on the way through.** It already carried two, which `StreamView` documents as "a coin-toss over which one presents"; `edit` would have made it three. It now has one `BookDetailSheet` value, the way the stream has one `StreamSheet`.

---

## 25. The sample library stops shipping; a first launch is the Inbox and nothing else

**Phase 15**, out of the App Store feasibility pass, and it was not on any existing list.

`Library.prepare` seeded whenever the store held no books, and on a real install that is the reader's first launch. They got five books they had not read and forty notes they had not written — already starred, already threaded, already connected — and review then handed those notes back to them, one a day, as things they once thought. The app's whole premise is meeting *your* older thinking again; it was staging a fake version of that on day one.

Two separate problems, and the first is the one that matters:

- **It is somebody else's reading, presented as yours.** No amount of good sample content fixes that. A reader cannot tell which of the first forty notes are theirs without remembering, and the one screen designed to resurface old notes is the one that makes the confusion daily.
- **App Review reads pre-populated user data as an unfinished app** — guideline 2.1 / 4.3 territory. Placeholder content in a shipping build is a thing reviewers look for.

**Removed from the bootstrap rather than deleted.** Every screenshot in this project needs a library to photograph and the simulator can't be tapped, so `SeedLibrary` stays exactly where it was, behind `-sampleLibrary 1` (all forty) and `-tinyLibrary <n>` (a prefix), and the tests go on using it.

`Library.Bootstrap` is `.empty` or `.sample(notes:)` and **has no default**. The expensive mistake is the sample library turning up somewhere nobody asked for it — which is the mistake the app shipped with — so every caller states which it wants and a new one can't inherit the wrong answer by omission.

**`.empty` still writes one book.** "No seed" was never the same thing as "no books": the Inbox is a `Book` found by status, `NoteWriter` falls back to it, `BookWriter.apply` and `Eraser.delete(book:)` both refuse to touch it, and `CrossingFinder` excludes it as a source. Bootstrapping the Inbox and only the Inbox is the actual change.

**The cost is a cold start, and it is now visible instead of hidden.** Review needs eight older notes, the crossing needs a cross-book edge, and the linking web needs enough notes to have neighbours above a 0.55 floor. On day one the app is a very austere notes list and every reason to keep it is weeks away. The seed was concealing that, not solving it. File import — Kindle, Readwise, markdown — is the real answer and is deliberately out of v1; until then the honest moves are copy that explains the deferral and a listing that promises the right thing.

**Residual, and it is small:** `SeedLibrary`'s passages are still compiled into the binary, unreachable. The exposure that mattered — presenting in-copyright quotations from Kahneman, Pirsig, Deutsch and Norman to every installer as their own library — is gone; what's left is dead strings. Rewriting them from public-domain sources, or compiling the fixture out of release, are both available and neither is urgent.

---

## 26. The app is called Passim

**Phase 15.** `marginalia` is unavailable in the only sense that matters: **Marginalia: Book
Quotes** is already on the App Store and is substantially this pitch. Open question 5 had
guessed "likely contested" since phase 10 and was right.

The search turned up something more useful than one collision. **Commonplace: Notebook** —
"intelligent recall to gently surface past entries," privacy-first, no ads, no tracking.
**Library Notes** — inspired by commonplace books, with a review mode over quotes. **Screvi**,
**KnowledgeSaved**, **BookNotes** — gather highlights, revisit them. *Book notes* is crowded and
*resurfacing what you saved* is crowded, and both were the categories this app was naming itself
into.

**What none of them claims is the crossing:** two notes from two different books, connected by
meaning, with the gap in time between them. That is the free ground, and the name should stand
on it.

*passim*, adv. — "here and there throughout." The citation term for an idea that is not on one
page but scattered across the whole work. **It is the definition of a crossing.** It is also
exactly the register the app already speaks in: an obscure scholarly abbreviation, set in
JetBrains Mono, next to `[◇]` and `n.11`.

The cost is real and taken deliberately: nobody knows the word on sight. The store name carries
`Passim — Book Notes` so the category is legible, and the keyword field does the searching — the
name's job is to be memorable and defensible, not to be a description.

Rejected: `Commonplace` (taken, and by the nearest competitor), `Throughline` (taken, plus
NPR's), `Concordance` (taken repeatedly, permanently Bible-flavoured), `Interleave` (taken by a
local-first incremental reading app — too close to be safe). `Ligature` was the runner-up and is
clear: two letters joined into one, typographic like the rest of the identity. It reads as a
font tool, which is the only thing against it.

**Availability came from web search, which is indicative and not authoritative.** A name is held
only once the app record exists in App Store Connect. Reserve it before building anything on it.

---

## 27. The sample library is rewritten from public-domain sources

**Phase 15**, and it is the prerequisite §25 left behind. Removing the seed from a reader's
first launch fixed the thing that mattered — nobody is handed somebody else's library any more —
but the passages were still compiled into the binary, and they were about to be published on an
App Store page under Nathaniel's name. Dead strings are one thing; a store screenshot is
another.

The old library quoted *Thinking, Fast and Slow*, *The Design of Everyday Things*, *Zen and the
Art of Motorcycle Maintenance* and *The Beginning of Infinity* verbatim. All four are in
copyright.

Rewritten from five works that are not: **Meditations** (Marcus Aurelius), **Essays**
(Montaigne), **Walden** (Thoreau), **The Principles of Psychology** (William James) and
**Self-Reliance** (Emerson).

**Translations carry their own copyright and are not interchangeable.** Aurelius is George Long
(1862) and Montaigne is Charles Cotton (1685) for that reason alone — the modern translations
read better and could not be used. The three English authors are clear outright.

**The structure is unchanged and the overlap is still deliberate.** Forty notes, six books,
seventeen pinned edges, three follow-ups — the same shape, because phase 6 tunes the affinity
weights against this content and `ReviewSetBuilder` is exercised against its dates. What
replaced `attention`/`error`/`quality` as the load-bearing themes is `attention`, `solitude`,
`habit`, `doubt` and `conformity`, each running through three or four authors so the embedder
has something real to find and the crossing card has something to show. It does: the first
crossing it produced was Thoreau's *"the mass of men lead lives of quiet desperation"* against
Emerson's *"whoso would be a man must be a nonconformist"*, written a fortnight apart, and that
is the App Store screenshot.

**A quieter gain.** Roughly half the notes are now the reader's own thoughts rather than
quotations, which is both safer and more honest about what the app is for — the quotes are the
raw material and the thinking is the point. `mon.quote` is the joke that earns its place:
*"I quote others only in order the better to express myself."*


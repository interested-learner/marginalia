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

**2026-08-13 · settled**

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

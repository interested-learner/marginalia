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

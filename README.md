# marginalia

Notes from books. A native iOS app for capturing what you read and actually running into it again.

---

Most reading apps are built around highlights you never revisit. marginalia is built around the opposite assumption: the value isn't in capturing the passage, it's in meeting it again six weeks later next to a thought you'd forgotten you had.

**Three tabs.**

- **stream** — every note across every book, newest first, filterable by tag. A capture bar sits at the bottom the whole time: type a thought, or hold to record one. Captures without a book land in an Inbox to file later.
- **books** — your library and each book's notes. Add a book by searching for it or scanning the barcode on the back cover.
- **review** — a set of about eight older notes chosen fresh each day, one per screen, swiped through. Star the good ones so they come back more often. Add a follow-up thought and the note grows a thread instead of sitting still.

Notes carry ids (`n.11`) and link to each other, so a thought from one book can point at a passage in another.

**Capture is the part that has to be frictionless**, so there are four ways in: type it, speak it (transcribed on-device, no network, no API key), point the camera at a printed page and tap the passage, or write it directly against a book.

## Design

The interface is built on the OpenCode design system, which permits itself very little: one monospace typeface, a near-white page, hairline rules, and no shadows anywhere. Icons are ASCII markers — `[+]` reading, `[x]` finished, `[q]` quote, `[t]` thought, `[v]` voice, `[↻]` review. There is no cover art and no color-coding; the only saturated color in the app is the red recording dot.

The full token reference is in [`docs/design-system.md`](docs/design-system.md), and the original prototype is archived at [`docs/prototype/Marginalia.dc.html`](docs/prototype/Marginalia.dc.html) — open it in a browser to see where the app came from.

Light and dark are the same two colors swapped: `#fdfcfc` and `#201d1d`.

## Requirements

- macOS with **Xcode 26** or later
- iOS **18.0**+ target device or simulator
- An Apple ID for installing to your own device. A **paid** Apple Developer account is required only for iCloud sync and notifications — everything else runs on a free account.

## Build and run

```bash
git clone <this repo>
cd marginalia
open Marginalia.xcodeproj
```

Select the **Marginalia** scheme and an iPhone 17 simulator, then run. Or from the terminal:

```bash
xcodebuild -scheme Marginalia \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build test
```

The app seeds a small library on first launch so there's something to look at.

To run on your own iPhone: connect it, pick it as the destination, and set your team under **Signing & Capabilities**. You'll need to trust the developer certificate on the phone the first time (Settings → General → VPN & Device Management).

Microphone, speech recognition, and camera permissions are each requested the first time you use the feature that needs them — never at launch.

## Layout

```
Marginalia/
  Design/       theme, typography, ASCII glyph vocabulary, shared components
  Model/        SwiftData models — Book, Note, FollowUp
  Features/     Stream · Capture · Books · Review · Search · Settings
  Services/     transcription, OCR, barcode, book lookup, notifications, export
docs/
  design-system.md    the full token and component reference
  decisions.md        what was chosen and why
  specs/              design specs
  prototype/          the original Claude Design prototype
```

## Data

Notes live on your device in SwiftData. Nothing is sent anywhere — transcription runs on-device, and the only network call the app makes is looking up a book you searched for.

iCloud sync is designed for but not yet enabled; the data model is already shaped to CloudKit's constraints so turning it on is a configuration change rather than a migration.

Everything exports to Markdown with `[[n.05]]` wiki-links, so your notes open in Obsidian and are yours to leave with.

## Roadmap

Shipping toward a first App Store release:

- [ ] Design system and three-tab shell
- [ ] Stream, tag filters, note links
- [ ] Text and voice capture
- [ ] Books, book detail, search and ISBN scan to add
- [ ] Review — daily set, stars, follow-up threads, share as image
- [ ] Full-text search, Markdown export, daily notification
- [ ] Camera OCR capture
- [ ] App icon, empty states, device polish

Later: iCloud sync, Lock Screen widget, Share extension, iPad.

## Credits

Typeface is [JetBrains Mono](https://www.jetbrains.com/lp/mono/), SIL Open Font License 1.1. The design system specifies Berkeley Mono, a commercial face; JetBrains Mono is its designated open substitute and the swap is two lines in `Design/Typography.swift`.

Book metadata comes from [Open Library](https://openlibrary.org).

# App Store listing — draft

Written phase 15, alongside the feasibility pass. Character limits are App Store Connect's and
every field below is counted. **Nothing here is submitted; this is copy to argue with.**

The governing constraint is `docs/decisions.md` §25: a first launch is now empty, review needs
about eight *older* notes, and the crossing needs a cross-book connection. **A listing that
promises connections on day one will generate the reviews that kill the app.** Every line below
is written to promise the thing that actually happens.

---

## Name — 30 characters

```
Passim — Book Notes
```
19 characters. **Decided phase 15** — `docs/decisions.md` §26 — and **accepted by App Store Connect on 19 aug 2026**, which is the only check that counts. `Passim` alone was taken; the two-part form cleared.

*passim*, adv. — "here and there throughout." The citation term you use when an idea is not on
one page but scattered across the whole work. That is the definition of a crossing, and the
crossing is the only thing in this app that no competitor claims.

`marginalia` is out: **Marginalia: Book Quotes** already exists and is substantially the same
pitch. The wider search was worse news than one collision — **Commonplace: Notebook** does
"intelligent recall to gently surface past entries," privacy-first, no ads or tracking;
**Library Notes** has a review mode for book quotes; **Screvi**, **KnowledgeSaved** and
**BookNotes** all gather and revisit highlights. *Book notes* and *resurfacing* are both
crowded categories, and a name pointing at either would put this app in a queue behind them.
Cross-book semantic connection is the free ground.

Rejected, and why, so nobody re-runs the search:

| Name | Verdict |
|---|---|
| `Commonplace` | Taken — *Commonplace: Notebook*, and it is the closest competitor of the lot |
| `Throughline` | Taken on the App Store, and NPR has a show of that name |
| `Concordance` | Taken several times over, all Bible study. The association is unshakeable |
| `Interleave` | Taken — interleave.app, a local-first incremental reading app. Too close |
| `Ligature` | **Clear**, and the runner-up. Two letters joined into one; typographic, which suits the identity. Reads as a font tool to some |
| `Crossing` | Unverified and a common word — hard to trademark, likely contested |

**Availability was checked by web search, which is indicative and not authoritative.** The name
is only really yours when the app record is created in App Store Connect, which is what reserves
it. Do that before building a listing around it.

## Subtitle — 30 characters

```
notes taken from books
```
22 characters. It is the app's own sentence, already in the about screen, and it says the
category without a verb.

## Promotional text — 170 characters, editable without a review

```
The value isn't in capturing the passage. It's in meeting it again six weeks later, next to a
thought you'd forgotten you had.
```
124 characters.

## Keywords — 100 characters, comma-separated, no spaces

```
reading,highlights,quotes,zettelkasten,commonplace,annotation,margin,recall,library,journal,reread
```
98 characters. **Nothing here repeats the name.** App Store Connect already indexes the app name, so `passim`, `book` and `notes` would be spent twice. Deliberately excludes "AI" — the linking is on-device and still unproven (`docs/issues.md` §14), and the word sets an expectation the app should not. Competitor names are prohibited, so no `marginalia`.
(`docs/issues.md` §14), and the word invites an expectation the app should not set.

## Description — 4000 characters

```
Most reading apps are built around highlights you never open again. marginalia is built around
the opposite bet: what a note is worth is not the moment you write it, but the moment you run
into it again.

Three tabs, and nothing else.

STREAM
Every note you've taken, newest first. A capture bar sits at the bottom the whole time — type a
thought, or hold to record one and have it transcribed on the device. Anything captured without
a book waits in an Inbox until you file it.

BOOKS
Your library, and each book's notes. Add a book by searching for it, by scanning the barcode on
the back cover, or by typing it in.

REVIEW
About eight of your older notes, one per screen, swiped through. Star the ones worth keeping
close and they come back more often. Add a follow-up and the note grows a thread instead of
sitting still.

FOUR WAYS IN
Type it, speak it, point the camera at a printed page and tap the passage you want, or write it
straight against a book. Transcription and text recognition both run on the device, and neither
is ever saved without showing it to you first — you get an editable field, not a guess.

CONNECTIONS THAT BUILD THEMSELVES
You never link anything by hand. As you write, the app reads each note and connects it to the
ones that mean something similar — a line from Walden can find one from Emerson written a
fortnight earlier, without the two sharing a single word. Some days review ends with a crossing: two notes from two
different books, and how long apart you wrote them. You can always tell it that it's wrong.

This needs a little time to be worth anything. Connections need notes to connect, and review
shows you notes you've had a while. The first week is a notes app; the month after is the
reason.

DESIGNED TO GET OUT OF THE WAY
One monospace typeface, a near-white page, hairlines instead of shadows, and ASCII marks
instead of icons. No cover art, no colour-coding, no badges, nothing to arrange. Full Dynamic
Type support, and a dark mode that is the same two colours swapped.

PRIVATE BECAUSE IT'S LOCAL
No account. No analytics. No tracking. No ads. Your notes never leave the phone, and the model
that connects them runs on it. The only thing that ever goes out is a book title or ISBN you
search for, sent to Open Library to fill in the author and page count — and you can always type
the book in instead.

Your notes are on this phone and nowhere else: there is no sync yet, so export as markdown is
worth doing. It writes every book, note and thread into one plain document with the connections
as links, and it opens in Obsidian or anything else.
```

~2,470 characters. **Two paragraphs are doing expectation-setting work and should not be cut:**
the "needs a little time" paragraph and the "no sync yet" sentence. The first is the answer to
§3.1's cold start; the second stops a reader assuming iCloud, which is what people assume of an
Apple-native notes app.

## Required URLs

| Field | Value |
|---|---|
| Privacy policy | `https://interested-learner.github.io/marginalia/site/privacy.html` |
| Support | `https://interested-learner.github.io/marginalia/site/support.html` |

Both live at `docs/site/`. **To publish:** GitHub → Settings → Pages → Deploy from a branch →
`main` → `/docs`. `.nojekyll` is already there so the files serve as written. **Both pages carry
`supportforapplication@gmail.com` as a placeholder** — that is the one thing that must be filled in before
either URL goes in the listing.

## Category, rating, availability

- **Primary category:** Productivity. **Secondary:** Education.
- **Age rating:** 4+. Nothing in the app generates or displays third-party content.
- **Price:** free. No IAP, no subscription, and no server cost to recover.
- **Devices:** iPhone only, portrait only (`TARGETED_DEVICE_FAMILY = 1`). It runs on iPad in
  compatibility mode; the listing should not claim iPad.
- **Localisation:** English only, and the linking is English-only in a way the reader cannot
  see (`docs/issues.md` — `NoteEmbedding` pins `.english`). Until that changes, do not localise
  the listing into languages the app cannot actually connect notes in.

## Screenshots — taken, 6.9", 1320 × 2868

**Six, in `screenshots/app-store-6.9/`** (that directory is gitignored, so they live on disk
rather than in the repo). All captured on iPhone 17 Pro Max, portrait, status bar overridden to
9:41 / full battery / full signal the way Apple's own screenshots are, against
`-sampleLibrary 1`.

| # | File | What it shows | Caption, if you add one |
|---|---|---|---|
| 1 | `01-stream.png` | The identity shot — the margin, note ids, the quote rule, tag chips, the capture bar | every note you've taken, newest first |
| 2 | `02-crossing.png` | **The differentiator.** Thoreau and Emerson, two books, both `#conformity`, `14 days apart` | two books. one idea. fourteen days apart. |
| 3 | `03-review.png` | A review card mid-set, `3 of 8`, starred, with its actions | eight older notes a day, one per screen |
| 4 | `04-book.png` | Walden — author, status, `352pp`, `[9]` notes, quote rules | your library, and what you took from it |
| 5 | `05-capture.png` | All four ways in, with `[s] scanned · edit before saving` | point the camera at the page |
| 6 | `06-dark.png` | The crossing again, in dark | the same two colours, swapped |

**Order matters and this one is deliberate.** Shot 2 is the crossing rather than something
prettier: it is the only screen in the app that no competitor has, and the App Store shows the
first two or three in search results. Leading with the stream and then the crossing says *this
is a notes app* and *here is why it is a different one* in the two frames most people see.

**They are deliberately unframed and uncaptioned.** This app's whole pitch is its restraint —
one typeface, no icons, no colour. A marketing banner in some other style across the top would
be arguing against the product in the product's own screenshot. The captions above are there if
you decide otherwise; set them in JetBrains Mono on `#fdfcfc` if you do.

**Retaking them.** The crossing rotates daily (`crossings[daySeed % count]`), so shot 2 will
show a different pair tomorrow — several are good, and there is no wrong one. The rest are
stable.

```bash
PM=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | grep -o "[0-9A-F-]\{36\}")
xcrun simctl boot $PM
xcrun simctl install $PM .build/Build/Products/Debug-iphonesimulator/Marginalia.app
xcrun simctl status_bar $PM override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularMode active --wifiBars 3
xcrun simctl spawn $PM defaults write com.apple.Preferences DidShowContinuousPathIntroduction -int 1
xcrun simctl launch $PM com.passim.app -sampleLibrary 1
```

Two traps, both of which cost time here: **uninstall after `build test`, not before** — the test
host bootstraps an empty library into the container (`docs/issues.md` §29) — and the QuickPath
keyboard tutorial will cover any screen with a keyboard until that `defaults write` is done.

## Content in the screenshots

**All public domain, and that is the point.** `SeedLibrary` was rewritten in phase 15
(`docs/decisions.md` §27) from Marcus Aurelius (George Long, 1862), Montaigne (Cotton, 1685),
Thoreau, William James and Emerson. Translations carry their own copyright, so the two
translated authors use editions that are clear — a modern translation would not be
interchangeable even though it reads better.

The previous library quoted *Thinking, Fast and Slow*, *The Design of Everyday Things*, *Zen and
the Art of Motorcycle Maintenance* and *The Beginning of Infinity* verbatim. Those passages on a
public store page under your own name are considerably more exposed than dead strings in a
binary, which is why this had to happen before any screenshot was taken.

## What's New — first release

```
First release.
```

## Before submitting

- [x] ~~Settle the name~~ — `Passim`, phase 15, `docs/decisions.md` §26. Still to do: **reserve it in App Store Connect**, which is the only thing that actually holds it
- [ ] Fill in `supportforapplication@gmail.com` on both pages and enable GitHub Pages
- [x] ~~Public-domain screenshot fixture~~ — `SeedLibrary` rewritten, `docs/decisions.md` §27
- [x] ~~Screenshots~~ — six at 1320 × 2868 in `screenshots/app-store-6.9/`
- [ ] App Privacy answers in App Store Connect, matching `PrivacyInfo.xcprivacy`: Search History, not linked, not tracking, App Functionality
- [ ] An archive that validates — needs `-allowProvisioningUpdates`, which registers the App ID
- [ ] The device evening (`docs/planning.md` phase 12b). Four capture paths and the embedder have still never run on hardware

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
19 characters. **Decided phase 15** — `docs/decisions.md` §26.

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
book notes,reading,highlights,quotes,zettelkasten,notetaking,annotations,commonplace,margin,recall
```
98 characters. Deliberately excludes "AI" — the linking is on-device and unproven
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
ones that mean something similar — a passage on impermanence can find a note on anchoring
without sharing a single word. Some days review ends with a crossing: two notes from two
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

## Screenshots — 6.9" is required, 3–10 accepted

Portrait, and every one of them needs a library to photograph, so: `-sampleLibrary 1`.

1. **stream** — the margin, the ids, a quote with its rule, the capture bar. The identity shot.
2. **a crossing** — `-startTab review -reviewCrossing 1`. The one thing no other reading app does.
3. **review card** — one note filling the screen, with its actions.
4. **book detail** — notes under a book, `499pp` in the byline.
5. **capture sheet** — the four types, showing how a note gets in.
6. **search** — one field over everything, grouped by book.
7. **dark mode** — any of the above, to show it is the same two colours swapped.

**Do not ship screenshots of the sample library as it stands.** It quotes *Thinking, Fast and
Slow*, *The Design of Everyday Things*, *Zen and the Art of Motorcycle Maintenance* and *The
Beginning of Infinity* verbatim. Dead strings in a binary are one thing; the same passages
published on a store page under your own name are considerably more exposed. **Write a
screenshot fixture from public-domain sources** — Marcus Aurelius and Montaigne are already in
the seed and are both clear — or from your own notes.

## What's New — first release

```
First release.
```

## Before submitting

- [x] ~~Settle the name~~ — `Passim`, phase 15, `docs/decisions.md` §26. Still to do: **reserve it in App Store Connect**, which is the only thing that actually holds it
- [ ] Fill in `supportforapplication@gmail.com` on both pages and enable GitHub Pages
- [ ] Public-domain screenshot fixture
- [ ] App Privacy answers in App Store Connect, matching `PrivacyInfo.xcprivacy`: Search History, not linked, not tracking, App Functionality
- [ ] An archive that validates — needs `-allowProvisioningUpdates`, which registers the App ID
- [ ] The device evening (`docs/planning.md` phase 12b). Four capture paths and the embedder have still never run on hardware

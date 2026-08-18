# Design system

The OpenCode system, as marginalia uses it. This is the reference to consult when building any view — the values below are lifted from the prototype's markup, not approximated.

The system's whole identity rests on restraint: **one typeface, two colors, hairlines, and no shadows.** Every rule below exists to protect that. Adding a shadow or a second color doesn't slightly weaken the design, it makes it look like a different app.

---

## Color

Light and dark are the same palette inverted. The light values are the prototype's exactly; the dark values are their counterparts, tuned so contrast ratios hold.

| Token | Light | Dark | Used for |
|---|---|---|---|
| `canvas` | `#fdfcfc` | `#201d1d` | Page background, secondary button fill |
| `surfaceSoft` | `#f8f7f7` | `#302c2c` | Text inputs at rest, pressed rows |
| `surfaceCard` | `#f1eeee` | `#3a3636` | Pressed state on secondary buttons |
| `ink` | `#201d1d` | `#fdfcfc` | Primary text, filled buttons, active indicators |
| `inkDeep` | `#0f0000` | `#ffffff` | Pressed state on filled buttons |
| `onInk` | `#fdfcfc` | `#201d1d` | Text on a filled surface |
| `textCharcoal` | `#302c2c` | `#ebe9e9` | Reserved; quotes now use `ink`. Kept for future use |
| `textBody` | `#424245` | `#d8d6d6` | Note body text |
| `textMute` | `#646262` | `#9a9898` | Source lines, secondary labels, inactive tabs |
| `textAsh` | `#9a9898` | `#787676` | Note ids, timestamps, metadata, counts |
| `hairline` | `rgba(15,0,0,0.12)` | `rgba(253,252,252,0.14)` | Every divider, unfilled border, margin rule, and graph edge |
| `disabled` | `#9a9898` | `#646262` | Filled button with nothing to do |
| `danger` | `#ff3b30` | `#ff453a` | Recording dot, destructive confirmation |

`danger` is the only saturated color in the app. Everything else is on the ink-to-paper ladder.

**These live in `Design/Theme.swift` and nowhere else.** A hex literal appearing in a view is a bug, and so is `.secondary`, `.gray`, or any other system color — those don't follow this palette in dark mode.

## Type

**JetBrains Mono** at every size and weight. No sans face, no display face, no italic. Weights: 400 regular, 500 medium, 700 bold.

Sizes are **one step up from the prototype**, which was drawn for a browser window about 410px wide and reads tight on a phone. The `→` column marks what changed.

| Role | Size | Weight | Line height | |
|---|---|---|---|---|
| Wordmark | 16 | 700 | — | |
| Screen title | 18 | 700 | — | |
| Review note text | 18 | 400 | 1.7 | ← 17 |
| Book title in a row | 15 | 700 | — | |
| Note body | 15 | 400 | 1.6 | ← 14 |
| Input text | 15 | 400 | 1.6 | |
| Button label | 15 | 500 | — | ← 14 |
| Source line, links | 13 | 400 | — | |
| Tab label | 13 | 400 / 700 active | — | |
| Metadata, ids, timestamps | 13 | 400 | — | ← 12.5 |

**Every size scales with Dynamic Type.** Define the scale once in `Typography` against a text style and let it move with the reader's setting — never `.system(size:)` with a fixed number. Layouts must survive the accessibility sizes without clipping, and note bodies wrap rather than truncate.

**Chrome stops growing at `xLarge`; content never stops.** `Typography.chromeCeiling` and the `chromeTypeSize()` modifier. It goes on the tab bar, `ScreenHeader`, review's foot, **the map's nodes and its foot, and the capture bar's two marker buttons** — and on nothing else. Everything that is the reading — every note body, quote, source line, thread, book title and field — is uncapped.

The last three were added in phase 11, all three found by looking at one screenshot at the largest accessibility size, and all three are the same argument the first three were:

- **A map node is a marker, not prose.** `GraphLayout` is told how much room each label needs in *characters* — mono makes that an exact ratio — so type that keeps growing inside a box that doesn't turns the whole library into a pile of overlapping words. At AX5 it was illegible.
- **The map's foot previews what you tapped**, and uncapped it took roughly three quarters of the screen, leaving the graph a strip. A panel that previews a thing cannot be bigger than the thing. The note itself is read by tapping `→ open note`, on a surface with no ceiling.
- **`[+]` and `[●]` are 48pt boxes** carrying one marker each. At AX5 the save button rendered as `…` and the record button burst its own brackets. **A marker truncated to an ellipsis has stopped being a marker.** The field between them is uncapped, which is the half that matters.

The rule is about what the text is *for*. A note is what the reader came to read and gets every point it asks for. A signpost that fills the room it points out of is worse at its job, not better: at `accessibility-extra-extra-extra-large` the four tab labels wrapped through each other, the stream's header came apart into eleven lines, and the ten-cell `[████░░░░░░]` progress bar wrapped onto two — a bar that has stopped being a bar. **This is the only ceiling in the app.** Anywhere else, `relativeTo:` is the whole story.

Long-form text (note bodies, review cards) sets `text-wrap: pretty` — in SwiftUI, balance line breaking and never truncate a note body mid-thought.

## Shape and space

- **Radius 4pt on interactive elements only** — buttons, inputs, chips. Everything else is square. Never a pill, never a circle, never an iOS-style 26pt card corner.
- **No shadows at any elevation.** Separation is a 1px `hairline` or a shift to `surfaceSoft`. Nothing else.
- **8pt spacing base**, with 4 / 12 / 16 / 24 / 32 steps.
- **20pt horizontal screen padding** throughout. Rows are 12–16pt vertical.
- **The bottom safe area, from the system**, not a number. The root ignores the container safe area at the *top* only; the tab bar used to carry a hardcoded 26pt to put back what ignoring the bottom took away, which is wrong on any device with a different indicator and on every device without one. It is also what lets the capture bar clear the indicator by itself on the one screen that hides the tab bar.

## Glyphs

ASCII markers replace icons entirely. Defined as named cases in `Design/Glyphs.swift` — never write the literal in a view.

| Glyph | Meaning |
|---|---|
| `[+]` | Book being read · add · save |
| `[x]` | Book finished · empty state |
| `[-]` | Book queued |
| `[~]` | Stream tab |
| `[=]` | Books tab |
| `[◇]` | Map tab |
| `[↻]` | Review tab · transcribing · shuffle |
| `[q]` | Quote note |
| `[t]` | Thought note |
| `[v]` | Voice note |
| `[s]` | Scanned note |
| `[●]` | Record — the dot is `danger`, the brackets are `ink` |
| `●` | The bare recording dot, beside the elapsed timer. `danger` |
| `■` | Stop |
| `▼` | A field that opens a list — the capture sheet's book picker |
| `[*]` `[ ]` | Starred / not starred |
| `→` `←` | Connection, navigation |
| `▁▂▃▄▅▆▇` | Recording waveform |
| `█` `░` | Progress bar fill and track |

Note ids render as `n.` + zero-padded number: `n.05`, `n.11`.

All chrome is lowercase — tab labels, the wordmark, screen titles, placeholders (`add a thought…`). `books`, not `Books`.

---

## Components

### Header — one per screen

**The wordmark appears on stream only.** Every other screen gets a single header carrying its own name and count. Never stack a wordmark row above a title row — that was the prototype's arrangement and it wasted ~50pt on every screen restating what the tab bar already says.

- **Stream** — padding `54 / 20 / 12`, wordmark `marginalia` at 16/700 `ink`, then ` · stream` at 13 `textAsh`. On the right, `search` and `settings` as link buttons.
- **Everything else** — padding `54 / 20 / 12`, the screen name at 18/700 `ink`, with any count right-aligned at 13 `textAsh`.

A `hairline` beneath, always.

**The stream's header is the only one that carries actions**, and it carries exactly two. Search and settings are screens with no tab — there is no fifth tab to give them and there will not be one — so they hang off the screen that is the app's home. Link buttons, like every other action in the app that isn't the one thing the screen is for. Both push a screen with `← stream` and both keep the tab bar: a screen, not a question.

### Tab bar

**Four** items — `[~] stream` · `[=] books` · `[◇] map` · `[↻] review` — each `flex: 1`, minimum height 52. The container has a `hairline` on top and 26pt bottom padding.

The active tab is marked by a **2pt `ink` border on its top edge, offset up 1pt** so it overlaps the container's hairline — the indicator sits above the tab, not below it. Active label is 700 `ink`; inactive is 400 `textMute`.

### The margin

The device that carries the app's name. Stream rows and book-detail notes place the id in a **48pt leading column with a `hairline` down its trailing edge**, so the column reads as an actual margin and the id annotates the text beside it.

```
n.11 │ [v] voice · 2 min ago
     │ Attention is a finite budget and
     │ switching costs are paid in
     │ comprehension.
     │ Thinking, Fast and Slow · p.214
─────────────────────────────────────
n.09 │ [q] quote · #stoicism
     │ ┃ "Confine thyself to
     │ ┃  the present."
     │ Meditations · p.47
```

The id sits at 13 `textAsh`, nudged down 2pt onto the first text baseline. The rule runs the full height of the row, meeting the row divider at both ends. The column widens under larger Dynamic Type sizes so the id never clips.

**And it folds at the accessibility sizes.** Past `isAccessibilitySize` the column and its rule go, and the id sits on its own line above the note with the full width under it — which is where the review card has always put it. This is the one conditional in the margin rule and it is not a softening of it: the column is a `@ScaledMetric` 48, so at `accessibility-extra-extra-extra-large` it is 110pt of a 393pt screen and the note it annotates gets about five characters a line. The margin is the identity at every size somebody reads at by choice; at the sizes somebody reads at by necessity, the note has to win. **No vertical hairline in the folded form** — a rule down the edge of a full-width row is a border, and this system doesn't have any.

The review card does **not** use the margin — it's centered and open by design.

### Tag chip

Padding `8 × 12`, minimum height 36, radius 4, 13pt.

- Selected — fill `ink`, text `onInk`, border `ink`, weight 500
- Unselected — fill `canvas`, text `textMute`, border `hairline`, weight 400

### Note row (stream)

The margin column plus a content column. Padding `12 × 20`, `hairline` beneath.

- Margin — id at 13 `textAsh`, with the rule as described above
- Metadata — type label and relative time, 13 `textAsh`
- Body — 15/1.6 `textBody`, or the quote rule below if the note is a quote
- Source — book · page · tag, 13 `textMute`, tappable to open the book. Connections (`→ n.09`) follow on the same line, underlined at 2pt offset. **The title is tappable and not underlined** — the connections carry the rule, and a second one under every title would put an underline on most rows in the app. Both are links inside one `AttributedString` rather than buttons, because the line has to stay one wrapping paragraph

### Quote rule

Quotes are marked by a **2pt `ink` rule on the leading edge** — the printer's convention for quoted matter, and what you'd actually draw beside a passage in a book. **No fill, no radius, no block.**

Text is 15/1.6 in **`ink`** (not `textBody`), indented 12pt from the rule, with 8pt of clear space above and below. The color difference from a thought body is what keeps the two distinguishable now that the fill is gone.

**No quote marks.** This paragraph asked for curly quotes for three phases and no surface ever drew them — `docs/issues.md` §18. Resolved in favour of the app: the printer's convention is a rule *or* quote marks, never both, and the rule is already here doing that job. `" "` would also be the closest thing to a dingbat the system carries, in an app that has ruled those out everywhere else.

The prototype used a `surfaceSoft` filled block here. That was the one element borrowed from messaging UI rather than print, and it competed with the page in dark mode. `surfaceSoft` remains in use for inputs and pressed states.

**A scan wears the rule too.** `[s] scan` is a passage read off a printed page — somebody else's words, exactly like a typed quote — so it's drawn the same way, everywhere the note appears. Its *metadata* still says `[s] scan`, because how a note was captured is a fact about the note. `NoteKind.isPassage` is the test; `kind == .quote` is not.

### Date group header

Padding `16 / 20 / 6`, 13 `textAsh`. Reads `today · wed aug 13`, `yesterday`, `earlier`.

### Book row

A button, two lines, padding `14 × 20`, `hairline` beneath, pressed fill `surfaceSoft`.

```
[+]  Thinking, Fast and Slow              [4]
     Daniel Kahneman · reading
```

Line one: status marker 13 `textMute` · title 15/700 `ink`, truncating · note count `[4]` at 13 `textAsh`.
Line two: indented 34pt to align under the title — author 13 `textMute`, then ` · ` and status at 13 `textAsh`.

### Book detail header

The one header on the screen, carrying more than a name. Same `54 / 20 / 12` padding and the same `hairline` beneath.

```
← books
Thinking, Fast and Slow                    [10]
Daniel Kahneman · reading
[████░░░░░░] p.214 / 499           edit  delete
```

- `← books` at 13 `textMute`, above the title, minimum 30pt tall. The only `←` in the app.
- Title 18/700 `ink`, wrapping rather than truncating; note count right-aligned at 13 `textAsh`.
- `author · status` at 13 `textMute`, closing up when the author is unknown.
- **No progress bar.** `author · status · 499pp` is the whole byline — the length of the book, not how far in the reader is. `docs/decisions.md` §17 says why the second one went. The `pp` closes up when the count is unknown, like the author does. `edit` and `delete` are link buttons, right-aligned, and **both absent on the Inbox** — editing it is one way to end up with two Inboxes and deleting it is the other.
- **`delete` is a link like any other, not a red button.** `danger` belongs to the confirmation it opens; a colored word in the header would be the app colour-coding, which this system doesn't do.

Rows beneath use the margin, minus the book title on the source line — it's already at the top of the screen.

### Pinned action bar

Each tab's create action sits at the foot of the screen, above the tab bar: the stream's capture bar, `[+] add book` on the library, `[+] add note` on book detail. A `hairline` on top, `12 × 20` padding, and a primary button spanning the width.

The parallel is the point — the thing you came to the tab to do is always in the same place, one thumb away.

### Capture bar

Fixed at the foot of the stream. Padding `12 × 20`, `hairline` on top, 8pt gaps.

**Focused, it grows one line and the tab bar goes.** The line is `→ full note`, a link under the input, and tapping it opens the capture sheet with whatever has been typed already in it — the book, the page and the tags are that sheet's job, on a screen with room for them. Unfocused the bar is exactly what it always was, one line and two buttons: **the fast path is not allowed to get slower.**

A `book · Inbox ▼` picker lived here for a day and came out. It was 40pt rows in a 240pt box above the keyboard, and its closed state answered a question the reader had never been asked. `docs/decisions.md` §18.

**Everything above the bar is the way out of the field.** While the input has focus a transparent scrim covers the header, the chips and the feed, and takes the first tap — the row underneath doesn't fire. Dragging the feed dismisses too, interactively, so a half-drag comes back. The scrim is `.accessibilityHidden`, because VoiceOver moves through the tree rather than by hit test and would otherwise be stranded on it.

**The tab bar is removed while the field has focus.** Content, capture bar and tab bar are one stack, so the keyboard lifts all three and the tab bar ends up stranded between the capture bar and the keys. Nothing on a tab bar is reachable with a keyboard up, so the signpost goes rather than the tool.

**There is always a way out of the field.** Tapping the feed clears focus and drags dismiss the keyboard interactively. Neither throws the draft away — this is "get out", not "give up".

- **Input** — flexible, padding `12 × 14`, fill `surfaceSoft`, `hairline` border, radius 4, 15pt, with a block cursor `▊`. On focus the fill goes to `canvas` and the border to `ink`.
- **Save `[+]`** — 48pt wide, fill `ink`, radius 4, text `onInk`. Fill becomes `disabled` when the field is empty.
- **Record `[●]`** — 48pt wide, fill `canvas`, `hairline` border, the dot in `danger`.

**Recording** replaces the whole row: a live waveform (18 bars, 15pt, 2pt letter spacing) fills the width, then the elapsed timer at 13 `textMute` behind a `danger` dot, then `cancel` as a plain `textMute` link, then a `■ stop` button — padding `10 × 16`, fill `ink`, radius 4, 13/500. **`cancel` is not optional furniture**: without it the only way out of a recording begun by accident was to finish it and delete the note.

**Transcribing** replaces it again: `[↻] transcribing…` centered, padding `22 × 20`, 15pt `textMute`.

The waveform redraws every 200ms from live input amplitude. In the full capture sheet it runs 22 bars instead of 18.

### Segmented control (capture type)

Each segment `flex: 1`, minimum height 44, radius 4, 13/500. Selected is filled `ink` / `onInk` with an `ink` border; unselected is `canvas` / `textMute` with a `hairline` border. Labels carry their glyph: `[q] quote`, `[t] thought`, `[v] voice`, `[s] scan`.

**Three segments fit a phone, not four**, so since phase 9 the type selector is **two rows of two** — `[q] quote` · `[t] thought` over `[v] voice` · `[s] scan`. A fourth segment at 14pt mono clips its own label at the default text size, and shrinking the type to fit is the thing this system never does. `SegmentedRow` takes a `perRow`; only the capture type passes one, and the book form's status and settings' appearance stay single rows of three.

### Scan panel (capture sheet)

The `[s] scan` type waits in the same 150pt box the recording states use, with one bordered `[s] scan a page` button in it — capture happens through a camera, and what comes back has to be seen before it's a note. Once there's a passage the box gives way to `[s] scanned · edit before saving` over the body field, with `scan more` as a link on the right for a passage that runs over a page turn.

### Text scanner

Full screen, with the app's own chrome over the viewfinder — the camera gets no system navigation bar, the same as the barcode. Under a `hairline`: what's been tapped so far, drawn with the **quote rule** in a fixed 150pt box that scrolls rather than grows, then `[+] use it` (primary, disabled until something is tapped) over `[x] cancel` (secondary). The box is fixed so the buttons don't move under a thumb while the other hand is holding a book open.

Where there's no camera — a simulator, a Mac — the viewfinder is replaced by `[x] no camera here — type the passage in as a quote instead`, and `use it` is not drawn at all: on that machine nothing could ever enable it.

### Book form (add / edit)

Header (`add book` or `edit book`, `[x]` to close) over one form. **The form is the screen; search and the barcode are two ways to fill it** — which is what keeps manual entry always available rather than buried behind a failure.

- Find a title, then `search` and `[s] scan isbn` as two secondary buttons splitting the row.
- Results expand inline beneath, drawn with the app's own rows: title 15/700 `ink`, then `author · 499pp` at 13 `textMute`. A `hairline` between, a `hairline` border around, radius 4.
- A `hairline` separates finding a book from typing one in: `title`, `author`, `pages`, then the status segments. **`pages` spans the row** — there is no `on p.` beside it any more, and `docs/decisions.md` §17 says why.
- The form fills the sheet so the save button sits where `save note` does.

A result **fills the fields** rather than saving straight through, and a failed lookup is a sentence under the buttons — never an alert.

### Capture sheet

Header (`new note`, `[x]` to close) over a form: type selector, book picker, body, then page and tags side by side, then `save note`.

- **The body field takes whatever height is left**, so the sheet reads as full rather than half empty. It scrolls instead once Dynamic Type needs the room. The prototype's fixed 150px was drawn for a browser window.
- **The recording box stays 150** in all three of its states, so the sheet doesn't resize under the thumb between them, and `save note` sits in the same place whichever type is selected.
- **The book picker opens inline** — the library, drawn with the app's own rows, expanding beneath the field. A wheel or a menu would be the one piece of iOS chrome in the app. Rows are 44pt minimum, like every other target in the app.
- **The Inbox is `— no book —`, the first row, and not a book in the list.** It is a real `Book` on the books screen — that's what keeps unfiled captures visible — but here it is the absence of an answer, so the closed field reads `book · none`. Offering it both ways gave a note two indistinguishable routes into the same drawer.
- The sheet itself is square (`presentationCornerRadius(0)`) with no grabber. Rule 4 applies to the sheet as much as to a card.

### Buttons

| | Fill | Border | Text | Pressed |
|---|---|---|---|---|
| **Primary** | `ink` | none | `onInk` | `inkDeep` |
| **Danger** | `danger` | none | `onInk` | — |
| **Secondary** | `canvas` | `hairline` | `ink` | `surfaceSoft` |
| **Link** | none | none | `textMute`, underlined at 2pt offset | — |

Primary is minimum height 48 at 16/500. Secondary is 10pt vertical at 14/500. Disabled primary fills `disabled` and stops responding — it never dims to 50% opacity.

**Danger is primary in the one saturated color the app has, and it appears in exactly one place: the button that carries out a confirmation.** It is never the button that *offers* one — see `ConfirmSheet` below.

### Progress bar

`[███░░░░░░░]` — ten cells, `█` filled and `░` empty, wrapped in literal brackets. 15pt `textMute`, 1pt letter spacing.

**Review's position in the day's set is the only thing that draws it.** Book detail used to, against `Book.currentPage`; §17 in `docs/decisions.md` records why that went. The difference is that the app knows which card you are on and never knew which page you were on.

### Empty state

Padding `24 × 20`, 15pt `textAsh`, prefixed with `[x]`: `[x] no notes yet — capture the first one`.

### Map — the overview

**The tab's top level is a summary, not a drawing.** `docs/decisions.md` §20 has the reasoning: a node labelled `n.07` is an opaque handle, so a canvas of forty-six of them is a picture nobody can read. The overview says what the reader has been thinking about, in words, in a list — which is also the only form of this screen that Dynamic Type and VoiceOver work on.

Three sections, in this order, down one scroll.

```
 map                                          [46]
 46 notes · 7 books · 12 themes
──────────────────────────────────────────────────
  #attention                    11 notes · 3 books
  ▇▇▇▇▇▇▇▇▇▇▇▇
  ▌the cost of a distraction is not the
  ▌minute it takes                           n.18

  error · systems · blame        7 notes · 2 books
  ▇▇▇▇▇▇▇
  ▌human error is system error               n.04

  quality · noticing             5 notes · 2 books
  ▇▇▇▇▇
   a thought — no rule, textBody             n.30
──────────────────────────────────────────────────
 crossings                                     [6]
  n.18  the cost of a distraction is not the
        minute it takes
        — Thinking, Fast and Slow
   │
  n.02  an affordance is a relationship,
        not a property
        — The Design of Everyday Things
──────────────────────────────────────────────────
 loose                                         [8]
  n.11  the map is not the territory
  n.24  a deadline is a kind of attention
                                    and 6 more
```

- **One header, and it always says `map`.** The bracketed count on the right is notes in the library. Under it, one orientation line at 13 `textMute` in the header's caption slot: `46 notes · 7 books · 12 themes`. That line is the whole of the "library at a glance" idea — a quotes-versus-thoughts bar and a most-thought-with ranking were both cut, because a counter is not a takeaway (§20).
- **Section heads reuse the stream's date-group header**, and the counts reuse `Glyphs.count`. Nothing new is introduced for this screen.

#### Theme row

- **A section shows at most eight rows**, then a plain line: `and 12 more`. It states a fact rather than offering a door — a summary that ran to four hundred rows would have stopped being one, and there is nowhere for a link to lead that search and the stream don't serve better.
- **A theme has no marker.** `[~]` is already both the Inbox status and the stream tab, and a theme has no status to report. Adding a fifteenth bracket-glyph for it would be inventing vocabulary to say nothing.
- **A theme may have no name, and then it has no heading** — the counts stay right and the exemplar leads. This is common and it is not a failure state: on the seed library three of seven themes are unnamed, and they read better than the weakly-named ones, because `Care and Quality are internal and external aspects of the same thing` says more than `mechanism` does. `ThemeName` returns nothing where the theme's notes share no word, because naming an incoherent group is the app asserting something it does not know. The first run of `ThemeDumpTests` named one `aspects · attention · automatically`: three words beginning with `a`, which is not a coincidence but the signature of the failure — with no word shared every candidate ties on weight and the alphabetical tie-break returns the first three words in the group.
- **The name is extracted from the notes and never comes from a tag** — `error · system`, `human error · system design`. Set at 15/500 `ink`, the same as a book title. Tags named themes for one afternoon and the rule was pulled: the grouping never needed them, but six of seven seed themes came out tag-named and the screen read as though tagging were the mechanism. Nothing here depends on anything the reader typed. `docs/decisions.md` §20.
- **Noun phrases, not keywords.** Single words gave `error · systems · blame`, which reads as machine output. `NounPhrases` offers phrases and bare nouns; a phrase wins ties. No two parts of a name may share a word, or it comes out `human error · system error · error messages`.
- **There is no weight bar.** One was drawn — first as ragged `▇`, then as `ASCIIProgressBar` — and both came out. It encoded theme size against the largest theme, which the sort order and the note count each already carry; and a progress bar means *how far through something you are*, which a theme is not. The largest theme always filled every cell, reading as 100% of nothing.
- **The counts sit right: `11 notes · 3 books`** at 13 `textAsh`. Books-spanned is the fact worth carrying here, because an idea that appears in three books is the thing this app exists to notice.
- **The exemplar wears the rule and no quote marks.** The note at the centre of the theme, two lines — **five at the accessibility sizes**, because the exemplar is the evidence and at two lines it truncated to `Slips and mistakes are…`, which is no evidence at all. The name, the counts and the bar are chrome and stop growing; this is content and does not. Its id trails at 13 `textAsh`. A passage exemplar — `.quote` or `.scan`, per `NoteKind.isPassage` — gets the 2pt `ink` rule and `ink` text; a thought exemplar gets neither and `textBody`. Identical to how bodies render everywhere else in the app, and **never with `“ ”`**.
- **The exemplar is evidence, not decoration.** It is what lets a reader judge a grouping the app got wrong, which matters more here than anywhere because the themes ride on an embedder nobody has verified.
- Tapping a theme opens its notes as ordinary `NoteRow`s, with `[◇] graph` one tap further.

#### Crossing

A **crossing** is one connection that spans two books — the most concrete form of what this app is for, and what the reader in §19 assumed the map was showing all along.

- Two note fragments, each `n.18` at 13 `textAsh` in the margin position, two lines of the note, then the book behind an em dash at 13 `textMute`.
- **Joined by `│`**, box-drawing, one character, in `hairline`. Not a drawn edge and not a second line weight — the same subtraction logic §19 settled: this screen adds no vocabulary.
- Strongest first, and **no note appears twice**. This is a display rule, not a claim about the data: the first run of this screen put `n.18` in three consecutive rows with its full text repeated each time, which is the hub behaviour phase 6 recorded arriving in the UI. Every one of those connections still exists, on the graph and on the note; the list shows the strongest crossing each note has, so eight rows are eight ideas.
- Tapping either half opens that note.
- **A long press offers `disconnect`.** This is the row that retires the app's only hidden destructive gesture — holding a line on the canvas — and puts deletion in the long-press menu every other listed row in the app already uses. It goes through `Eraser.suppress`, the app's own `ConfirmSheet`, and a `LinkWriter.relink` after, exactly as the canvas did.

#### Loose

Notes in no theme, connected to nothing. `n.11` and one line of the note, capped, with `and 6 more` at 13 `textAsh` when there are more than fit.

**It is not a scolding and not a to-do list.** It is there because a summary that showed only the connections the app *found*, while hiding the notes it couldn't place, would be dishonest in an app whose docs are this careful about their own failures — eight of the forty seed notes are isolated. A note whose vector was made by a model that isn't the one loaded today is loose too, and says so rather than being silently dropped.

### Map — the graph

**The canvas survives at the two sizes where a graph is legible**: one theme's notes, and two hops from one note. One book on its own still opens from a hub. **The whole-library view and the book-hub collapse are gone** — §20 — and with them `collapseAbove` and `-mapCollapse`. A knowledge graph in a system with no color and no images; the constraint is the point, and this should read as a terminal drew it, not as a data-viz library did.

```
     n.01
        ╲          n.09
         ╲        ╱
          ██n.07██
         ╱        ╲
        ╱          ╲
     n.03          n.11

   [Meditations]
```

- **Nodes are the note id itself**, set in mono at 13 — `n.07`, not a dot with a label beside it. There are no circles in this graph.
- **Books are hub nodes**, bracketed and bolder: `[Meditations]` at 13/700. That's the only difference between the two node types — no color, no shape change.
- **A hub is the book's first word, not its title.** `[Meditations]` is the whole of one title and none of `Zen and the Art of Motorcycle Maintenance`; forty characters of bold mono lie across half the graph and cover the notes the hub is meant to be gathering. A leading article is dropped, because `[The]` names nothing. So: `[Thinking]`, `[Zen]`, `[Design]`, `[Beginning]`, `[Inbox]`. The panel at the foot carries the whole title when a hub is selected, and that's where the disambiguation lives if two books ever start with the same word.
- **A note's line to its own book is drawn like any other line.** There is one line weight in this system. It isn't a connection anybody suggested, though, so it can't be held down on and deleted, and it doesn't count toward the weight of either end.
- **Edges are `hairline`**, 1px, at the same 12% as every divider in the app.
- **The reader can subtract the book lines.** A chip row under the header — `all lines` / `connections only`, the same `TagChip` the library and the stream use — stops the attachments being drawn. **It still earns its place in a theme's graph**, because a theme spans books and so still carries attachments. **It is a filter and not a second line style**, which is why the rule above survives it intact: nothing is dashed, nothing is lightened, nothing gains a weight. Lines are drawn or they are not.
- **The filtering happens at the stroke, not in the graph.** `GraphLayout` is told about every edge either way, so **not one node moves when the filter changes** — verified by pixel-comparing the two states. Removing edges from the graph would re-key the layout task and reshuffle the screen, and it would also stop the hubs gathering their clusters, since the attachment is the force that does the gathering.
- **Selection inverts.** The node fills `ink` with its text in `onInk`, and its edges go to full-opacity `ink` while every other edge stays at hairline. That is the entire interaction vocabulary — no highlight color, no glow, no shadow.
- **Connection count shows as weight** — 400 → 500 → 700 — never as node size. Varying node size would introduce a visual dimension the rest of the app doesn't have.
- **The foot is always there, and it is always the same height.** A selected node previews its note in it — metadata, three lines of the note, the source, then two link buttons: `→ open note` and `[◇] connections`, which narrows the map to two hops around it. A hub previews the book — `[+] Meditations`, then `author · status · 12 notes` — and offers `→ open book` and `[◇] only this book`. Link buttons, never filled ones, like every other action row in the app.
- **With nothing selected it says what the screen does**: `tap a note to preview it, again to open it` over `hold a line to disconnect two notes`. This is the most gestural screen in the app and it was the only one that never said so.
- **The constant height is not cosmetic.** The panel used to appear and disappear, which changed the canvas's height, which changed the aspect ratio `GraphLayout` is told, which re-ran the entire force-directed layout — so **tapping a node reshuffled the whole graph**, and two notes with different-length previews reshuffled it differently. Reserve the room and none of that happens. `docs/issues.md` §5 in the phase 11 list.

Nodes need a 44pt minimum hit target even though the drawn text is smaller.

Layout is force-directed and cached; it only recomputes when the graph changes.

**The header always says `map`.** A narrowed view says what it is on a line under the title — `two hops from n.18`, `#attention`, `Meditations` — and carries `← map` back. The count on the right is nodes on screen, not notes in the library.

### Review card

Full screen, one note, **vertical** paging. Header shows `daily review` at 18/700 with the position `3 of 8` at 13 `textAsh` on the right, clamped so the closing card reads `8 of 8` rather than `9 of 8`.

The note is vertically centered with 16pt gaps: metadata at 13 `textAsh`, the text at 18/1.7 `ink` (a quote wears the rule and no quote marks — see *Quote rule*), the source at 13 `textMute` behind an em dash, then linked notes, then the thread if the note has one. It scrolls only once a long note plus its thread outgrows the screen — centering inside a scroll view is a `minHeight` frame, not a pair of `Spacer`s, which collapse there.

**The card does not use the margin.** It's centered and open by design; the margin belongs to screens where a row is one of many.

The action row sits below the note as link buttons, never filled ones:

```
[+] add a thought   [ ] star
→ open book   share
[◇] connections   → link
```

**Rows of two, never a row of four.** Four labels are ~320pt of 13pt mono before gaps, which overflows a phone at the default text size and is hopeless above it — the same arithmetic that gives the capture sheet three segments instead of four. Six actions is three rows by the same arithmetic. A starred note reads `[*] starred`; there is no other state change. `share` is bare rather than glyphed: every marker here is bracket-plus-character, and no bracketed character means "share" without becoming a picture.

`[◇] connections` opens the map two hops out from this note — the same view the map's own panel offers, from the screen where you're actually reading the note. `→ link` opens the note picker below.

### Note picker

The one place a reader makes a connection. A full-height sheet — `link n.04` and `[x]` over one field and the library, newest first.

- Rows are compact: `n.40 · [v] voice · 3 mins ago` over three lines of the note and its source. **No margin column** — this is a list of things to choose, not a list of things to read.
- The note itself and everything it's already joined to are left off the list. A pair the reader once *disconnected* stays on it: they're allowed to change their mind.
- An empty field lists the whole library rather than nothing. It's a picker first and a search second.
- **Nothing here says the link will look different afterwards, because it won't.** A hand-made connection is drawn exactly like one the app found.

The foot carries the progress bar and the hint `↑ swipe up for next`. The hint goes on the closing card, where there is nothing left to swipe to.

**The closing card** ends the set — `that's the set` at 18/700 over a line of `textBody`, then `[↻] keep going` as a secondary button, which extends past the day's eight rather than starting the same set over. When there's nothing left to show it says so and drops the button.

### Thread of follow-ups

A note's later thoughts, under the note they answer. Shown **everywhere the note is shown** — stream, book detail, and the review card — or `[+] add a thought` would appear to do nothing.

```
n.04 │ [q] quote · jul 09
     │ ┃ "Human error usually is a result of
     │ ┃  poor design."
     │ The Design of Everyday Things · p.68
     │ ╷ aug 05
     │ ╵ Held up for a month now, except where
     │   the design is fine and the person was
     │   tired.
```

The same device as the quote rule and deliberately the quieter half of it: a 1px `hairline` on the leading edge where a quote gets 2pt of `ink`. A follow-up is subordinate to the note it grew out of, and the weight of the rule is what says so.

Indented 12pt from the rule, 8pt of clear space above, 12pt between two follow-ups. The timestamp sits at 13 `textAsh` over the text at 15/1.6 `textBody`. **Oldest first** — a thread reads forward, because the answer comes after the thing it answers.

### Search

`← stream` over `search`, the count of what was found on the right, then one field and the results.

```
← stream
search                                     [7]
──────────────────────────────────────────────
[ notes, books, authors, #tags…             ]
──────────────────────────────────────────────
Thinking, Fast and Slow
n.31 │ [t] thought · 5 days ago
     │ …
```

- The field is an `InputField` at `20 / 12`, focused on arrival — a screen whose whole purpose is one field opens with the keyboard up. A `hairline` under it.
- **Results are note rows grouped by book**, under the same `GroupHeader` the stream groups dates with. The rows drop the book from their source line, because the header above already says it — the rule book detail follows.
- A row is a button: tapping it opens the note in the stream. That's the only difference from a stream row, and it's the reason search is the one list in the app whose rows are tappable as a whole.
- Nothing typed says `[x] type to search every note, thread, book and tag`; nothing found names what was asked for.

### Settings

`← stream` over `settings`, then four groups, each behind a `hairline`, each titled at 13 `textAsh` like a date header: **daily review**, **appearance**, **library**, **about**.

- **A setting is on when its box is filled**: `[*] one note a day`, `[ ]` when it's off. There is no `Toggle` anywhere in this app — it is a green pill, and it would be the only pill in the design system.
- **The time opens inline**, `at 8:00 am ▼`, expanding a list of half-hours in a 200pt box scrolled to the current setting. Not a `DatePicker`: a wheel is the same piece of iOS chrome the capture sheet's book picker was written to avoid.
- **Appearance is a `SegmentedRow`** — `system` · `light` · `dark`, three segments, which is what fits.
- `export as markdown` and `rebuild connections` are secondary buttons, each with a sentence under it at 13 `textMute` saying what it does.
- **About is prose, not a table.** Version, what stays on the phone, and the two credits. Lowercase, like every other sentence the app says about itself.

### Confirmation sheet

The app asking whether it should really do the irreversible thing. Half-height sheet, square corners, `canvas` behind it, no drag indicator — the same presentation as every other sheet in the app, at `.medium` rather than full.

```
delete Meditations?

8 notes written from it go with it, and
their threads go with them. this can't
be undone.


          [x] delete                     ← danger fill
          cancel                         ← secondary
```

- Title at 18/700 `ink`, phrased as the question. Consequence at 15/1.6 `textBody`, saying **what goes with it** — that's the whole reason for asking.
- The destructive button is first, filled `danger`, and says what it will do: `[x] delete`, never `ok` or `yes`. `cancel` is secondary and unmarked, because backing out isn't an action.
- Buttons sit at the foot of the sheet, one thumb away, with the question at the top — the same arrangement as a pinned action bar.

**Its own sheet, never `confirmationDialog`.** A system dialog arrives in San Francisco with pill buttons and a 26pt radius: three rules broken in one presentation, and the only place in the app that would look like iOS.

### Deleting a row

A note or a follow-up is deleted by **long-pressing the row**, which opens the confirmation above. There is no permanent `delete` on a stream row — there is nowhere on a row that dense to put one without it competing with the note itself.

The same long press carries `[◇] connections`, which opens the map two hops out from that note. It is there for the same reason `delete` is: a row this dense has no room for a second permanent word, and the gesture is already learned.

**A row can be deleted where it is listed, not where it is being read.** Stream rows and book-detail rows carry the gesture; the review card does not, because review is a reading surface and destroying the card under your thumb is not worth being able to do by accident.

---

## Checking your work

After any UI change, screenshot the simulator in **both** appearances and look at the images:

```bash
xcrun simctl ui booted appearance dark      # then light
xcrun simctl io booted screenshot /tmp/marginalia.png
```

Compare against `docs/prototype/Marginalia.dc.html`, opened in a browser. Dark mode breakage is invisible when reading code and immediately obvious in a screenshot.

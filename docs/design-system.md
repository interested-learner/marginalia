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

**Every size scales with Dynamic Type.** Define the scale once in `Typography` against a text style and let it move with the reader's setting — never `.system(size:)` with a fixed number. Layouts must survive the accessibility sizes without clipping; the margin column widens with the id, and note bodies wrap rather than truncate.

Long-form text (note bodies, review cards) sets `text-wrap: pretty` — in SwiftUI, balance line breaking and never truncate a note body mid-thought.

## Shape and space

- **Radius 4pt on interactive elements only** — buttons, inputs, chips. Everything else is square. Never a pill, never a circle, never an iOS-style 26pt card corner.
- **No shadows at any elevation.** Separation is a 1px `hairline` or a shift to `surfaceSoft`. Nothing else.
- **8pt spacing base**, with 4 / 12 / 16 / 24 / 32 steps.
- **20pt horizontal screen padding** throughout. Rows are 12–16pt vertical.
- **26pt bottom padding** on the tab bar, clearing the home indicator.

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

Text is 15/1.6 in **`ink`** (not `textBody`), wrapped in curly quotes `" "`, indented 12pt from the rule, with 8pt of clear space above and below. The color difference from a thought body is what keeps the two distinguishable now that the fill is gone.

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
- Progress bar at 15 `textMute` with `p.214 / 499` at 13 `textAsh`, both omitted when the page count is unknown. `edit` and `delete` are link buttons, right-aligned, and **both absent on the Inbox** — editing it is one way to end up with two Inboxes and deleting it is the other.
- **`delete` is a link like any other, not a red button.** `danger` belongs to the confirmation it opens; a colored word in the header would be the app colour-coding, which this system doesn't do.

Rows beneath use the margin, minus the book title on the source line — it's already at the top of the screen.

### Pinned action bar

Each tab's create action sits at the foot of the screen, above the tab bar: the stream's capture bar, `[+] add book` on the library, `[+] add note` on book detail. A `hairline` on top, `12 × 20` padding, and a primary button spanning the width.

The parallel is the point — the thing you came to the tab to do is always in the same place, one thumb away.

### Capture bar

Fixed at the foot of the stream. Padding `12 × 20`, `hairline` on top, 8pt gaps.

- **Input** — flexible, padding `12 × 14`, fill `surfaceSoft`, `hairline` border, radius 4, 15pt, with a block cursor `▊`. On focus the fill goes to `canvas` and the border to `ink`.
- **Save `[+]`** — 48pt wide, fill `ink`, radius 4, text `onInk`. Fill becomes `disabled` when the field is empty.
- **Record `[●]`** — 48pt wide, fill `canvas`, `hairline` border, the dot in `danger`.

**Recording** replaces the whole row: a live waveform (18 bars, 15pt, 2pt letter spacing) fills the width, then the elapsed timer at 13 `textMute` behind a `danger` dot, then a `■ stop` button — padding `10 × 16`, fill `ink`, radius 4, 13/500.

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
- A `hairline` separates finding a book from typing one in: `title`, `author`, then `pages` (110pt) and `on p.` side by side, then the status segments.
- The form fills the sheet so the save button sits where `save note` does.

A result **fills the fields** rather than saving straight through, and a failed lookup is a sentence under the buttons — never an alert.

### Capture sheet

Header (`new note`, `[x]` to close) over a form: type selector, book picker, body, then page and tags side by side, then `save note`.

- **The body field takes whatever height is left**, so the sheet reads as full rather than half empty. It scrolls instead once Dynamic Type needs the room. The prototype's fixed 150px was drawn for a browser window.
- **The recording box stays 150** in all three of its states, so the sheet doesn't resize under the thumb between them, and `save note` sits in the same place whichever type is selected.
- **The book picker opens inline** — the library, drawn with the app's own rows, expanding beneath the field. A wheel or a menu would be the one piece of iOS chrome in the app.
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

### Empty state

Padding `24 × 20`, 15pt `textAsh`, prefixed with `[x]`: `[x] no notes yet — capture the first one`.

### Map

A knowledge graph in a system with no color and no images. The constraint is the point — this should read as a terminal drew it, not as a data-viz library did.

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
- **Selection inverts.** The node fills `ink` with its text in `onInk`, and its edges go to full-opacity `ink` while every other edge stays at hairline. That is the entire interaction vocabulary — no highlight color, no glow, no shadow.
- **Connection count shows as weight** — 400 → 500 → 700 — never as node size. Varying node size would introduce a visual dimension the rest of the app doesn't have.
- **A selected node previews its note** in a panel at the foot, above the tab bar, separated by a `hairline`. Metadata, three lines of the note, the source, then two link buttons: `→ open note` and `[◇] connections`, which narrows the map to two hops around it. A hub previews the book — `[+] Meditations`, then `author · status · 12 notes` — and offers `→ open book` and `[◇] only this book`. Link buttons, never filled ones, like every other action row in the app.

Nodes need a 44pt minimum hit target even though the drawn text is smaller.

Layout is force-directed and cached; it only recomputes when the graph changes. Above ~150 nodes the global view collapses to book hubs and expands one on tap.

**One header, and it always says `map`.** A narrowed view says what it is on a line under the title — `two hops from n.18`, `Meditations`, `books only — tap one to open it` — and carries `← map` back to the whole library. The count on the right is nodes on screen, not notes in the library.

### Review card

Full screen, one note, **vertical** paging. Header shows `daily review` at 18/700 with the position `3 of 8` at 13 `textAsh` on the right, clamped so the closing card reads `8 of 8` rather than `9 of 8`.

The note is vertically centered with 16pt gaps: metadata at 13 `textAsh`, the text at 18/1.7 `ink` (quotes wrapped in curly quotes), the source at 13 `textMute` behind an em dash, then linked notes, then the thread if the note has one. It scrolls only once a long note plus its thread outgrows the screen — centering inside a scroll view is a `minHeight` frame, not a pair of `Spacer`s, which collapse there.

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

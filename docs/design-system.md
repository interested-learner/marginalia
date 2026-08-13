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
| `■` | Stop |
| `→` `←` | Note link, navigation |
| `▁▂▃▄▅▆▇` | Recording waveform |
| `█` `░` | Progress bar fill and track |

Note ids render as `n.` + zero-padded number: `n.05`, `n.11`.

All chrome is lowercase — tab labels, the wordmark, screen titles, placeholders (`add a thought…`). `books`, not `Books`.

---

## Components

### Header — one per screen

**The wordmark appears on stream only.** Every other screen gets a single header carrying its own name and count. Never stack a wordmark row above a title row — that was the prototype's arrangement and it wasted ~50pt on every screen restating what the tab bar already says.

- **Stream** — padding `54 / 20 / 12`, wordmark `marginalia` at 16/700 `ink`, then ` · stream` at 13 `textAsh`.
- **Everything else** — padding `54 / 20 / 12`, the screen name at 18/700 `ink`, with any count right-aligned at 13 `textAsh`.

A `hairline` beneath, always.

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
- Source — book · page · tag, 13 `textMute`, tappable to open the book. Connections (`→ n.09`) follow on the same line, underlined at 2pt offset

### Quote rule

Quotes are marked by a **2pt `ink` rule on the leading edge** — the printer's convention for quoted matter, and what you'd actually draw beside a passage in a book. **No fill, no radius, no block.**

Text is 15/1.6 in **`ink`** (not `textBody`), wrapped in curly quotes `" "`, indented 12pt from the rule, with 8pt of clear space above and below. The color difference from a thought body is what keeps the two distinguishable now that the fill is gone.

The prototype used a `surfaceSoft` filled block here. That was the one element borrowed from messaging UI rather than print, and it competed with the page in dark mode. `surfaceSoft` remains in use for inputs and pressed states.

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

### Capture bar

Fixed at the foot of the stream. Padding `12 × 20`, `hairline` on top, 8pt gaps.

- **Input** — flexible, padding `12 × 14`, fill `surfaceSoft`, `hairline` border, radius 4, 15pt, with a block cursor `▊`. On focus the fill goes to `canvas` and the border to `ink`.
- **Save `[+]`** — 48pt wide, fill `ink`, radius 4, text `onInk`. Fill becomes `disabled` when the field is empty.
- **Record `[●]`** — 48pt wide, fill `canvas`, `hairline` border, the dot in `danger`.

**Recording** replaces the whole row: a live waveform (18 bars, 15pt, 2pt letter spacing) fills the width, then the elapsed timer at 13 `textMute` behind a `danger` dot, then a `■ stop` button — padding `10 × 16`, fill `ink`, radius 4, 13/500.

**Transcribing** replaces it again: `[↻] transcribing…` centered, padding `22 × 20`, 15pt `textMute`.

The waveform redraws every 200ms from live input amplitude. In the full capture sheet it runs 22 bars instead of 18.

### Segmented control (capture type)

Each segment `flex: 1`, minimum height 44, radius 4, 14/500. Selected is filled `ink` / `onInk` with an `ink` border; unselected is `canvas` / `textMute` with a `hairline` border. Labels carry their glyph: `[q] quote`, `[t] thought`, `[v] voice`, `[s] scan`.

### Buttons

| | Fill | Border | Text | Pressed |
|---|---|---|---|---|
| **Primary** | `ink` | none | `onInk` | `inkDeep` |
| **Secondary** | `canvas` | `hairline` | `ink` | `surfaceSoft` |
| **Link** | none | none | `textMute`, underlined at 2pt offset | — |

Primary is minimum height 48 at 16/500. Secondary is 10pt vertical at 14/500. Disabled primary fills `disabled` and stops responding — it never dims to 50% opacity.

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
- **Edges are `hairline`**, 1px, at the same 12% as every divider in the app.
- **Selection inverts.** The node fills `ink` with its text in `onInk`, and its edges go to full-opacity `ink` while every other edge stays at hairline. That is the entire interaction vocabulary — no highlight color, no glow, no shadow.
- **Connection count shows as weight** — 400 → 500 → 700 — never as node size. Varying node size would introduce a visual dimension the rest of the app doesn't have.
- **A selected node previews its note** in a panel at the foot, above the tab bar, separated by a `hairline`. Tappable through to the note.

Nodes need a 44pt minimum hit target even though the drawn text is smaller.

Layout is force-directed and cached; it only recomputes when the graph changes. Above ~150 nodes the global view collapses to book hubs and expands one on tap.

### Review card

Full screen, one note, vertical paging. Header shows `Daily review` at 18/700 with the position `3 of 8` at 13 `textAsh` on the right.

The note is vertically centered with 16pt gaps: metadata at 13 `textAsh`, the text at 18/1.7 `ink` (quotes wrapped in curly quotes), the source at 14 `textMute` behind an em dash, then linked notes if any.

The action row sits below the note — `✎ add a thought`, `★ star`, `→ open book`, share — as link buttons, not filled ones. A starred note fills its star; there is no other state change.

The foot carries the progress bar and the hint `↑ swipe up for next`. The final card closes the set and offers `[↻] keep going` to continue past the day's eight.

---

## Checking your work

After any UI change, screenshot the simulator in **both** appearances and look at the images:

```bash
xcrun simctl ui booted appearance dark      # then light
xcrun simctl io booted screenshot /tmp/marginalia.png
```

Compare against `docs/prototype/Marginalia.dc.html`, opened in a browser. Dark mode breakage is invisible when reading code and immediately obvious in a screenshot.

# Design system

The OpenCode system, as marginalia uses it. This is the reference to consult when building any view — the values below are lifted from the prototype's markup, not approximated.

The system's whole identity rests on restraint: **one typeface, two colors, hairlines, and no shadows.** Every rule below exists to protect that. Adding a shadow or a second color doesn't slightly weaken the design, it makes it look like a different app.

---

## Color

Light and dark are the same palette inverted. The light values are the prototype's exactly; the dark values are their counterparts, tuned so contrast ratios hold.

| Token | Light | Dark | Used for |
|---|---|---|---|
| `canvas` | `#fdfcfc` | `#201d1d` | Page background, secondary button fill |
| `surfaceSoft` | `#f8f7f7` | `#302c2c` | Quote blocks, text inputs at rest, pressed rows |
| `surfaceCard` | `#f1eeee` | `#3a3636` | Pressed state on secondary buttons |
| `ink` | `#201d1d` | `#fdfcfc` | Primary text, filled buttons, active indicators |
| `inkDeep` | `#0f0000` | `#ffffff` | Pressed state on filled buttons |
| `onInk` | `#fdfcfc` | `#201d1d` | Text on a filled surface |
| `textCharcoal` | `#302c2c` | `#ebe9e9` | Quote text inside a quote block |
| `textBody` | `#424245` | `#d8d6d6` | Note body text |
| `textMute` | `#646262` | `#9a9898` | Source lines, secondary labels, inactive tabs |
| `textAsh` | `#9a9898` | `#787676` | Note ids, timestamps, metadata, counts |
| `hairline` | `rgba(15,0,0,0.12)` | `rgba(253,252,252,0.14)` | Every divider and unfilled border |
| `disabled` | `#9a9898` | `#646262` | Filled button with nothing to do |
| `danger` | `#ff3b30` | `#ff453a` | Recording dot, destructive confirmation |

`danger` is the only saturated color in the app. Everything else is on the ink-to-paper ladder.

**These live in `Design/Theme.swift` and nowhere else.** A hex literal appearing in a view is a bug, and so is `.secondary`, `.gray`, or any other system color — those don't follow this palette in dark mode.

## Type

**JetBrains Mono** at every size and weight. No sans face, no display face, no italic. Weights: 400 regular, 500 medium, 700 bold.

| Role | Size | Weight | Line height |
|---|---|---|---|
| Wordmark | 16 | 700 | — |
| Screen title | 18 | 700 | — |
| Review note text | 17 | 400 | 1.7 |
| Book title in a row | 15 | 700 | — |
| Input text | 15 | 400 | 1.6 |
| Note body | 14 | 400 | 1.65 |
| Button label | 14 | 500 | — |
| Source line, links | 13 | 400 | — |
| Tab label | 13 | 400 / 700 active | — |
| Metadata, ids, timestamps | 12.5 | 400 | — |

Long-form text (note bodies, review cards) sets `text-wrap: pretty` — in SwiftUI, balance line breaking and never truncate a note body mid-thought.

## Shape and space

- **Radius 4pt on interactive elements only** — buttons, inputs, chips, quote blocks. Everything else is square. Never a pill, never a circle, never an iOS-style 26pt card corner.
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

Chrome is lowercase — tab labels, the wordmark, placeholders (`add a thought…`). Screen titles are sentence case: `Daily review`, `Books`.

---

## Components

### Header

Padding `54 / 20 / 12` (the top clears the status bar). Wordmark `marginalia` at 16/700 `ink`, then ` · ` and the screen name at 13 `textAsh`. A `hairline` beneath.

### Tab bar

Three items, each `flex: 1`, minimum height 52. The container has a `hairline` on top and 26pt bottom padding.

The active tab is marked by a **2pt `ink` border on its top edge, offset up 1pt** so it overlaps the container's hairline — the indicator sits above the tab, not below it. Active label is 700 `ink`; inactive is 400 `textMute`.

### Tag chip

Padding `8 × 12`, minimum height 36, radius 4, 13pt.

- Selected — fill `ink`, text `onInk`, border `ink`, weight 500
- Unselected — fill `canvas`, text `textMute`, border `hairline`, weight 400

### Note row (stream)

A two-column grid: a **48pt id gutter** and the content column. Padding `12 × 20`, `hairline` beneath.

```
n.11   [v] voice · 2 min ago
       Attention is a finite budget and switching
       costs are paid in comprehension — same as
       context switching in engineering work.
       Thinking, Fast and Slow · p.214 · #systems
```

- Gutter — id at 12.5 `textAsh`, nudged down 2pt to sit on the first text baseline
- Metadata — type label and relative time, 12.5 `textAsh`
- Body — 14/1.65 `textBody`, or a quote block if the note is a quote
- Source — book · page · tag, 13 `textMute`, tappable to open the book. Note links (`→ n.09`) follow on the same line, underlined at 2pt offset

### Quote block

Fill `surfaceSoft`, radius 4, padding `12 × 14`, text 14/1.65 `textCharcoal`, wrapped in curly quotes `" "`. This is the only visual distinction between a quote and a thought — no icons, no color.

### Date group header

Padding `16 / 20 / 6`, 12.5 `textAsh`. Reads `today · wed aug 13`, `yesterday`, `earlier`.

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

- **Input** — flexible, padding `12 × 14`, fill `surfaceSoft`, `hairline` border, radius 4, 14pt. On focus the fill goes to `canvas` and the border to `ink`.
- **Save `[+]`** — 48pt wide, fill `ink`, radius 4, text `onInk`. Fill becomes `disabled` when the field is empty.
- **Record `[●]`** — 48pt wide, fill `canvas`, `hairline` border, the dot in `danger`.

**Recording** replaces the whole row: a live waveform (18 bars, 14pt, 2pt letter spacing) fills the width, then the elapsed timer at 13 `textMute` behind a `danger` dot, then a `■ stop` button — padding `10 × 16`, fill `ink`, radius 4, 13/500.

**Transcribing** replaces it again: `[↻] transcribing…` centered, padding `22 × 20`, 14pt `textMute`.

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

`[███░░░░░░░]` — ten cells, `█` filled and `░` empty, wrapped in literal brackets. 14pt `textMute`, 1pt letter spacing.

### Empty state

Padding `24 × 20`, 14pt `textAsh`, prefixed with `[x]`: `[x] no notes yet — capture the first one`.

### Review card

Full screen, one note, vertical paging. Header shows `Daily review` at 18/700 with the position `3 of 8` at 13 `textAsh` on the right.

The note is vertically centered with 16pt gaps: metadata at 12.5 `textAsh`, the text at 17/1.7 `ink` (quotes wrapped in curly quotes), the source at 14 `textMute` behind an em dash, then linked notes if any.

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

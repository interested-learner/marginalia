#!/usr/bin/env swift

// Renders the app icon — `[m]`, the bracket marker vocabulary applied to itself.
//
// The icon is the one image in an app whose identity is the absence of images,
// which is exactly why it is a script and not a binary somebody exported once.
// It reads the same JetBrains Mono the app ships and the same two hexes
// `Design/Theme.swift` defines, so the icon cannot drift from the palette
// without this file drifting too.
//
//     swift Tools/MakeAppIcon.swift
//
// Writes three 1024×1024 PNGs and the `Contents.json` that names them into
// `Marginalia/Resources/Assets.xcassets/AppIcon.appiconset/`.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Values

/// Theme.canvas / Theme.ink, light. The dark variant is the same pair, swapped.
let canvasLight = (r: 0xFD / 255.0, g: 0xFC / 255.0, b: 0xFC / 255.0)
let inkLight = (r: 0x20 / 255.0, g: 0x1D / 255.0, b: 0x1D / 255.0)

let side = 1024.0

/// The glyph is fitted to this fraction of the icon's width rather than set at a
/// chosen point size. iOS masks the icon to a squircle, so the corners are not
/// ours to use; `[m]` sits inside the width the mask actually keeps.
let fitWidth = 0.80

/// Extra space between the brackets and the `m`, as a fraction of the font size.
///
/// **This is the number the icon was tuned on.** JetBrains Mono sets `[m]`
/// tightly enough that at home-screen size the two bracket stems and the `m`'s
/// three stems read as one five-bar smear. Opening the brackets separates the
/// marker into its parts at 40pt, which is the size that decides whether an
/// icon works.
let tracking = 0.055

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // Tools/
    .deletingLastPathComponent()   // repo root

let fontURL = root.appending(path: "Marginalia/Resources/Fonts/JetBrainsMono-Bold.ttf")
let iconSet = root.appending(path: "Marginalia/Resources/Assets.xcassets/AppIcon.appiconset")

// MARK: - The font

guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) else {
    fatalError("couldn't register \(fontURL.path) — is the repo intact?")
}

func jetBrainsMonoBold(_ size: Double) -> CTFont {
    CTFontCreateWithName("JetBrainsMono-Bold" as CFString, size, nil)
}

// MARK: - Drawing

/// One 1024×1024 icon. `background: nil` leaves it transparent, which is what
/// the tinted variant wants — the system composites its own ground under it.
func render(
    background: (r: Double, g: Double, b: Double)?,
    glyph: (r: Double, g: Double, b: Double),
    to file: URL
) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(side), height: Int(side),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("couldn't make a bitmap context") }

    if let background {
        ctx.setFillColor(CGColor(
            colorSpace: space,
            components: [background.r, background.g, background.b, 1]
        )!)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }

    let color = CGColor(
        colorSpace: space, components: [glyph.r, glyph.g, glyph.b, 1]
    )!

    // Fit `[m]` to `fitWidth` by measuring at a reference size and scaling —
    // the mono advance is linear in point size, so one measurement is enough.
    let reference = 100.0
    let referenceWidth = typeset("[m]", size: reference).bounds.width
    let size = reference * (side * fitWidth) / referenceWidth

    let line = typeset("[m]", size: size, color: color)

    // Optically centred on the ink, not on the typographic line. A line's
    // height is ascender-to-descender and `[m]` uses neither fully, so
    // centring the line would sit the marker low.
    let bounds = line.bounds
    ctx.textPosition = CGPoint(
        x: (side - bounds.width) / 2 - bounds.minX,
        y: (side - bounds.height) / 2 - bounds.minY
    )
    CTLineDraw(line.line, ctx)

    guard let image = ctx.makeImage(),
          let out = CGImageDestinationCreateWithURL(
              file as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else { fatalError("couldn't encode \(file.lastPathComponent)") }

    CGImageDestinationAddImage(out, image, nil)
    guard CGImageDestinationFinalize(out) else {
        fatalError("couldn't write \(file.path)")
    }
    print("wrote \(file.lastPathComponent)")
}

/// A typeset line and the bounding box of the ink it actually puts down.
func typeset(
    _ text: String, size: Double, color: CGColor? = nil
) -> (line: CTLine, bounds: CGRect) {
    // CoreText's own keys, not `NSAttributedString.Key` — those are AppKit's,
    // and this script links Foundation and CoreText and nothing else.
    var attributes: [CFString: Any] = [
        kCTFontAttributeName: jetBrainsMonoBold(size),
        kCTKernAttributeName: size * tracking,
    ]
    if let color { attributes[kCTForegroundColorAttributeName] = color }

    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)
    )
    // `.useOpticalBounds` is the ink, which is what centring wants — the
    // typographic bounds include the trailing kern and would push `[m]` left.
    return (line, CTLineGetBoundsWithOptions(line, .useOpticalBounds))
}

// MARK: - Run

try FileManager.default.createDirectory(
    at: iconSet, withIntermediateDirectories: true
)

// Light: ink on canvas, exactly as every screen in the app draws it.
render(
    background: canvasLight, glyph: inkLight,
    to: iconSet.appending(path: "icon-light.png")
)

// Dark: the same pair swapped, which is what `Theme` does everywhere else.
render(
    background: inkLight, glyph: canvasLight,
    to: iconSet.appending(path: "icon-dark.png")
)

// Tinted: grayscale, and **opaque**. Apple's guidance is a transparent ground
// here and iOS 26 cannot draw one — its Liquid Glass pass puts a specular
// highlight behind the artwork, and over a mostly-transparent image that
// highlight is the artwork: a white disc with `[m]` scattered across it. Seen
// on the home screen, isolated by shipping the variants one at a time.
// `docs/issues.md` §20. An opaque neutral ground gives the highlight something
// to sit under, which is what every other icon on that screen has.
render(
    background: (r: 0.13, g: 0.13, b: 0.13), glyph: (r: 1, g: 1, b: 1),
    to: iconSet.appending(path: "icon-tinted.png")
)

let contents = """
{
  "images" : [
    {
      "filename" : "icon-light.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

try contents.write(
    to: iconSet.appending(path: "Contents.json"), atomically: true, encoding: .utf8
)
print("wrote Contents.json")


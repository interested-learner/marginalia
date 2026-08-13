import SwiftUI

/// The library as a graph. Nodes are the note ids themselves in mono type,
/// books are bracketed hubs, edges are hairlines, selection inverts to filled
/// ink. No color, no circles — see `docs/design-system.md` under *Map*.
///
/// Phase 1: a fixed layout with the real visual language, so the look can be
/// judged. Phase 7 replaces the positions with `GraphLayout` and the edges with
/// what `AffinityEngine` actually found.
struct MapView: View {
    @State private var selected: String? = Glyphs.noteID(7)

    private let nodes: [(String, CGPoint, Bool)] = [
        (Glyphs.noteID(1),  CGPoint(x: 0.22, y: 0.16), false),
        (Glyphs.noteID(9),  CGPoint(x: 0.76, y: 0.22), false),
        (Glyphs.noteID(7),  CGPoint(x: 0.48, y: 0.36), false),
        (Glyphs.noteID(3),  CGPoint(x: 0.72, y: 0.53), false),
        (Glyphs.noteID(8),  CGPoint(x: 0.24, y: 0.55), false),
        ("[Zen]",           CGPoint(x: 0.30, y: 0.75), true),
        (Glyphs.noteID(4),  CGPoint(x: 0.70, y: 0.78), false),
        (Glyphs.noteID(5),  CGPoint(x: 0.84, y: 0.90), false),
        ("[Meditations]",   CGPoint(x: 0.62, y: 0.94), true),
    ]

    private let edges: [(Int, Int)] = [
        (0, 2), (1, 2), (2, 3), (2, 4), (4, 5), (3, 6), (6, 7), (6, 8), (7, 8),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(style: .title("map"), trailing: Glyphs.count(nodes.count))

            GeometryReader { geo in
                let pt = { (p: CGPoint) in
                    CGPoint(x: p.x * geo.size.width, y: p.y * geo.size.height)
                }
                ZStack {
                    Canvas { ctx, _ in
                        for (a, b) in edges {
                            var path = Path()
                            path.move(to: pt(nodes[a].1))
                            path.addLine(to: pt(nodes[b].1))
                            let touches = selected == nodes[a].0 || selected == nodes[b].0
                            ctx.stroke(
                                path,
                                with: .color(touches ? Theme.ink : Theme.hairline),
                                lineWidth: 1
                            )
                        }
                    }

                    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                        let isSelected = selected == node.0
                        Text(node.0)
                            .font(node.2 ? Typography.mapHub : Typography.mapNode)
                            .foregroundStyle(isSelected ? Theme.onInk : Theme.ink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(isSelected ? Theme.ink : Theme.canvas)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .position(pt(node.1))
                            .onTapGesture { selected = node.0 }
                    }
                }
            }

            if let selected, let note = SampleData.streamYesterday.first(where: { $0.idLabel == selected }) {
                Hairline()
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(note.idLabel) · \(note.meta)")
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textAsh)
                    Text(note.text)
                        .font(Typography.noteBody)
                        .lineSpacing(Typography.bodyLeading)
                        .foregroundStyle(Theme.textBody)
                        .lineLimit(3)
                    Text(note.source)
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(Theme.canvas)
    }
}

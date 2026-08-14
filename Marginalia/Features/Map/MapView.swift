import SwiftUI
import SwiftData

/// The library as a graph. Nodes are the note ids themselves in mono type,
/// books are bracketed hubs, edges are hairlines, selection inverts to filled
/// ink. No color, no circles — see `docs/design-system.md` under *Map*.
///
/// **Phase 2 still hand-places every position and every line.** Only the
/// preview panel is real: it reads the selected note out of the store. Phase 7
/// replaces the positions with `GraphLayout` and the lines with what
/// `AffinityEngine` actually found.
struct MapView: View {
    @Query private var notes: [Note]

    @State private var selected: Int? = 7

    private struct Node {
        let shortID: Int?      // nil for a book hub
        let label: String
        let at: CGPoint
    }

    private let nodes: [Node] = [
        Node(shortID: 1, label: Glyphs.noteID(1), at: CGPoint(x: 0.22, y: 0.16)),
        Node(shortID: 9, label: Glyphs.noteID(9), at: CGPoint(x: 0.76, y: 0.22)),
        Node(shortID: 7, label: Glyphs.noteID(7), at: CGPoint(x: 0.48, y: 0.36)),
        Node(shortID: 3, label: Glyphs.noteID(3), at: CGPoint(x: 0.72, y: 0.53)),
        Node(shortID: 8, label: Glyphs.noteID(8), at: CGPoint(x: 0.24, y: 0.55)),
        Node(shortID: nil, label: "[Zen]", at: CGPoint(x: 0.30, y: 0.75)),
        Node(shortID: 4, label: Glyphs.noteID(4), at: CGPoint(x: 0.70, y: 0.78)),
        Node(shortID: 5, label: Glyphs.noteID(5), at: CGPoint(x: 0.84, y: 0.90)),
        Node(shortID: nil, label: "[Meditations]", at: CGPoint(x: 0.62, y: 0.94)),
    ]

    private let links: [(Int, Int)] = [
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
                        for (a, b) in links {
                            var path = Path()
                            path.move(to: pt(nodes[a].at))
                            path.addLine(to: pt(nodes[b].at))
                            let touches = touching(nodes[a]) || touching(nodes[b])
                            ctx.stroke(
                                path,
                                with: .color(touches ? Theme.ink : Theme.hairline),
                                lineWidth: 1
                            )
                        }
                    }

                    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                        let isSelected = touching(node)
                        Text(node.label)
                            .font(node.shortID == nil ? Typography.mapHub : Typography.mapNode)
                            .foregroundStyle(isSelected ? Theme.onInk : Theme.ink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(isSelected ? Theme.ink : Theme.canvas)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .position(pt(node.at))
                            .onTapGesture { selected = node.shortID }
                    }
                }
            }

            if let note = selectedNote {
                Hairline()
                let row = NoteRowData(note)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(row.idLabel) · \(row.meta)")
                        .font(Typography.meta)
                        .foregroundStyle(Theme.textAsh)
                    Text(row.text)
                        .font(Typography.noteBody)
                        .lineSpacing(Typography.bodyLeading)
                        .foregroundStyle(Theme.textBody)
                        .lineLimit(3)
                    Text(row.source)
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

    private func touching(_ node: Node) -> Bool {
        node.shortID != nil && node.shortID == selected
    }

    private var selectedNote: Note? {
        guard let selected else { return nil }
        return notes.first { $0.shortID == selected }
    }
}

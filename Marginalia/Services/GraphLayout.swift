import CoreGraphics
import Foundation

/// Where every node sits.
///
/// **Pure.** A node count and a list of edges in, points out — no models, no
/// store, no view, no clock. That's what makes convergence, determinism and the
/// spacing guarantee assertable without a container, and it's why `MapView` does
/// all the fetching on the other side of it, the same way `LinkWriter` sits
/// across from `AffinityEngine`.
///
/// Spring-electrical, as the spec asks for: every pair of nodes pushes apart,
/// every edge pulls together, and the whole thing is dragged gently toward the
/// middle so the notes nothing connects to don't drift off the page. A falling
/// temperature caps how far a node may move on each pass, so the layout settles
/// rather than oscillating.
///
/// **Nothing here is random.** Nodes start on a phyllotaxis spiral — evenly
/// spread and already asymmetric, so the forces have something to work against
/// without a seeded generator. The same graph lays out the same way every
/// launch, for the same reason `AffinityEngine` breaks its ties on the note id:
/// a map that rearranged itself overnight would read as the app changing its
/// mind about what connects to what.
nonisolated enum GraphLayout {

    /// A connection, **by index into the node list**. The layout never learns
    /// what a node is — `MapGraph` knows that, and this only knows how many
    /// there are and which pull on which.
    struct Edge: Hashable, Sendable {
        let a: Int
        let b: Int

        init(_ a: Int, _ b: Int) {
            self.a = a
            self.b = b
        }
    }

    struct Layout: Equatable, Sendable {
        /// One point per node, in a box **one wide and `aspect` tall** — the
        /// same shape the caller said it had room for. The graph is scaled
        /// uniformly to fill it and centred on whichever axis it doesn't reach,
        /// so the view multiplies *both* coordinates by the same number and
        /// nothing is stretched on the way to the screen.
        let positions: [CGPoint]

        /// The pull still acting on the busiest node when the budget ran out,
        /// as a fraction of the ideal edge length.
        ///
        /// **The force, not the step.** How far a node last *moved* is capped
        /// by the falling temperature and would shrink toward zero whether or
        /// not the graph had settled — a convergence number that can't report a
        /// failure. What's left pushing on a node can, and it's what
        /// `GraphLayoutTests` checks the iteration budget against rather than
        /// taking convergence on faith.
        let motion: Double

        static let empty = Layout(positions: [], motion: 0)
    }

    // MARK: The constants

    /// The spec's budget, and the floor under `budget(for:)`.
    static let passes = 300

    /// Three hundred passes settle forty-six nodes; they don't settle two
    /// hundred, and a graph still in motion when the budget runs out is a graph
    /// laid out badly rather than one laid out slowly. The whole thing is
    /// O(passes · N²) and the constant is tiny — forty-six nodes is three
    /// milliseconds, a hundred and fifty is twenty — so the budget grows with
    /// the library and stays cheap enough to be free.
    ///
    /// **One shape defeats it and it's worth naming:** a single hub with a few
    /// hundred leaves and nothing else — one enormous book, in this app —
    /// leaves a residual well above where the rest of the graphs land, at any
    /// budget worth spending. It draws as a hub in a halo, which is what it is;
    /// it just never quite stops shuffling the halo. See `docs/planning.md`.
    static func budget(for count: Int) -> Int { max(passes, count * 6) }

    /// No two nodes end up closer together than this **fraction of an ideal
    /// edge length**, times how big the pair of them are. Two of them in the
    /// same place is a node you can't tap under a label you can't read.
    ///
    /// Four fifths is generous for a pair of ordinary nodes and still well
    /// inside what will physically pack into the box, which is about `1.13`.
    static let minimumSpacing = 0.8

    /// The furthest a node may move on the first pass, as a fraction of the
    /// box. Falls linearly to nothing, which is what makes the layout settle.
    private static let temperature = 0.1

    /// Pulls every node toward the middle. Without it the eight notes nothing
    /// connected to would be shoved off the page by everything else, and a
    /// library of unconnected clusters would fly apart.
    ///
    /// **Four, and the number is derived rather than tuned.** The whole
    /// library's outward push on a node at radius `r` works out at `area / r`;
    /// an inward pull balances it at half the box exactly when this is four.
    /// The graph then settles just inside its walls instead of against them —
    /// weaker gravity pins the outermost nodes to the edge, where the clamp
    /// holds them still against a force that never resolves, and the layout is
    /// permanently mid-shove: it looks settled and isn't. That showed up as a
    /// residual seven times what it should be, and only in `motion`.
    ///
    /// It's applied **per axis**, stronger across the narrow dimension, so the
    /// graph settles into the shape of the box rather than into a disc inside
    /// a tall one.
    private static let gravity = 4.0

    /// Relaxation rounds for the spacing pass — a **ceiling, not a schedule**:
    /// the pass stops the first round it finds nothing to push apart, which on
    /// a graph the forces already spread is the first one. The number only
    /// matters in the case that needs it, which is a crowded tall box against
    /// the walls, and there twenty-four rounds fell about one percent short of
    /// the promise.
    private static let separationRounds = 150

    // MARK: The layout

    /// `aspect` is the height of the drawing area over its width. **It is not
    /// cosmetic.** Laying a graph out square and then drawing it into a box
    /// twice as tall as it is wide squeezes every horizontal gap to half of what
    /// the forces agreed on, and the first thing that collides is a book hub
    /// against the note beside it — which is exactly what happened.
    ///
    /// `sizes` is how much room each node needs relative to an ordinary one,
    /// and it matters for the same reason `aspect` does. A book hub is
    /// `[Meditations]` in bold mono and the note beside it is `n.05`; spacing
    /// them as if both were points puts a hub straight through its neighbour,
    /// which is what the first two passes at this screen did. Empty means every
    /// node is the same size.
    ///
    /// `iterations` is the budget, and `nil` takes the one `budget(for:)`
    /// picks — which is what everything but a test should do.
    static func positions(
        count: Int,
        edges: [Edge],
        aspect: Double = 1,
        sizes: [Double] = [],
        iterations: Int? = nil
    ) -> Layout {
        let aspect = aspect.isFinite && aspect > 0.01 ? min(aspect, 100) : 1
        guard count > 1 else {
            return count == 1
                ? Layout(positions: [CGPoint(x: 0.5, y: aspect / 2)], motion: 0)
                : .empty
        }

        var x = [Double](repeating: 0, count: count)
        var y = [Double](repeating: 0, count: count)
        spiral(&x, &y, aspect)

        // The ideal distance between two connected nodes, if the whole box were
        // shared out evenly. Every force below is expressed in terms of it,
        // which is what makes the same constants work at 12 nodes and at 400.
        let ideal = (aspect / Double(count)).squareRoot()
        let links = edges.filter { edge in
            edge.a != edge.b && x.indices.contains(edge.a) && x.indices.contains(edge.b)
        }

        var pushX = [Double](repeating: 0, count: count)
        var pushY = [Double](repeating: 0, count: count)
        var motion = 0.0
        let passes = max(1, iterations ?? budget(for: count))

        for pass in 0..<passes {
            let limit = temperature * (1 - Double(pass) / Double(passes))
            for index in 0..<count {
                pushX[index] = 0
                pushY[index] = 0
            }

            // Everything pushes everything else away, weakening with distance.
            // O(N²), which the spec allows under a couple of thousand nodes —
            // and above ~150 the map has collapsed to book hubs long before.
            for i in 0..<count {
                for j in (i + 1)..<count {
                    let (ux, uy, distance) = direction(x[i] - x[j], y[i] - y[j])
                    let force = ideal * ideal / distance
                    pushX[i] += ux * force
                    pushY[i] += uy * force
                    pushX[j] -= ux * force
                    pushY[j] -= uy * force
                }
            }

            // A connection pulls, and pulls harder the further apart it's been
            // stretched.
            for link in links {
                let (ux, uy, distance) = direction(x[link.a] - x[link.b], y[link.a] - y[link.b])
                let force = distance * distance / ideal
                pushX[link.a] -= ux * force
                pushY[link.a] -= uy * force
                pushX[link.b] += ux * force
                pushY[link.b] += uy * force
            }

            for index in 0..<count {
                pushX[index] += (0.5 - x[index]) * gravity * aspect
                pushY[index] += (aspect / 2 - y[index]) * gravity / aspect
            }

            motion = 0
            for index in 0..<count {
                let travel = (pushX[index] * pushX[index] + pushY[index] * pushY[index]).squareRoot()
                guard travel > 0 else { continue }
                let step = min(travel, limit)
                // Clamped to the box rather than left to run: gravity handles
                // the common case, and the box handles the pathological one.
                x[index] = min(1, max(0, x[index] + pushX[index] / travel * step))
                y[index] = min(aspect, max(0, y[index] + pushY[index] / travel * step))
                motion = max(motion, travel)
            }
        }

        fill(&x, &y, aspect)
        separate(&x, &y, ideal, aspect, room(sizes, count))

        return Layout(
            positions: zip(x, y).map { CGPoint(x: $0, y: $1) },
            motion: motion / ideal
        )
    }

    // MARK: The pieces

    /// The golden angle, which is what spreads a spiral evenly rather than into
    /// visible arms. Sunflowers, and every scatter that needed to look
    /// deliberate without being random.
    private static func spiral(_ x: inout [Double], _ y: inout [Double], _ aspect: Double) {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        let count = Double(x.count)
        for index in x.indices {
            let angle = Double(index) * golden
            let radius = 0.5 * ((Double(index) + 0.5) / count).squareRoot()
            x[index] = 0.5 + radius * cos(angle)
            y[index] = aspect / 2 + radius * aspect * sin(angle)
        }
    }

    /// A unit vector and the distance it came from. Two nodes that have landed
    /// in exactly the same place are pushed apart along x rather than dividing
    /// by zero — deterministically, like everything else here.
    private static func direction(_ dx: Double, _ dy: Double) -> (x: Double, y: Double, distance: Double) {
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 1e-9 else { return (1, 0, 1e-6) }
        return (dx / distance, dy / distance, distance)
    }

    /// Scales the settled graph to fill the unit box, **uniformly**. Fitting
    /// each axis on its own would stretch a tall graph sideways and quietly undo
    /// the spacing the forces just worked out.
    private static func fill(_ x: inout [Double], _ y: inout [Double], _ aspect: Double) {
        guard let minX = x.min(), let maxX = x.max(),
              let minY = y.min(), let maxY = y.max() else { return }

        let spanX = maxX - minX
        let spanY = maxY - minY
        guard spanX > 1e-9 || spanY > 1e-9 else {
            for index in x.indices {
                x[index] = 0.5
                y[index] = aspect / 2
            }
            return
        }

        // Whichever axis runs out of room first sets the scale for both.
        let scale = min(spanX > 1e-9 ? 1 / spanX : .greatestFiniteMagnitude,
                        spanY > 1e-9 ? aspect / spanY : .greatestFiniteMagnitude)
        let midX = (minX + maxX) / 2
        let midY = (minY + maxY) / 2
        for index in x.indices {
            x[index] = 0.5 + (x[index] - midX) * scale
            y[index] = aspect / 2 + (y[index] - midY) * scale
        }
    }

    /// One size per node, whatever the caller passed. A short or missing list
    /// means ordinary nodes, and a non-positive size is one.
    private static func room(_ sizes: [Double], _ count: Int) -> [Double] {
        (0..<count).map { index in
            guard sizes.indices.contains(index), sizes[index] > 0 else { return 1 }
            return sizes[index]
        }
    }

    /// The last pass, and the one that makes `minimumSpacing` a promise rather
    /// than a tendency. Force-directed layout has no non-overlap guarantee in
    /// it — two nodes can settle on top of each other and the forces will
    /// happily leave them there — so any pair still too close is prised apart.
    ///
    /// It also holds each node back from the **walls** by its own half-size, so
    /// a node's label has somewhere to be drawn. Without it a wide book hub
    /// settles happily at `x = 0` and the reader sees `Meditations]` with its
    /// opening bracket off the side of the screen.
    private static func separate(
        _ x: inout [Double],
        _ y: inout [Double],
        _ ideal: Double,
        _ aspect: Double,
        _ sizes: [Double]
    ) {
        let count = x.count
        // Capped, because a single enormous label in a small graph would
        // otherwise be given a margin wider than the box and pinned to the
        // middle of it.
        let margin = sizes.map { min(minimumSpacing * ideal * $0 / 2, 0.2) }

        func hold() {
            for index in 0..<count {
                let side = margin[index]
                let above = min(margin[index], aspect / 4)
                x[index] = min(1 - side, max(side, x[index]))
                y[index] = min(aspect - above, max(above, y[index]))
            }
        }

        // Up front as well as after every round, or a graph that needed no
        // prising apart would never be pulled off the walls at all.
        hold()

        for _ in 0..<separationRounds {
            var moved = false
            for i in 0..<count {
                for j in (i + 1)..<count {
                    let target = minimumSpacing * ideal * (sizes[i] + sizes[j]) / 2
                    let (ux, uy, distance) = direction(x[i] - x[j], y[i] - y[j])
                    guard distance < target else { continue }
                    let push = (target - distance) / 2
                    x[i] += ux * push
                    y[i] += uy * push
                    x[j] -= ux * push
                    y[j] -= uy * push
                    moved = true
                }
            }
            guard moved else { break }
            hold()
        }
    }
}

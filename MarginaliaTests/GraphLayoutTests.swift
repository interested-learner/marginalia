import CoreGraphics
import Foundation
import Testing
@testable import Marginalia

/// The three things the spec asks of the layout: **deterministic given a seed,
/// no overlapping nodes, convergence inside the iteration budget.**
///
/// It can't tell anyone whether the map *looks* right — that needs a screenshot
/// and a person, the same way the connections themselves do. What it can prove
/// is that the geometry doesn't cheat.
struct GraphLayoutTests {

    /// A ring: every node joined to the next, the last back to the first. Enough
    /// structure that a working layout produces something recognisably round and
    /// a broken one collapses.
    private func ring(_ count: Int) -> [GraphLayout.Edge] {
        (0..<count).map { GraphLayout.Edge($0, ($0 + 1) % count) }
    }

    /// One hub with everything hanging off it — a book, in the app's terms.
    private func star(_ count: Int) -> [GraphLayout.Edge] {
        (1..<count).map { GraphLayout.Edge(0, $0) }
    }

    /// Three chains that touch nothing else. Gravity is the only thing keeping
    /// them on the same page, which is exactly what a library of unrelated
    /// books looks like before the app has connected much.
    private func clumps(_ count: Int) -> [GraphLayout.Edge] {
        var edges: [GraphLayout.Edge] = []
        for clump in 0..<3 {
            let base = clump * count / 3
            for node in base..<(base + count / 3 - 1) {
                edges.append(GraphLayout.Edge(node, node + 1))
            }
        }
        return edges
    }

    /// The closest any two nodes came, measured in the box the layout was asked
    /// for — which is the space the view draws into, uniformly scaled.
    private func spacing(_ layout: GraphLayout.Layout) -> Double {
        var closest = Double.greatestFiniteMagnitude
        let points = layout.positions
        for i in points.indices {
            for j in (i + 1)..<points.count {
                let dx = points[i].x - points[j].x
                let dy = points[i].y - points[j].y
                closest = min(closest, Double((dx * dx + dy * dy).squareRoot()))
            }
        }
        return closest
    }

    // MARK: Determinism

    @Test func theSameGraphLaysOutTheSameWayTwice() {
        let first = GraphLayout.positions(count: 30, edges: ring(30))
        let second = GraphLayout.positions(count: 30, edges: ring(30))

        #expect(first == second)
    }

    /// Nothing here reaches for a random generator, so this holds without a seed
    /// being passed in — which is the point. A map that rearranged itself
    /// overnight would read as the app changing its mind.
    @Test func aStarLaysOutTheSameWayTwice() {
        #expect(GraphLayout.positions(count: 12, edges: star(12))
             == GraphLayout.positions(count: 12, edges: star(12)))
    }

    // MARK: Spacing

    /// The ideal edge length in a box of this shape — what `minimumSpacing` is
    /// a fraction of.
    private func floor(_ count: Int, aspect: Double = 1) -> Double {
        GraphLayout.minimumSpacing * (aspect / Double(count)).squareRoot()
    }

    @Test func noTwoNodesLandOnTopOfEachOther() {
        for count in [2, 7, 30, 46, 120] {
            let layout = GraphLayout.positions(count: count, edges: ring(count))

            #expect(spacing(layout) >= floor(count) * 0.999,
                    "\(count) nodes came out too close together")
        }
    }

    /// The shape the app actually asks for: a phone's map area is about twice
    /// as tall as it is wide. This is the case a square layout got wrong, and it
    /// showed up on screen as a book hub sitting on top of the note beside it.
    @Test func nodesStaySpacedInATallBox() {
        for count in [7, 46, 120] {
            let layout = GraphLayout.positions(count: count, edges: ring(count), aspect: 2.06)

            #expect(spacing(layout) >= floor(count, aspect: 2.06) * 0.999)
        }
    }

    @Test func aTallBoxIsFilledRatherThanASquareInsideIt() {
        let layout = GraphLayout.positions(count: 46, edges: ring(46), aspect: 2)
        let ys = layout.positions.map(\.y)

        #expect(ys.max()! - ys.min()! > 1.5)
    }

    /// The hard case for a force-directed layout: everything pulled toward one
    /// point by an edge, and nothing but repulsion holding it apart.
    @Test func aStarDoesNotPileItsNodesOnTheHub() {
        let layout = GraphLayout.positions(count: 40, edges: star(40))

        #expect(spacing(layout) >= floor(40) * 0.999)
    }

    /// Nothing pulls these together at all, so gravity and the box are the only
    /// things keeping them on the page.
    @Test func nodesWithNoEdgesStillFitTheBox() {
        let layout = GraphLayout.positions(count: 25, edges: [])

        for point in layout.positions {
            #expect(point.x >= 0 && point.x <= 1)
            #expect(point.y >= 0 && point.y <= 1)
        }
    }

    // MARK: Convergence

    /// `motion` is the pull still acting on the busiest node, over the ideal
    /// edge length. Under a half means nothing is being asked to move even
    /// halfway to where it already sits from its neighbours — the graph has
    /// arrived, and more passes wouldn't take it anywhere a reader could see.
    @Test func theGraphHasSettledByTheEndOfTheBudget() {
        for edges in [ring(46), star(46), clumps(45), []] {
            let layout = GraphLayout.positions(count: 46, edges: edges)
            #expect(layout.motion < 0.5)
        }
    }

    /// And still at the size the collapse rule hands it. This is why the budget
    /// grows with the library: at a flat three hundred passes a hundred and
    /// twenty nodes are still moving when it runs out.
    @Test func aLargeGraphAlsoSettles() {
        for edges in [ring(120), clumps(120), []] {
            #expect(GraphLayout.positions(count: 120, edges: edges).motion < 0.5)
        }
        #expect(GraphLayout.positions(count: 120, edges: ring(120), iterations: 300).motion
              > GraphLayout.positions(count: 120, edges: ring(120)).motion)
    }

    /// The other half of the claim: the budget is doing work rather than being
    /// long enough to be beside the point. Twelve passes leave the graph
    /// visibly unfinished.
    @Test func aShorterBudgetHasNotSettledAsFar() {
        let brief = GraphLayout.positions(count: 46, edges: ring(46), iterations: 12)
        let full = GraphLayout.positions(count: 46, edges: ring(46))

        #expect(brief.motion > full.motion)
    }

    // MARK: The box

    /// The graph fills the box **less the room its nodes need at the walls** —
    /// a node's label is drawn around its position, not to one side of it, so a
    /// graph flush against the edge is a graph with its labels half off screen.
    @Test func theLongerSideFillsTheBoxLessItsMargins() {
        let layout = GraphLayout.positions(count: 40, edges: ring(40))
        let xs = layout.positions.map(\.x)
        let ys = layout.positions.map(\.y)
        let span = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!)
        // An ordinary node's wall margin is half its share of an edge length.
        let margin = floor(40) / 2

        #expect(abs(span - (1 - 2 * margin)) < 0.05)
        #expect(span > 0.8)
    }

    /// A book hub's label is three times the width of a note id, and the layout
    /// is told so. Both halves of that show here: it gets more room from its
    /// neighbours, and more room from the wall.
    @Test func aBigNodeIsGivenMoreRoom() {
        let sizes = [3.25] + [Double](repeating: 1, count: 24)
        let layout = GraphLayout.positions(count: 25, edges: star(25), sizes: sizes)
        let hub = layout.positions[0]
        let ideal = (1 / 25.0).squareRoot()

        for leaf in layout.positions.dropFirst() {
            let gap = Double(hypot(hub.x - leaf.x, hub.y - leaf.y))
            #expect(gap >= GraphLayout.minimumSpacing * ideal * (3.25 + 1) / 2 * 0.999)
        }
        #expect(hub.x > 0.1 && hub.x < 0.9)
    }

    /// Nothing may make it worse than an ordinary node: a garbage size falls
    /// back rather than shrinking a node to a point.
    @Test func nonsenseSizesFallBackToOrdinaryOnes() {
        let layout = GraphLayout.positions(count: 9, edges: ring(9), sizes: [0, -4])

        #expect(spacing(layout) >= floor(9) * 0.999)
    }

    @Test func everythingStaysInsideTheBox() {
        for aspect in [0.5, 1.0, 2.06] {
            let layout = GraphLayout.positions(
                count: 46, edges: ring(46) + star(46), aspect: aspect
            )
            for point in layout.positions {
                #expect(point.x >= -0.0001 && point.x <= 1.0001)
                #expect(point.y >= -0.0001 && point.y <= aspect + 0.0001)
            }
        }
    }

    /// Nothing the view can hand it may crash it, and a zero-height frame is
    /// what a screen hands out for one layout pass while it's working out how
    /// much room there is.
    @Test func anImpossibleBoxFallsBackToASquareOne() {
        for aspect in [0.0, -3.0, Double.nan, .infinity] {
            #expect(GraphLayout.positions(count: 9, edges: ring(9), aspect: aspect).positions.count == 9)
        }
    }

    // MARK: Degenerate graphs

    @Test func anEmptyGraphLaysOutToNothing() {
        #expect(GraphLayout.positions(count: 0, edges: []).positions.isEmpty)
    }

    @Test func aLoneNodeSitsInTheMiddle() {
        #expect(GraphLayout.positions(count: 1, edges: []).positions == [CGPoint(x: 0.5, y: 0.5)])
        #expect(GraphLayout.positions(count: 1, edges: [], aspect: 2).positions
             == [CGPoint(x: 0.5, y: 1)])
    }

    /// A note joined to itself, and an edge naming a node that isn't there.
    /// Neither should exist by the time this is called; neither may crash it.
    @Test func nonsenseEdgesAreIgnored() {
        let layout = GraphLayout.positions(
            count: 5,
            edges: [GraphLayout.Edge(2, 2), GraphLayout.Edge(0, 99), GraphLayout.Edge(-1, 3)]
        )

        #expect(layout.positions.count == 5)
    }

    /// Two nodes and one edge is the smallest graph the app can draw — a note
    /// and the book it came from, on a first launch.
    @Test func twoNodesAndOneEdgeAreSeparated() {
        let layout = GraphLayout.positions(count: 2, edges: [GraphLayout.Edge(0, 1)])
        let apart = spacing(layout)

        #expect(apart > 0.5)
    }
}

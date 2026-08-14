import Testing
@testable import Marginalia

/// Edges store a direction; the UI shows both. Half of every note's
/// connections would otherwise be invisible.
struct ConnectionIndexTests {

    @Test func anEdgeIsVisibleFromBothEnds() {
        let index = ConnectionIndex.build(from: [(from: 7, to: 9)])
        #expect(index[7] == [9])
        #expect(index[9] == [7])
    }

    @Test func connectionsAreListedInIDOrder() {
        let index = ConnectionIndex.build(from: [(1, 9), (1, 3), (1, 5)])
        #expect(index[1] == [3, 5, 9])
    }

    /// A pair recorded in both directions is one connection, not two.
    @Test func aReciprocalPairIsNotListedTwice() {
        let index = ConnectionIndex.build(from: [(1, 2), (2, 1)])
        #expect(index[1] == [2])
        #expect(index[2] == [1])
    }

    @Test func aNoteNeverConnectsToItself() {
        #expect(ConnectionIndex.build(from: [(4, 4)]).isEmpty)
    }

    @Test func noEdgesMeansAnEmptyIndex() {
        #expect(ConnectionIndex.build(from: []).isEmpty)
    }
}

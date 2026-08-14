import Foundation

/// Turns edges into "which notes does `n.07` connect to", by short id.
///
/// **Edges store a direction; the UI shows both.** Otherwise half of every
/// note's connections are invisible — the note that got linked *to* would never
/// know about it.
enum ConnectionIndex {

    static func build(from pairs: [(from: Int, to: Int)]) -> [Int: [Int]] {
        var index: [Int: Set<Int>] = [:]
        for pair in pairs where pair.from != pair.to {
            index[pair.from, default: []].insert(pair.to)
            index[pair.to, default: []].insert(pair.from)
        }
        return index.mapValues { $0.sorted() }
    }
}

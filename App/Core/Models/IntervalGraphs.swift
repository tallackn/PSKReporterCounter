import Foundation

/// Fixed, wall-clock seconds keep the histogram's resolution and bin boundaries
/// unchanged as the live window advances or its duration is increased.
public struct ArrivalBin: Equatable, Identifiable, Sendable {
    public let id: Int64
    public let count: Int
    public var startedAt: Date { Date(timeIntervalSince1970: Double(id)) }
    public var endedAt: Date { startedAt.addingTimeInterval(1) }

    static func make(from selectedReports: [ReceivedReception]) -> [ArrivalBin] {
        var counts: [Int64: Int] = [:]
        for report in selectedReports {
            let second = Int64(floor(report.receivedAt.timeIntervalSince1970))
            counts[second, default: 0] += 1
        }
        return counts.keys.sorted().map { ArrivalBin(id: $0, count: counts[$0]!) }
    }
}

public struct SignalSummary: Equatable, Sendable {
    public let sampleCount: Int
    public let minimum: Double
    public let lowerQuartile: Double
    public let median: Double
    public let upperQuartile: Double
    public let maximum: Double
    public let lowerWhisker: Double
    public let upperWhisker: Double
    public let outliers: [Double]

    public init?(values: [Double]) {
        let sorted = values.filter(\.isFinite).sorted()
        guard let first = sorted.first, let last = sorted.last else { return nil }
        // Linear interpolation at (n - 1) * p (the R type 7 convention).
        func quantile(_ p: Double) -> Double {
            let position = Double(sorted.count - 1) * p
            let lower = Int(floor(position))
            let upper = Int(ceil(position))
            return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
        }
        sampleCount = sorted.count
        minimum = first
        maximum = last
        lowerQuartile = quantile(0.25)
        median = quantile(0.5)
        upperQuartile = quantile(0.75)
        let spread = upperQuartile - lowerQuartile
        let lowerFence = lowerQuartile - 1.5 * spread
        let upperFence = upperQuartile + 1.5 * spread
        lowerWhisker = sorted.first { $0 >= lowerFence }!
        upperWhisker = sorted.last { $0 <= upperFence }!
        outliers = sorted.filter { $0 < lowerFence || $0 > upperFence }
    }
}

import Charts
import PSKReporterCore
import SwiftUI

private struct SignalPoint: Identifiable, Equatable {
    enum Phase { case steady, arriving, departing }
    let id: UUID
    let signal: Double
    let jitter: Double
    var phase = Phase.steady

    static func make(from snapshot: ListenerSnapshot) -> [SignalPoint] {
        snapshot.selectedReports.compactMap { report in
            guard let signal = report.report.signalToNoise else { return nil }
            // Stable vertical spacing separates overlapping station reports.
            let hash = report.report.receiver.utf8.reduce(UInt64(2_166_136_261)) { ($0 ^ UInt64($1)) &* 16_777_619 }
            return SignalPoint(id: report.id,
                signal: signal, jitter: Double(hash % 101) / 100 * 0.7 - 0.35)
        }
    }
}

struct SignalBoxPlotView: View {
    let snapshot: ListenerSnapshot
    let animate: Bool
    @State private var points: [SignalPoint]
    @State private var domain: ClosedRange<Double>
    @State private var fadeProgress = 1.0
    @State private var transitionTask: Task<Void, Never>?

    init(snapshot: ListenerSnapshot, animate: Bool) {
        self.snapshot = snapshot
        self.animate = animate
        let points = SignalPoint.make(from: snapshot)
        _points = State(initialValue: points)
        _domain = State(initialValue: Self.domain(for: points) ?? -30...10)
    }

    private var summary: SignalSummary? { snapshot.signalSummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reported signal").font(.headline)
                Spacer()
                Text("SNR (dB)").font(.caption).foregroundStyle(.secondary)
            }
            Chart {
                if let box = summary {
                    RuleMark(xStart: .value("SNR", box.lowerWhisker), xEnd: .value("SNR", box.lowerQuartile), y: .value("Position", 0))
                        .foregroundStyle(.teal).lineStyle(StrokeStyle(lineWidth: 1.5))
                    RuleMark(xStart: .value("SNR", box.upperQuartile), xEnd: .value("SNR", box.upperWhisker), y: .value("Position", 0))
                        .foregroundStyle(.teal).lineStyle(StrokeStyle(lineWidth: 1.5))
                    RectangleMark(xStart: .value("SNR", box.lowerQuartile), xEnd: .value("SNR", box.upperQuartile),
                        yStart: .value("Position", -0.2), yEnd: .value("Position", 0.2))
                        .foregroundStyle(.teal.opacity(0.2))
                    ForEach([box.lowerWhisker, box.upperWhisker].enumerated().map { Whisker(id: $0.offset, value: $0.element) }) { whisker in
                        RuleMark(x: .value("SNR", whisker.value), yStart: .value("Position", -0.13), yEnd: .value("Position", 0.13))
                            .foregroundStyle(.teal).lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    RuleMark(x: .value("Median SNR", box.median), yStart: .value("Position", -0.23), yEnd: .value("Position", 0.23))
                        .foregroundStyle(.primary).lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXScale(domain: domain, range: .plotDimension(padding: 0))
            .chartYScale(domain: -0.6...0.6, range: .plotDimension(padding: 0))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plot in
                plot.overlay {
                    SignalPointCloud(points: points, lowerBound: domain.lowerBound, upperBound: domain.upperBound,
                        summary: summary, progress: fadeProgress)
                }.clipped()
            }
            .frame(height: 112)
            .animation(animate ? .easeInOut(duration: 0.5) : nil, value: summary)
            .accessibilityLabel("Reported signal strength distribution")
            .accessibilityValue(sampleDescription)
            .overlay {
                if summary == nil && points.isEmpty {
                    Text("No signal reports in this window.").font(.callout).foregroundStyle(.secondary)
                }
            }
            if let box = summary {
                HStack {
                    statistic("Lower quartile", value: box.lowerQuartile)
                    Spacer()
                    statistic("Median", value: box.median)
                    Spacer()
                    statistic("Upper quartile", value: box.upperQuartile)
                }
            }
            HStack(alignment: .top) {
                Text("Box: middle 50%. Whiskers: 1.5× IQR. Orange points: outliers.")
                Spacer(minLength: 8)
                Text(sampleDescription).multilineTextAlignment(.trailing)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: snapshot.selectedReports) { _ in updatePoints() }
        .onAppear { updatePoints() }
        .onDisappear { transitionTask?.cancel() }
    }

    private struct Whisker: Identifiable { let id: Int; let value: Double }

    private func statistic(_ label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) dB")
                .font(.callout.weight(.medium)).monospacedDigit()
        }
    }

    private var sampleDescription: String {
        let samples = summary?.sampleCount ?? 0
        let missing = snapshot.count - samples
        return "\(samples) \(samples == 1 ? "signal report" : "signal reports")"
            + (missing > 0 ? "\n\(missing) without SNR" : "")
    }

    private static func domain(for points: [SignalPoint]) -> ClosedRange<Double>? {
        guard let low = points.map(\.signal).min(), let high = points.map(\.signal).max() else { return nil }
        return (floor(low / 5) * 5 - 5)...(ceil(high / 5) * 5 + 5)
    }

    private func updatePoints() {
        transitionTask?.cancel()
        let next = SignalPoint.make(from: snapshot)
        guard animate else {
            points = next
            if let nextDomain = Self.domain(for: next) { domain = nextDomain }
            return
        }
        let nextIDs = Set(next.map(\.id))
        let oldIDs = Set(points.map(\.id))
        let departing = points.filter { !nextIDs.contains($0.id) }.map { point in
            var point = point
            point.phase = .departing
            return point
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            points = next.map { point in
                var point = point
                if !oldIDs.contains(point.id) { point.phase = .arriving }
                return point
            } + departing
            fadeProgress = 0
        }
        if let expanded = Self.domain(for: points) {
            withAnimation(.easeInOut(duration: 0.5)) { domain = expanded }
        }
        transitionTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { fadeProgress = 1 }
            do { try await Task.sleep(nanoseconds: 600_000_000) } catch { return }
            points = next
            if let finalDomain = Self.domain(for: next) {
                withAnimation(.easeInOut(duration: 0.5)) { domain = finalDomain }
            }
        }
    }
}

/// One asynchronous drawing keeps large station sets out of the SwiftUI view
/// tree. The animatable progress fades arrivals and departures together.
private struct SignalPointCloud: View, Animatable {
    let points: [SignalPoint]
    nonisolated var lowerBound: Double
    nonisolated var upperBound: Double
    let summary: SignalSummary?
    nonisolated var progress: Double

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(progress, AnimatablePair(lowerBound, upperBound)) }
        set { progress = newValue.first; lowerBound = newValue.second.first; upperBound = newValue.second.second }
    }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for point in points {
                let x = (point.signal - lowerBound) / (upperBound - lowerBound) * size.width
                let y = (0.6 - point.jitter) / 1.2 * size.height
                let opacity = point.phase == .arriving ? progress : point.phase == .departing ? 1 - progress : 1
                let outlier = summary.map { point.signal < $0.lowerWhisker || point.signal > $0.upperWhisker } ?? false
                let colour: Color = outlier ? .orange : .teal
                context.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)),
                    with: .color(colour.opacity(opacity * 0.7)))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

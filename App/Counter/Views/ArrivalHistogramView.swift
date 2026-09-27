import Charts
import PSKReporterCore
import SwiftUI

struct ArrivalHistogramView: View {
    let snapshot: ListenerSnapshot
    @State private var detail = false
    @State private var hoveredSecond: Int64?

    private var peak: Int { max(1, snapshot.arrivalBins.map(\.count).max() ?? 0) }
    private var ticks: [Int] { Array(Set([0, peak / 2, peak])).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Arrivals").font(.headline)
                Spacer()
                Toggle("Detail", isOn: $detail).toggleStyle(.button).controlSize(.small)
                    .help("Show one-second bins at full width. Scroll horizontally to inspect earlier arrivals.")
            }
            GeometryReader { geometry in
                if detail {
                    ScrollViewReader { reader in
                        ScrollView(.horizontal) {
                            HStack(spacing: 0) {
                                histogram(width: max(geometry.size.width, snapshot.interval.seconds * 6 + 45))
                                Color.clear.frame(width: 0).id("now")
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.async { reader.scrollTo("now", anchor: .trailing) }
                        }
                    }
                } else {
                    histogram(width: geometry.size.width)
                }
            }
            .frame(height: 182)
            .onChange(of: detail) { _ in hoveredSecond = nil }
            HStack {
                if let second = hoveredSecond {
                    let count = snapshot.arrivalBins.first { $0.id == second }?.count ?? 0
                    Text("\(Date(timeIntervalSince1970: Double(second)).formatted(date: .omitted, time: .standard)): \(count)")
                        .monospacedDigit()
                } else {
                    Text("One-second bins.")
                }
                Spacer()
                Text(detail ? "Scroll for earlier arrivals" : "Total: \(snapshot.count)").monospacedDigit()
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func histogram(width: CGFloat) -> some View {
        Chart {
            RuleMark(y: .value("Stations", 0)).foregroundStyle(.clear)
        }
        .chartXScale(domain: snapshot.startedAt...snapshot.endedAt, range: .plotDimension(padding: 0))
        .chartYScale(domain: 0...peak)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: max(3, Int(width / 140)))) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute().second())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: ticks) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartPlotStyle { plot in
            plot.background {
                // Batch the bars into one drawing rather than thousands of
                // SwiftUI marks. Every one-second bin is still drawn.
                Canvas(rendersAsynchronously: true) { context, size in
                    let duration = snapshot.interval.seconds
                    let barWidth = max(0.5, size.width / duration * 0.85)
                    var bars = Path()
                    for bin in snapshot.arrivalBins {
                        let elapsed = bin.startedAt.timeIntervalSince(snapshot.startedAt) + 0.5
                        let x = elapsed / duration * size.width
                        let height = Double(bin.count) / Double(peak) * size.height
                        bars.addRect(CGRect(x: x - barWidth / 2, y: size.height - height, width: barWidth, height: height))
                    }
                    context.fill(bars, with: .color(.accentColor))
                }
                .accessibilityLabel("Total \(snapshot.count) in one-second arrival bins")
            }.clipped()
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            let plot = geometry[proxy.plotAreaFrame]
                            guard plot.contains(point), let date: Date = proxy.value(atX: point.x - plot.minX) else {
                                hoveredSecond = nil
                                return
                            }
                            hoveredSecond = Int64(floor(date.timeIntervalSince1970))
                        case .ended: hoveredSecond = nil
                        }
                    }
            }
        }
        .frame(width: width, height: 168)
        .accessibilityLabel("Arrivals over time")
    }
}

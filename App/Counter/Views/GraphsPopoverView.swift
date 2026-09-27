import PSKReporterCore
import SwiftUI

struct GraphsPopoverView: View {
    @ObservedObject var monitor: MonitorModel

    private var live: Bool { monitor.isRunning && monitor.isConnected }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.isConfigured ? monitor.callsign : "PSK Reporter Counter")
                        .font(.title2.weight(.semibold))
                    Text("\(monitor.filter.band.label), \(monitor.filter.mode.label)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let snapshot = monitor.snapshot {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(snapshot.count)").font(.title2.weight(.semibold)).monospacedDigit()
                        Text("in this window").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let snapshot = monitor.snapshot {
                HStack {
                    Circle().fill(live ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text(live ? "Live, last \(snapshot.interval.label)" : "Last collected window")
                    Spacer()
                    Text(snapshot.endedAt, format: .dateTime.hour().minute().second()).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
                if let issue = monitor.activeIssue {
                    Text("\(issue.summary). Right-click the menu bar icon for Settings.")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                } else if !monitor.isRunning {
                    Text("Monitoring is stopped.").font(.caption).foregroundStyle(.secondary)
                } else if monitor.isFillingWindow {
                    Text("The live window is filling as reports arrive.").font(.caption).foregroundStyle(.secondary)
                }
                IntervalChartsView(snapshot: snapshot)
                Divider()
                Text("The counter and graphs share this sliding window and update every second.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text(monitor.statusTitle).font(.headline)
                    Text(monitor.isConfigured && monitor.isRunning
                         ? "The graphs will start as soon as the live feed connects."
                         : "Right-click the menu bar icon to open Settings or start monitoring.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let issue = monitor.activeIssue { Text(issue.summary).font(.caption).foregroundStyle(.orange) }
                }
                .frame(maxWidth: .infinity).frame(height: 230)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

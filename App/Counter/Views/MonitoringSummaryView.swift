import PSKReporterCore
import SwiftUI

struct MonitoringSummaryView: View {
    let snapshot: ListenerSnapshot?
    let title: String
    let statusColour: Color
    let isActive: Bool
    let isConnecting: Bool
    let canToggle: Bool
    let toggleMonitoring: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.map { String($0.count) } ?? "—")
                    .font(.system(size: 42, weight: .medium, design: .rounded)).monospacedDigit()
                    .accessibilityLabel(snapshot.map { "\($0.count) \($0.unitLabel) in the live window" } ?? "Waiting for the live feed")
                Text(snapshot?.unitLabel ?? "live count").font(.caption).foregroundStyle(.secondary)
            }
            Divider().frame(height: 60)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Circle().fill(statusColour).frame(width: 7, height: 7)
                    Text(title).fontWeight(.medium)
                    if isConnecting { ProgressView().controlSize(.small) }
                }
                if let result = snapshot {
                    Text("\(result.callsign) · last \(result.interval.label)").foregroundStyle(.secondary)
                    Text("Updated \(result.endedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(isActive ? "Connecting to the live feed." : "Enter a callsign and start monitoring.").foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button(isActive ? "Stop" : "Start", action: toggleMonitoring)
            .disabled(!canToggle)
            .accessibilityIdentifier("monitorToggle")
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

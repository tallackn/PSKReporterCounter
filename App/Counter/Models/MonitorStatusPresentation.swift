import PSKReporterCore
import Foundation

@MainActor
struct MonitorStatusPresentation {
    let title: String
    let detail: String
    let timing: String?
    let isError: Bool
    let canDismiss: Bool

    init(monitor: MonitorModel) {
        title = monitor.statusTitle
        detail = Self.makeDetail(monitor)
        isError = monitor.activeIssue != nil
        canDismiss = monitor.settingsIssue != nil
        if monitor.isFillingWindow, let fullAt = monitor.coverageCompletesAt {
            timing = "Live now. Full window available at \(fullAt.formatted(date: .omitted, time: .standard))"
        } else if let retry = monitor.retryAt {
            timing = "Retrying connection at \(retry.formatted(date: .omitted, time: .standard))"
        } else { timing = nil }
    }

    private static func makeDetail(_ monitor: MonitorModel) -> String {
        var details: [String] = []
        for issue in [monitor.feedIssue, monitor.settingsIssue].compactMap({ $0 }) {
            details.append("\(issue.occurredAt.formatted(date: .abbreviated, time: .standard))\n\(issue.detail)")
        }
        if !details.isEmpty {
            if monitor.feedIssue != nil, monitor.snapshot != nil {
                details.append(monitor.isConnected ? "The live window is refilling after an interruption." : "The number above is the last result before the interruption.")
            }
            if monitor.feedIssue != nil, monitor.isRunning {
                details.append(monitor.isConnected ? "Connected. The warning clears after a full uninterrupted window." : "The connection will retry automatically.")
            }
            if monitor.settingsIssue != nil { details.append("Resolve the setting or dismiss its error below.") }
            return details.joined(separator: "\n\n")
        }
        if !monitor.isConfigured { return "A valid transmitting callsign is required.\nThe menu bar displays ⛔️ until monitoring is configured." }
        if !monitor.isRunning { return "Monitoring is stopped. The live feed is disconnected.\nChoose Start to resume." }
        if monitor.isConnecting { return "Connecting securely to mqtt.pskreporter.info:1884.\nSubscription: \(monitor.filter.topic)" }
        if let result = monitor.snapshot {
            return "Window updated: \(result.endedAt.formatted(date: .abbreviated, time: .standard))\n\(result.count) \(result.unitLabel) in the last \(result.interval.label). \(result.filter.band.label), \(result.filter.mode.label).\nSubscription: \(monitor.filter.topic)\(lastReportDetail(monitor))"
        }
        return "Waiting for the live feed.\nSubscription: \(monitor.filter.topic)\(lastReportDetail(monitor))"
    }

    private static func lastReportDetail(_ monitor: MonitorModel) -> String {
        guard let arrived = monitor.lastReportAt else { return "\nNo reports have arrived in this session yet." }
        return "\nLast report arrived: \(arrived.formatted(date: .omitted, time: .standard))"
    }

}

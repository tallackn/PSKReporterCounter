import Combine
import Foundation
import PSKReporterCore

@main
struct Probe {
    @MainActor
    static func main() {
        if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--sandbox-preferences" {
            SandboxCheck.run(phase: CommandLine.arguments[2], blockedFile: CommandLine.arguments[3],
                callsign: CommandLine.arguments[4])
        }
        guard CommandLine.arguments.count >= 2, Callsign.isValid(CommandLine.arguments[1]) else {
            print("Usage: PSKReporterProbe CALLSIGN [SECONDS, default 45]")
            print("       PSKReporterProbe CALLSIGN --monitor [SECONDS, default 75]")
            exit(2)
        }
        let filter = ReceptionFilter(callsign: CommandLine.arguments[1])
        if CommandLine.arguments.dropFirst(2).first == "--monitor" {
            let seconds = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 0 : 75
            guard (5...300).contains(seconds) else {
                print("Choose between 5 and 300 seconds of live monitoring.")
                exit(2)
            }
            verifyMonitor(filter: filter, seconds: seconds)
            return
        }
        let duration = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 45 : 45
        let feed = LiveFeed()
        var connected = false
        var reports = 0
        var mismatches = 0
        var receivers = Set<String>()
        feed.onConnected = {
            connected = true
            print("Connected over TLS; broker accepted sender subscription: \(filter.topic)")
            fflush(stdout)
        }
        feed.onReport = { received in
            Task { @MainActor in
            let report = received.report
            reports += 1
            if !filter.matches(report) { mismatches += 1 }
            else { receivers.insert(report.receiver) }
            let delay = Int(Date().timeIntervalSince(report.timestamp))
            print("Report \(reports): sender=\(report.sender), receiver=\(report.receiver), band=\(report.band ?? "?"), mode=\(report.mode ?? "?"), SNR=\(report.signalToNoise.map(String.init(describing:)) ?? "missing") dB, age-on-arrival=\(delay)s")
            fflush(stdout)
        }
        }
        feed.onFailure = { error in print("Feed failed: \(error.localizedDescription)"); exit(1) }
        feed.onMalformedReport = { error in print("Invalid report: \(error.localizedDescription)"); exit(1) }
        do { try feed.connect(filter: filter) }
        catch { print(error.localizedDescription); exit(1) }
        let timer = Timer(timeInterval: max(5, min(duration, 300)), repeats: false) { _ in
            Task { @MainActor in
                feed.disconnect()
                print("Received \(reports) reports, \(receivers.count) distinct receivers, \(mismatches) sender mismatches.")
                exit(connected && mismatches == 0 ? 0 : 1)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.run()
    }

    /// Exercises the same model, real timer and feed used by the menu bar app.
    /// An isolated preferences suite leaves the user's app settings untouched.
    @MainActor
    private static func verifyMonitor(filter: ReceptionFilter, seconds: Int) {
        let suite = "PSKReporterCounter.Probe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(filter.callsign, forKey: "callsign")
        defaults.set(filter.band.rawValue, forKey: "band")
        defaults.set(filter.mode.rawValue, forKey: "mode")
        defaults.set(1, forKey: "intervalMinutes")
        defaults.set(true, forKey: "monitoringEnabled")
        let monitor = MonitorModel(defaults: defaults)
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Verify live PSK Reporter counting")
        var subscriptions = Set<AnyCancellable>()
        var updates = 0
        var deadline: Date?
        var previous: [ReceivedReception]?
        var peakCount = 0
        var sawSignals = false

        func finish(_ code: Int32) {
            monitor.shutdown()
            defaults.removePersistentDomain(forName: suite)
            ProcessInfo.processInfo.endActivity(activity)
            fflush(stdout)
            exit(code)
        }

        monitor.$isConnected.removeDuplicates().filter { $0 }.sink { _ in
            deadline = Date().addingTimeInterval(Double(seconds))
            print("Connected; monitoring \(filter.topic) for \(seconds) seconds with a sliding one-minute window.")
            fflush(stdout)
        }.store(in: &subscriptions)
        monitor.$feedIssue.compactMap { $0 }.sink { issue in
            print("Monitor failed: \(issue.detail)")
            finish(1)
        }.store(in: &subscriptions)
        monitor.$snapshot.compactMap { $0 }.sink { snapshot in
            // Published values notify before assignment, as in StatusItemController.
            DispatchQueue.main.async {
                updates += 1
                peakCount = max(peakCount, snapshot.count)
                sawSignals = sawSignals || snapshot.signalSummary != nil
                guard monitor.menuTitle == String(snapshot.count),
                      snapshot.arrivalBins.reduce(0, { $0 + $1.count }) == snapshot.count,
                      snapshot.signalSummary?.sampleCount ?? 0 == snapshot.selectedReports.compactMap(\.report.signalToNoise).count else {
                    print("The counter and graph data do not match.")
                    finish(1)
                    return
                }
                if previous != snapshot.selectedReports {
                    print("\(snapshot.endedAt.ISO8601Format()): \(snapshot.count) stations; histogram total=\(snapshot.arrivalBins.reduce(0, { $0 + $1.count })); SNR samples=\(snapshot.signalSummary?.sampleCount ?? 0); median=\(snapshot.signalSummary?.median.description ?? "none").")
                    print("Receivers: \(snapshot.receivers.sorted().joined(separator: ", "))")
                    previous = snapshot.selectedReports
                    fflush(stdout)
                }
                if let deadline, snapshot.endedAt >= deadline {
                    print("Verified \(updates) live updates in \(seconds) seconds. Peak stations=\(peakCount); received SNR=\(sawSignals).")
                    finish(0)
                }
            }
        }.store(in: &subscriptions)
        let timeout = Timer(timeInterval: Double(seconds + 35), repeats: false) { _ in
            Task { @MainActor in
                print("Timed out before live monitoring completed.")
                finish(1)
            }
        }
        RunLoop.main.add(timeout, forMode: .common)
        monitor.beginScheduling()
        withExtendedLifetime(subscriptions) { RunLoop.main.run() }
    }
}

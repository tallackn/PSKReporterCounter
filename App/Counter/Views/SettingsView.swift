import PSKReporterCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: MonitorModel
    @ObservedObject var login: LoginItemController
    @State private var callsign = ""
    @State private var interval: ReportingInterval = .fifteen
    @State private var band: RadioBand = .all
    @State private var mode: OperatingMode = .all
    @State private var countUniqueStations = true

    private var validCallsign: Bool { Callsign.isValid(callsign) }
    private var changed: Bool { ReceptionFilter(callsign: callsign, band: band, mode: mode) != monitor.filter
        || interval != monitor.interval || countUniqueStations != monitor.countUniqueStations }
    private var isActive: Bool { monitor.isRunning && monitor.isConfigured }
    private var statusColour: Color { monitor.activeIssue != nil ? .orange : (isActive ? .green : .secondary) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 15) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PSK Reporter Counter").font(.title2.weight(.semibold))
                        Text("Reception reports in your menu bar").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                MonitoringSummaryView(snapshot: monitor.snapshot, title: monitor.statusTitle, statusColour: statusColour,
                    isActive: isActive, isConnecting: monitor.isConnecting, canToggle: monitor.isConfigured && !changed,
                    toggleMonitoring: toggleMonitoring)
                MonitoringSettingsView(callsign: $callsign, interval: $interval, band: $band, mode: $mode,
                    countUniqueStations: $countUniqueStations,
                    actionTitle: isActive ? "Apply" : "Save and Start", canApply: validCallsign && (changed || !isActive),
                    focusCallsign: !monitor.isConfigured, apply: applySettings)
                BehaviourSettingsView(hideDockIcon: $monitor.hideDockIcon,
                    launchAtLogin: Binding(get: { login.isOn }, set: { login.setEnabled($0) }),
                    isUpdating: login.isUpdating, statusDescription: login.description,
                    showLoginSettings: login.status == .requiresApproval || login.status == .notFound,
                    openLoginSettings: login.openSystemSettings)
                StatusSettingsView(presentation: MonitorStatusPresentation(monitor: monitor),
                    canReconnect: monitor.canReconnect && !changed, reconnect: monitor.reconnect,
                    dismissIssue: { monitor.settingsIssue = nil })
                HStack(alignment: .top) {
                    Text("Left-click the menu bar icon for live graphs. Right-click for Settings, Reconnect and Quit.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Link("PSK Reporter", destination: URL(string: "https://pskreporter.info/")!).font(.caption)
                }
            }.padding(24)
        }
        .frame(width: 620)
        .onAppear(perform: loadSettings)
    }

    private func loadSettings() {
        callsign = monitor.callsign
        interval = monitor.interval
        band = monitor.filter.band
        mode = monitor.filter.mode
        countUniqueStations = monitor.countUniqueStations
        login.refresh()
    }

    private func toggleMonitoring() {
        if isActive { monitor.stop() } else { monitor.start() }
    }

    private func applySettings() {
        guard validCallsign else { return }
        callsign = Callsign.normalise(callsign)
        monitor.apply(filter: ReceptionFilter(callsign: callsign, band: band, mode: mode), interval: interval,
            countUniqueStations: countUniqueStations)
        if !monitor.isRunning { monitor.start() }
    }
}

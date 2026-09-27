import Combine
import Foundation
import PSKReporterCore
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var isUpdating = false
    private weak var monitor: MonitorModel?

    init(monitor: MonitorModel) { self.monitor = monitor }

    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var description: String {
        switch status {
        case .enabled: return "Enabled. PSK Reporter Counter will open when you log in."
        case .requiresApproval: return "Approval is required in System Settings > General > Login Items."
        case .notFound: return "macOS could not find this app. Move it to Applications, then try again."
        case .notRegistered: return "Disabled."
        @unknown default: return "macOS returned an unknown login item status."
        }
    }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false; refresh() }
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try await SMAppService.mainApp.unregister() }
                monitor?.settingsIssue = nil
            } catch {
                monitor?.settingsIssue = MonitorIssue(error: error,
                    context: "Could not \(enabled ? "enable" : "disable") launch at login.\nInstall the app in Applications before enabling this setting.", at: Date())
            }
        }
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

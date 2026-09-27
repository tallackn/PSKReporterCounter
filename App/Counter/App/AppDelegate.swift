import AppKit
import Combine
import OSLog
import PSKReporterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = MonitorModel()
    private let logger = Logger(subsystem: "com.tallackn.PSKReporterCounter", category: "Lifecycle")
    private lazy var login = LoginItemController(monitor: monitor)
    private lazy var settingsWindow = SettingsWindowController(monitor: monitor, login: login)
    private lazy var aboutWindow = InformationWindowController(title: "About PSK Reporter Counter",
        size: NSSize(width: 720, height: 680),
        content: AboutView(information: AppInformation(), openHelp: { [weak self] in self?.showHelp() }))
    private lazy var helpWindow = InformationWindowController(title: "PSK Reporter Counter Help",
        size: NSSize(width: 860, height: 680),
        content: HelpGuideView(openSettings: { [weak self] in self?.showSettings() }))
    private var statusController: StatusItemController?
    private var menuController: ApplicationMenuController?
    private var observations = Set<AnyCancellable>()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var monitoringActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        statusController = StatusItemController(monitor: monitor,
            openSettings: { [weak self] in self?.showSettings() },
            openAbout: { [weak self] in self?.showAbout() }, openHelp: { [weak self] in self?.showHelp() })
        menuController = ApplicationMenuController(openSettings: { [weak self] in self?.showSettings() },
            openGraphs: { [weak self] in self?.statusController?.showGraphs() },
            openAbout: { [weak self] in self?.showAbout() }, openHelp: { [weak self] in self?.showHelp() })
        monitor.$hideDockIcon.removeDuplicates().sink { hidden in
            NSApp.setActivationPolicy(hidden ? .accessory : .regular)
        }.store(in: &observations)
        monitor.$isRunning.combineLatest(monitor.$filter)
            .map { running, filter in running && Callsign.isValid(filter.callsign) }
            .removeDuplicates()
            .sink { [weak self] in self?.setMonitoringActivity($0) }
            .store(in: &observations)
        let notifications = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(notifications.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.monitor.suspend() }
        })
        workspaceObservers.append(notifications.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.monitor.resume() }
        })
        monitor.beginScheduling()
        logger.info("App launched, version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", privacy: .public)")
        if !monitor.isConfigured { showSettings() }
    }

    func applicationDidBecomeActive(_ notification: Notification) { login.refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.shutdown()
        setMonitoringActivity(false)
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    private func showSettings() {
        statusController?.closeGraphs()
        settingsWindow.show()
    }

    private func showAbout() { statusController?.closeGraphs(); aboutWindow.show() }
    private func showHelp() { statusController?.closeGraphs(); helpWindow.show() }

    private func setMonitoringActivity(_ active: Bool) {
        if active && monitoringActivity == nil {
            monitoringActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Receive PSK Reporter reports while monitoring")
        } else if !active, let activity = monitoringActivity {
            ProcessInfo.processInfo.endActivity(activity)
            monitoringActivity = nil
        }
    }
}

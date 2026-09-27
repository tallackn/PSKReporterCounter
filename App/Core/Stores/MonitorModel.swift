import Combine
import Foundation

public struct MonitorIssue: Equatable {
    public let summary: String
    public let detail: String
    public let occurredAt: Date
    public init(error: Error, context: String, at date: Date) {
        let error = error as NSError
        summary = error.localizedDescription
        detail = "\(context)\n\(error.localizedDescription)\n\(error.localizedFailureReason ?? "")\nDomain: \(error.domain) · Code: \(error.code)"
        occurredAt = date
    }
}

@MainActor
public final class MonitorModel: ObservableObject {
    @Published public private(set) var filter: ReceptionFilter
    @Published public private(set) var interval: ReportingInterval
    @Published public private(set) var countUniqueStations: Bool
    @Published public private(set) var isRunning: Bool
    @Published public private(set) var isConnecting = false
    @Published public private(set) var isConnected = false
    @Published public private(set) var snapshot: ListenerSnapshot?
    @Published public private(set) var feedIssue: MonitorIssue?
    @Published public private(set) var retryAt: Date?
    @Published public private(set) var coverageStartedAt: Date?
    @Published public private(set) var lastReportAt: Date?
    @Published public private(set) var now: Date
    @Published public var settingsIssue: MonitorIssue?
    @Published public var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: "hideDockIcon") }
    }

    private let defaults: UserDefaults
    private let clock: () -> Date
    private let makeFeed: () -> LiveFeedConnection
    private var feed: LiveFeedConnection?
    private var timer: Timer?
    private var pipeline: ReceptionPipeline?
    private var calculation: UUID?
    private var configurationRevision = UUID()
    private var generation = UUID()
    private var retryDelay: TimeInterval = 5
    private var suspended = false
    private var lastTick: Date?

    public init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init, makeFeed: (() -> LiveFeedConnection)? = nil) {
        self.defaults = defaults
        self.clock = clock
        self.makeFeed = makeFeed ?? { LiveFeed() }
        defaults.register(defaults: ["intervalMinutes": 15, "hideDockIcon": false, "countUniqueStations": true])
        filter = ReceptionFilter(callsign: defaults.string(forKey: "callsign") ?? "",
            band: RadioBand(rawValue: defaults.string(forKey: "band") ?? "+") ?? .all,
            mode: OperatingMode(rawValue: defaults.string(forKey: "mode") ?? "+") ?? .all)
        interval = ReportingInterval(rawValue: defaults.integer(forKey: "intervalMinutes")) ?? .fifteen
        countUniqueStations = defaults.bool(forKey: "countUniqueStations")
        // Stop pauses this session. A configured app listens on every launch.
        isRunning = true
        hideDockIcon = defaults.bool(forKey: "hideDockIcon")
        now = clock()
    }

    public var callsign: String { filter.callsign }
    public var isConfigured: Bool { Callsign.isValid(callsign) }
    public var activeIssue: MonitorIssue? { feedIssue ?? settingsIssue }
    public var coverageCompletesAt: Date? { coverageStartedAt?.addingTimeInterval(interval.seconds) }
    public var isFillingWindow: Bool { isConnected && coverageCompletesAt.map { now < $0 } == true }
    public var menuTitle: String {
        guard isConfigured, isRunning else { return "⛔️" }
        if activeIssue != nil { return "⚠️" }
        return snapshot.map { String($0.count) } ?? "…"
    }

    public var statusTitle: String {
        if !isConfigured { return "Not configured" }
        if !isRunning { return "Stopped" }
        if suspended { return "Paused while your Mac sleeps" }
        if isConnecting { return "Connecting to PSK Reporter" }
        if feedIssue != nil { return isConnected ? "Collecting after an interruption" : "Connection error" }
        if settingsIssue != nil { return "Settings need attention" }
        if snapshot != nil { return "Monitoring \(callsign)" }
        return "Waiting for the live feed"
    }

    public var tooltip: String {
        if !isConfigured { return "PSK Reporter Counter: enter a callsign in Settings." }
        if !isRunning { return "PSK Reporter Counter is stopped. Open the menu to start." }
        if let issue = activeIssue { return "PSK Reporter Counter: \(issue.summary). Open Settings for details." }
        if let snapshot {
            let coverage = isFillingWindow ? " The window is filling since connecting." : ""
            return "\(filter.description): \(snapshot.count) \(snapshot.unitLabel) in the last \(interval.label). Updated every second.\(coverage)"
        }
        return "Connecting to the feed for \(callsign)…"
    }

    public func beginScheduling() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        if isRunning && isConfigured { connect() }
    }

    public func apply(filter: ReceptionFilter, interval: ReportingInterval, countUniqueStations: Bool? = nil) {
        let countUniqueStations = countUniqueStations ?? self.countUniqueStations
        guard filter != self.filter || interval != self.interval || countUniqueStations != self.countUniqueStations else { return }
        self.countUniqueStations = countUniqueStations
        defaults.set(countUniqueStations, forKey: "countUniqueStations")
        if filter == self.filter {
            let date = clock()
            let previousDuration = self.interval.seconds
            self.interval = interval
            configurationRevision = UUID()
            defaults.set(interval.rawValue, forKey: "intervalMinutes")
            if isConnected {
                // Increasing the window cannot restore history already pruned.
                coverageStartedAt = max(coverageStartedAt ?? date, date.addingTimeInterval(-previousDuration))
                now = date
                Task { @MainActor [weak self] in await self?.tick() }
            } else { snapshot = nil }
            return
        }
        disconnect()
        self.filter = filter
        self.interval = interval
        defaults.set(filter.callsign, forKey: "callsign")
        defaults.set(filter.band.rawValue, forKey: "band")
        defaults.set(filter.mode.rawValue, forKey: "mode")
        defaults.set(interval.rawValue, forKey: "intervalMinutes")
        snapshot = nil
        feedIssue = nil
        lastReportAt = nil
        retryDelay = 5
        if isRunning && isConfigured { connect() }
    }

    public func start() {
        guard isConfigured else { return }
        isRunning = true
        snapshot = nil
        feedIssue = nil
        retryDelay = 5
        connect()
    }

    public func stop() {
        isRunning = false
        disconnect()
        feedIssue = nil
    }

    public var canReconnect: Bool { isRunning && isConfigured && !isConnecting && !suspended }
    public func reconnect() {
        guard canReconnect else { return }
        snapshot = nil
        connect()
    }

    public func suspend() {
        suspended = true
        disconnect()
        if isRunning && isConfigured {
            feedIssue = MonitorIssue(error: ReporterError("Reception paused during sleep", detail: "The live window will refill after waking."), context: "The feed cannot deliver reports while this Mac is asleep.", at: clock())
        }
    }

    public func resume() {
        suspended = false
        lastTick = nil
        if isRunning && isConfigured { connect() }
    }

    public func shutdown() {
        timer?.invalidate()
        timer = nil
        disconnect()
    }

    public func tick() async {
        guard calculation == nil else { return }
        now = clock()
        defer { lastTick = now }
        guard !suspended, isRunning, isConfigured else { return }
        if let lastTick, now < lastTick || now.timeIntervalSince(lastTick) > 10 {
            if isConnected {
                feedIssue = MonitorIssue(error: ReporterError("Collection was interrupted", detail: "A clock change or pause interrupted the live window."), context: "The warning clears when the window has refilled.", at: now)
                pipeline?.reset()
                coverageStartedAt = now
            }
        }
        if let retryAt, now >= retryAt, !isConnecting, !isConnected { connect(); return }
        guard isConnected, let pipeline else { return }
        let calculationID = UUID()
        calculation = calculationID
        defer { if calculation == calculationID { calculation = nil } }
        let generation = generation
        let revision = configurationRevision
        let result = await pipeline.snapshot(interval: interval, countUniqueStations: countUniqueStations, at: now)
        guard self.generation == generation, configurationRevision == revision, isConnected else { return }
        switch result {
        case .success(let update):
            snapshot = update.snapshot
            if lastReportAt != update.lastReportAt { lastReportAt = update.lastReportAt }
            if !isFillingWindow { feedIssue = nil; retryDelay = 5 }
        case .failure(let error): failed(error)
        }
    }

    private func connect() {
        disconnect()
        guard isRunning, isConfigured, !suspended else { return }
        isConnecting = true
        let generation = generation
        let pipeline = ReceptionPipeline(filter: filter)
        self.pipeline = pipeline
        let feed = makeFeed()
        self.feed = feed
        feed.onConnected = { [weak self] in
            guard let self, self.generation == generation, self.isRunning else { return }
            self.isConnecting = false
            self.isConnected = true
            self.now = self.clock()
            self.coverageStartedAt = self.now
            self.lastTick = self.now
            self.lastReportAt = nil
            self.snapshot = ListenerSnapshot(reports: [], filter: self.filter, interval: self.interval, countUniqueStations: self.countUniqueStations, endedAt: self.now)
        }
        feed.onReport = { report in pipeline.receive(report) }
        feed.onFailure = { [weak self] error in
            guard let self, self.generation == generation else { return }
            self.failed(error)
        }
        feed.onMalformedReport = { [weak self] error in
            guard let self, self.generation == generation else { return }
            self.feedIssue = MonitorIssue(error: error, context: "An unreadable report interrupted the live window.", at: self.clock())
            self.configurationRevision = UUID()
            self.pipeline?.reset()
            self.coverageStartedAt = self.clock()
            self.now = self.clock()
            self.snapshot = ListenerSnapshot(reports: [], filter: self.filter, interval: self.interval, countUniqueStations: self.countUniqueStations, endedAt: self.now)
        }
        do { try feed.connect(filter: filter) }
        catch { failed(error) }
    }

    private func failed(_ error: Error) {
        disconnect()
        feedIssue = MonitorIssue(error: error, context: "Feed: mqtt.pskreporter.info:1884 (TLS)\nSender subscription: \(filter.topic)\nThe warning clears when a full live window has been collected after reconnecting.", at: clock())
        retryAt = clock().addingTimeInterval(retryDelay)
        retryDelay = min(retryDelay * 2, 300)
    }

    private func disconnect() {
        generation = UUID()
        calculation = nil
        feed?.disconnect()
        feed = nil
        isConnecting = false
        isConnected = false
        coverageStartedAt = nil
        retryAt = nil
        pipeline = nil
    }
}

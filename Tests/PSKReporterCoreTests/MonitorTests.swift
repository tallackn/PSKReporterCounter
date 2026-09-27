import XCTest
@testable import PSKReporterCore

@MainActor
private final class FakeFeed: LiveFeedConnection {
    var onConnected: (() -> Void)?
    var onReport: (@Sendable (ReceivedReception) -> Void)?
    var onFailure: ((Error) -> Void)?
    var onMalformedReport: ((Error) -> Void)?
    var requestedFilter: ReceptionFilter?
    var disconnected = false
    func connect(filter: ReceptionFilter) throws { requestedFilter = filter }
    func disconnect() { disconnected = true }
}

@MainActor
private final class Fixture {
    var now = Date(timeIntervalSince1970: 1_790_000_000)
    var feeds: [FakeFeed] = []
    let suite = "PSKReporterCounter.Tests.\(UUID().uuidString)"
    lazy var defaults = UserDefaults(suiteName: suite)!
    lazy var model = MonitorModel(defaults: defaults, clock: { [unowned self] in self.now }, makeFeed: { [unowned self] in
        let feed = FakeFeed()
        self.feeds.append(feed)
        return feed
    })
    var feed: FakeFeed { feeds.last! }
    func start(interval: ReportingInterval = .one) {
        model.apply(filter: ReceptionFilter(callsign: "ZL1ABC"), interval: interval)
        feed.onConnected?()
    }
    func advance(_ seconds: Int) async {
        for _ in 0..<seconds { now = now.addingTimeInterval(1); await model.tick() }
    }
    func report(_ receiver: String, age: Double = 0, sender: String = "ZL1ABC") {
        feed.onReport?(ReceivedReception(report: Reception(sender: sender, receiver: receiver, timestamp: now.addingTimeInterval(-age)), receivedAt: now))
    }
    func cleanUp() { model.shutdown(); defaults.removePersistentDomain(forName: suite) }
}

final class MonitorTests: XCTestCase {
    @MainActor func testUnconfiguredDoesNotConnectAndShowsStopSymbol() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.beginScheduling()
        XCTAssertEqual(f.model.menuTitle, "⛔️")
        XCTAssertTrue(f.feeds.isEmpty)
        XCTAssertEqual(f.model.interval, .fifteen)
        XCTAssertTrue(f.model.countUniqueStations)
        XCTAssertEqual(f.model.filter.band, .all)
        XCTAssertEqual(f.model.filter.mode, .all)
    }

    @MainActor func testCountRefreshesOncePerTickAndExpiresByArrival() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10); f.report("G1AAA"); f.report("g1aaa"); f.report("VK2BBB")
        XCTAssertEqual(f.model.menuTitle, "0")
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot?.count, 2)
        XCTAssertEqual(f.model.menuTitle, "2")
        await f.advance(9); f.report("N1CCC")
        XCTAssertEqual(f.model.menuTitle, "2")
        await f.advance(1)
        XCTAssertEqual(f.model.menuTitle, "3")
        await f.advance(49)
        XCTAssertEqual(f.model.snapshot?.receivers, ["N1CCC"])
        await f.advance(10)
        XCTAssertEqual(f.model.menuTitle, "0")
    }

    @MainActor func testFiveMinuteWindowStillUpdatesEverySecond() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start(interval: .five)
        let expected = f.now.addingTimeInterval(300)
        XCTAssertEqual(f.model.coverageCompletesAt, expected)
        XCTAssertTrue(f.model.isFillingWindow)
        await f.advance(20); f.report("G1AAA")
        await f.advance(279)
        XCTAssertEqual(f.model.menuTitle, "1")
        XCTAssertTrue(f.model.isFillingWindow)
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot?.count, 1)
        XCTAssertFalse(f.model.isFillingWindow)
        await f.advance(20)
        XCTAssertEqual(f.model.menuTitle, "0")
    }

    @MainActor func testCounterAndGraphsShareOneLiveSnapshotAcrossMinuteBoundaries() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10); f.report("G1AAA")
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot?.arrivalBins.reduce(0) { $0 + $1.count }, 1)
        XCTAssertEqual(f.model.snapshot?.endedAt, f.now)
        XCTAssertEqual(f.model.menuTitle, "1")
        await f.advance(49)
        XCTAssertEqual(f.model.menuTitle, "1")
        XCTAssertEqual(f.model.snapshot?.count, 1)
        f.report("G2BBB")
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot?.count, 2)
        XCTAssertEqual(f.model.menuTitle, "2")
        await f.advance(9)
        XCTAssertEqual(f.model.snapshot?.receivers, ["G2BBB"])
    }

    @MainActor func testWindowAdvancesAndExpiresEvenWithoutNewReports() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(20); f.report("G1AAA")
        await f.advance(10)
        XCTAssertEqual(f.model.snapshot?.receivers, ["G1AAA"])
        await f.advance(50)
        XCTAssertEqual(f.model.snapshot?.count, 0)
        XCTAssertEqual(f.model.snapshot?.endedAt, f.now)
    }

    @MainActor func testGraphHistoryIsClearedOnFilterChangeAndDisconnect() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10); f.report("G1AAA"); await f.advance(1)
        let before = f.model.snapshot
        f.feed.onFailure?(ReporterError("Offline", detail: "Test interruption"))
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot, before)
        f.model.apply(filter: ReceptionFilter(callsign: "ZL2DEF"), interval: .five)
        XCTAssertNil(f.model.snapshot)
        f.feed.onConnected?()
        XCTAssertEqual(f.model.snapshot?.count, 0)
    }

    @MainActor func testResizingWindowUsesAvailableHistoryWithoutReconnecting() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10); f.report("G1AAA")
        await f.advance(100); f.report("G2BBB")
        await f.advance(10)
        let filter = f.model.filter
        let changedAt = f.now
        f.model.apply(filter: filter, interval: .five)
        await f.model.tick()
        XCTAssertEqual(f.feeds.count, 1)
        XCTAssertEqual(f.model.snapshot?.receivers, ["G2BBB"])
        XCTAssertEqual(f.model.coverageCompletesAt, changedAt.addingTimeInterval(240))
        await f.advance(51)
        f.model.apply(filter: filter, interval: .one)
        await f.model.tick()
        XCTAssertEqual(f.feeds.count, 1)
        XCTAssertEqual(f.model.menuTitle, "0")
        XCTAssertFalse(f.model.isFillingWindow)
    }

    @MainActor func testDelayedReportsCountByArrivalAndWrongSendersAreExcluded() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10)
        f.report("G1AAA", sender: "OTHER1")
        f.report("G2BBB", age: 300)
        f.report("G3CCC", age: 201)
        await f.advance(50)
        XCTAssertEqual(f.model.snapshot?.receivers, ["G2BBB", "G3CCC"])
    }

    @MainActor func testStopDisconnectsAndIgnoresOldCallbacks() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        let old = f.feed
        f.model.stop()
        old.onConnected?()
        old.onFailure?(ReporterError("Old error", detail: "Old session"))
        XCTAssertTrue(old.disconnected)
        XCTAssertFalse(f.model.isConnected)
        XCTAssertEqual(f.model.menuTitle, "⛔️")
        XCTAssertNil(f.model.retryAt)
    }

    @MainActor func testFilterChangeCreatesOneNarrowSubscriptionAndResetsPeriod() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        let old = f.feed
        await f.advance(10); f.report("G1AAA")
        let filter = ReceptionFilter(callsign: "ZL2DEF", band: .b40, mode: .ft4)
        f.model.apply(filter: filter, interval: .five)
        old.onConnected?()
        old.onReport?(ReceivedReception(report: Reception(sender: "ZL1ABC", receiver: "G1AAA", timestamp: f.now), receivedAt: f.now))
        XCTAssertTrue(old.disconnected)
        XCTAssertFalse(f.model.isConnected)
        XCTAssertNil(f.model.snapshot)
        XCTAssertEqual(f.feed.requestedFilter?.topic, "pskr/filter/v2/40m/FT4/ZL2DEF/#")
        f.feed.onConnected?()
        XCTAssertEqual(f.model.coverageCompletesAt, f.now.addingTimeInterval(300))
        XCTAssertEqual(f.defaults.string(forKey: "band"), "40m")
        XCTAssertEqual(f.defaults.string(forKey: "mode"), "FT4")
    }

    @MainActor func testFailureWarnsRetriesAndRequiresFullPeriodToRecover() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(20); f.report("G1AAA")
        f.feed.onFailure?(ReporterError("Network offline", detail: "Lost connection"))
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        XCTAssertTrue(f.model.tooltip.contains("Network offline"))
        XCTAssertTrue(f.model.feedIssue!.detail.contains("mqtt.pskreporter.info"))
        await f.advance(4)
        XCTAssertEqual(f.feeds.count, 1)
        await f.advance(1)
        XCTAssertEqual(f.feeds.count, 2)
        f.feed.onConnected?()
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        await f.advance(20); f.report("N1CCC")
        await f.advance(40)
        XCTAssertEqual(f.model.menuTitle, "1")
        XCTAssertNil(f.model.feedIssue)
        XCTAssertEqual(f.model.snapshot?.receivers, ["N1CCC"])
    }

    @MainActor func testMalformedReportInvalidatesThePeriod() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10); f.report("G1AAA")
        f.feed.onMalformedReport?(ReporterError("Invalid report", detail: "Missing timestamp"))
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        await f.advance(50)
        XCTAssertEqual(f.model.snapshot?.count, 0)
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        await f.advance(10)
        XCTAssertEqual(f.model.menuTitle, "0")
    }

    @MainActor func testSleepRestartsACompletePeriodWithoutCatchUp() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(20); f.report("G1AAA")
        f.model.suspend()
        XCTAssertTrue(f.feed.disconnected)
        f.now = f.now.addingTimeInterval(3600)
        f.model.resume()
        f.feed.onConnected?()
        XCTAssertEqual(f.model.coverageCompletesAt, f.now.addingTimeInterval(60))
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        await f.advance(60)
        XCTAssertEqual(f.model.menuTitle, "0")
    }

    @MainActor func testClockJumpClearsUnreliableHistoryAndWarns() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        f.now = f.now.addingTimeInterval(400)
        await f.model.tick()
        XCTAssertEqual(f.model.snapshot?.count, 0)
        XCTAssertEqual(f.model.menuTitle, "⚠️")
        XCTAssertEqual(f.model.coverageCompletesAt, f.now.addingTimeInterval(60))
    }

    @MainActor func testSettingsPersistAndStoppedStateWinsOverErrors() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start(interval: .ten)
        f.model.hideDockIcon = true
        f.model.stop()
        f.model.settingsIssue = MonitorIssue(error: ReporterError("Login item failed", detail: "Test failure"), context: "Launch at login", at: f.now)
        XCTAssertEqual(f.model.menuTitle, "⛔️")
        let restored = MonitorModel(defaults: f.defaults)
        XCTAssertEqual(restored.callsign, "ZL1ABC")
        XCTAssertEqual(restored.interval, .ten)
        XCTAssertTrue(restored.hideDockIcon)
        XCTAssertTrue(restored.isRunning)
        restored.shutdown()
    }

    @MainActor func testLaunchStartsSavedCallsignEvenIfPreviousSessionStopped() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        f.model.stop()
        // Older versions persisted this flag. It must not prevent auto-start.
        f.defaults.set(false, forKey: "monitoringEnabled")
        let feed = FakeFeed()
        let relaunched = MonitorModel(defaults: f.defaults, makeFeed: { feed })
        defer { relaunched.shutdown() }
        relaunched.beginScheduling()
        XCTAssertTrue(relaunched.isRunning)
        XCTAssertTrue(relaunched.isConnecting)
        XCTAssertEqual(feed.requestedFilter?.callsign, "ZL1ABC")
        feed.onConnected?()
        XCTAssertTrue(relaunched.isConnected)
    }

    @MainActor func testUniqueCountingCanChangeWithoutReconnectingOrLosingHistory() async {
        let f = Fixture(); defer { f.cleanUp() }
        f.start()
        await f.advance(10)
        f.report("G1AAA"); f.report("G1AAA"); f.report("G1AAA"); f.report("G2BBB")
        await f.advance(1)
        XCTAssertEqual(f.model.snapshot?.count, 2)
        f.model.apply(filter: f.model.filter, interval: .one, countUniqueStations: false)
        await f.model.tick()
        XCTAssertEqual(f.feeds.count, 1)
        XCTAssertEqual(f.model.snapshot?.count, 4)
        XCTAssertEqual(f.model.snapshot?.arrivalBins.reduce(0) { $0 + $1.count }, 4)
        let restored = MonitorModel(defaults: f.defaults)
        XCTAssertFalse(restored.countUniqueStations)
        restored.shutdown()
        f.model.apply(filter: f.model.filter, interval: .five)
        await f.model.tick()
        XCTAssertFalse(f.model.countUniqueStations)
        f.model.apply(filter: f.model.filter, interval: .five, countUniqueStations: true)
        await f.model.tick()
        XCTAssertEqual(f.model.snapshot?.count, 2)
        XCTAssertEqual(f.feeds.count, 1)
    }
}

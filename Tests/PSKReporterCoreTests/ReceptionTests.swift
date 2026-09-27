import XCTest
@testable import PSKReporterCore

final class ReceptionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func report(_ receiver: String, age: Double, sender: String = "ZL1ABC") -> ReceivedReception {
        ReceivedReception(report: Reception(sender: sender, receiver: receiver, timestamp: now.addingTimeInterval(-age - 180)), receivedAt: now.addingTimeInterval(-age))
    }

    func testCountDeduplicatesReceiversAndFiltersSenderAndPeriod() {
        let snapshot = ListenerSnapshot(reports: [
            report("G1AAA", age: 10), report("g1aaa", age: 20),
            report("VK2BBB", age: 59), report("N1CCC", age: 60),
            report("N2DDD", age: 120), report("G2EEE", age: -1),
            report("G3FFF", age: 10, sender: "OTHER1"), report("", age: 5)
        ], filter: ReceptionFilter(callsign: "zl1abc"), interval: .one, endedAt: now)
        XCTAssertEqual(snapshot.receivers, ["G1AAA", "VK2BBB"])
        XCTAssertEqual(snapshot.count, 2)
    }

    func testEachRefreshIsAnIndependentSnapshot() {
        let first = ListenerSnapshot(reports: [report("G1AAA", age: 10)], filter: ReceptionFilter(callsign: "ZL1ABC"), interval: .one, endedAt: now)
        let second = ListenerSnapshot(reports: [], filter: ReceptionFilter(callsign: "ZL1ABC"), interval: .one, endedAt: now.addingTimeInterval(60))
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 0)
    }

    func testDelayedReceptionsCountInTheIntervalWhenTheyArrive() {
        let delayed = ReceivedReception(report: Reception(sender: "ZL1ABC", receiver: "G1AAA", timestamp: now.addingTimeInterval(-201)), receivedAt: now.addingTimeInterval(-4))
        let snapshot = ListenerSnapshot(reports: [delayed], filter: ReceptionFilter(callsign: "ZL1ABC"), interval: .one, endedAt: now)
        XCTAssertEqual(snapshot.count, 1)
    }

    func testEverySupportedPeriodUsesTheMatchingCutoff() {
        XCTAssertEqual(ReportingInterval.allCases.map(\.rawValue), [1, 5, 10, 15, 30, 60, 120])
        for interval in ReportingInterval.allCases {
            let snapshot = ListenerSnapshot(reports: [report("G1AAA", age: interval.seconds - 1), report("G2BBB", age: interval.seconds)], filter: ReceptionFilter(callsign: "ZL1ABC"), interval: interval, endedAt: now)
            XCTAssertEqual(snapshot.count, 1, interval.label)
        }
    }

    func testCallsignValidationAllowsPortableCallsButRejectsWildcards() {
        for value in ["zl1abc", "  ZL1ABC/P\n", "F/ZL1ABC", "K1RA-4", "3D2CR"] { XCTAssertTrue(Callsign.isValid(value), value) }
        for value in ["", "ABC", "123", "A1", "ZL1 ABC", "ZL1ABC/#", "ZL1+", "ZL1ABC?", "/ZL1ABC", "ZL1ABC//P"] { XCTAssertFalse(Callsign.isValid(value), value) }
    }
}

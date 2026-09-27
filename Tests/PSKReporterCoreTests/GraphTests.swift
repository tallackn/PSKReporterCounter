import XCTest
@testable import PSKReporterCore

final class GraphTests: XCTestCase {
    private let end = Date(timeIntervalSince1970: 1_790_000_060)

    private func report(_ receiver: String, age: Double, snr: Double? = nil) -> ReceivedReception {
        ReceivedReception(report: Reception(sender: "ZL2NU", receiver: receiver,
            timestamp: end.addingTimeInterval(-300), signalToNoise: snr), receivedAt: end.addingTimeInterval(-age))
    }

    func testOnlyFirstReportPerStationContributesToBothGraphs() {
        let snapshot = ListenerSnapshot(reports: [report("G1AAA", age: 10, snr: 5),
            report("G1AAA", age: 50, snr: -20), report("G2BBB", age: 49.7, snr: -10),
            report("G1AAA", age: 30, snr: 0)], filter: ReceptionFilter(callsign: "ZL2NU"), interval: .one, endedAt: end)
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot.selectedReports.map(\.report.signalToNoise), [-20, -10])
        XCTAssertEqual(snapshot.arrivalBins.reduce(0) { $0 + $1.count }, 2)
        XCTAssertEqual(snapshot.arrivalBins.count, 1)
        XCTAssertEqual(snapshot.signalSummary?.median, -15)
    }

    func testNextReportBecomesFirstWhenEarlierReportLeavesTheWindow() {
        let reports = [report("G1AAA", age: 59, snr: -20), report("G1AAA", age: 10, snr: -8)]
        let initial = ListenerSnapshot(reports: reports, filter: ReceptionFilter(callsign: "ZL2NU"), interval: .one, endedAt: end)
        let later = ListenerSnapshot(reports: reports, filter: ReceptionFilter(callsign: "ZL2NU"), interval: .one, endedAt: end.addingTimeInterval(2))
        XCTAssertEqual(initial.signalSummary?.median, -20)
        XCTAssertEqual(later.signalSummary?.median, -8)
        XCTAssertEqual(later.count, 1)
    }

    func testMissingFirstSignalIsNotReplacedByADuplicateSignal() {
        let snapshot = ListenerSnapshot(reports: [report("G1AAA", age: 40), report("G1AAA", age: 10, snr: -8)],
            filter: ReceptionFilter(callsign: "ZL2NU"), interval: .one, endedAt: end)
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertNil(snapshot.signalSummary)
    }

    func testAllReportsContributeWhenUniqueCountingIsOff() {
        let reports = [report("G1AAA", age: 50, snr: -20), report("G1AAA", age: 10, snr: -8),
            report("G1AAA", age: 10, snr: -8), report("G2BBB", age: 5), report("G3CCC", age: 61, snr: 10)]
        let snapshot = ListenerSnapshot(reports: reports, filter: ReceptionFilter(callsign: "ZL2NU"),
            interval: .one, countUniqueStations: false, endedAt: end)
        XCTAssertEqual(snapshot.count, 4)
        XCTAssertEqual(snapshot.receivers.count, 2)
        XCTAssertEqual(snapshot.arrivalBins.reduce(0) { $0 + $1.count }, 4)
        XCTAssertEqual(snapshot.signalSummary?.sampleCount, 3)
        XCTAssertEqual(snapshot.signalSummary?.median, -8)
        XCTAssertEqual(Set(snapshot.selectedReports.map(\.id)).count, 4)
    }

    func testLongIntervalsKeepIndividualSecondsAndPreciseArrivals() {
        let arrivals = [report("G1AAA", age: 7199.75, snr: -10), report("G2BBB", age: 7198.25, snr: -8),
            report("G3CCC", age: 0.125, snr: -2)]
        let snapshot = ListenerSnapshot(reports: arrivals, filter: ReceptionFilter(callsign: "ZL2NU"), interval: .oneTwenty, endedAt: end)
        XCTAssertEqual(snapshot.selectedReports, arrivals)
        XCTAssertEqual(snapshot.arrivalBins.count, 3)
        XCTAssertTrue(snapshot.arrivalBins.allSatisfy { $0.endedAt.timeIntervalSince($0.startedAt) == 1 })
        XCTAssertEqual(snapshot.arrivalBins[1].id - snapshot.arrivalBins[0].id, 1)
    }

    func testBoxPlotQuartilesWhiskersAndOutlier() throws {
        let summary = try XCTUnwrap(SignalSummary(values: [-20, -19, -18, -17, -16, -15, -14, 10]))
        XCTAssertEqual(summary.sampleCount, 8)
        XCTAssertEqual(summary.lowerQuartile, -18.25)
        XCTAssertEqual(summary.median, -16.5)
        XCTAssertEqual(summary.upperQuartile, -14.75)
        XCTAssertEqual(summary.lowerWhisker, -20)
        XCTAssertEqual(summary.upperWhisker, -14)
        XCTAssertEqual(summary.outliers, [10])
    }

    func testEmptySingleAndIdenticalSignals() throws {
        XCTAssertNil(SignalSummary(values: [.nan, .infinity]))
        let single = try XCTUnwrap(SignalSummary(values: [-12]))
        XCTAssertEqual(single.lowerQuartile, -12)
        XCTAssertEqual(single.upperQuartile, -12)
        XCTAssertEqual(single.lowerWhisker, single.upperWhisker)
        XCTAssertTrue(single.outliers.isEmpty)
        let identical = try XCTUnwrap(SignalSummary(values: [-8, -8, -8, -8]))
        XCTAssertEqual(identical.median, -8)
        XCTAssertTrue(identical.outliers.isEmpty)
    }

    func testMissingAndInvalidSignalDoesNotDiscardReception() throws {
        for signal in ["null", "\"unavailable\"", "{}"] {
            let json = "{\"sc\":\"ZL2NU\",\"rc\":\"G1AAA\",\"t\":100,\"rp\":\(signal)}"
            XCTAssertNil(try Reception.decodeLive(Data(json.utf8)).signalToNoise)
        }
        let numeric = #"{"sc":"ZL2NU","rc":"G1AAA","t":100,"rp":-12}"#
        let string = #"{"sc":"ZL2NU","rc":"G1AAA","t":100,"rp":"-12.5"}"#
        XCTAssertEqual(try Reception.decodeLive(Data(numeric.utf8)).signalToNoise, -12)
        XCTAssertEqual(try Reception.decodeLive(Data(string.utf8)).signalToNoise, -12.5)
    }
}

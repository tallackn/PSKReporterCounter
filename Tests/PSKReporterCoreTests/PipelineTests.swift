import XCTest
@testable import PSKReporterCore

final class PipelineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testConcurrentReceiversDoNotLoseReports() async throws {
        let pipeline = ReceptionPipeline(filter: ReceptionFilter(callsign: "ZL2NU"))
        let now = now
        await withTaskGroup(of: Void.self) { tasks in
            for i in 0..<1_000 {
                tasks.addTask {
                    pipeline.receive(ReceivedReception(report: Reception(sender: "ZL2NU", receiver: "G\(i)TEST",
                        timestamp: now.addingTimeInterval(-180), signalToNoise: -10), receivedAt: now))
                }
            }
        }
        let update = try await pipeline.snapshot(interval: .one, at: now).get()
        XCTAssertEqual(update.snapshot.count, 1_000)
        XCTAssertEqual(update.snapshot.arrivalBins.reduce(0) { $0 + $1.count }, 1_000)
        XCTAssertEqual(update.snapshot.signalSummary?.sampleCount, 1_000)
        XCTAssertEqual(update.lastReportAt, now)
    }

    func testInboxOverflowIsReportedInsteadOfSilentlyDroppingData() async {
        let pipeline = ReceptionPipeline(filter: ReceptionFilter(callsign: "ZL2NU"), capacity: 2)
        for receiver in ["G1AAA", "G2BBB", "G3CCC"] {
            pipeline.receive(ReceivedReception(report: Reception(sender: "ZL2NU", receiver: receiver, timestamp: now), receivedAt: now))
        }
        let result = await pipeline.snapshot(interval: .one, at: now)
        guard case .failure(let error) = result else { return XCTFail("Expected an overflow error") }
        XCTAssertEqual(error.summary, "Too many reception reports")
    }

    func testReceivingDuringCalculationsKeepsEveryReport() async throws {
        let pipeline = ReceptionPipeline(filter: ReceptionFilter(callsign: "ZL2NU"))
        let now = now
        let calculations = Task {
            var previousCount = 0
            for _ in 0..<40 {
                let update = try await pipeline.snapshot(interval: .one, at: now).get()
                XCTAssertGreaterThanOrEqual(update.snapshot.count, previousCount)
                XCTAssertEqual(update.snapshot.arrivalBins.reduce(0) { $0 + $1.count }, update.snapshot.count)
                previousCount = update.snapshot.count
                await Task.yield()
            }
        }
        await withTaskGroup(of: Void.self) { tasks in
            for i in 0..<2_000 {
                tasks.addTask {
                    pipeline.receive(ReceivedReception(report: Reception(sender: "ZL2NU", receiver: "G\(i)TEST",
                        timestamp: now, signalToNoise: -15), receivedAt: now))
                }
            }
        }
        try await calculations.value
        let update = try await pipeline.snapshot(interval: .one, at: now).get()
        XCTAssertEqual(update.snapshot.count, 2_000)
    }

    func testResetRemovesHistoryAndKeepsSubsequentReports() async throws {
        let pipeline = ReceptionPipeline(filter: ReceptionFilter(callsign: "ZL2NU"))
        pipeline.receive(ReceivedReception(report: Reception(sender: "ZL2NU", receiver: "G1AAA", timestamp: now), receivedAt: now))
        _ = await pipeline.snapshot(interval: .one, at: now)
        pipeline.reset()
        pipeline.receive(ReceivedReception(report: Reception(sender: "ZL2NU", receiver: "G2BBB", timestamp: now), receivedAt: now))
        let update = try await pipeline.snapshot(interval: .one, at: now).get()
        XCTAssertEqual(update.snapshot.receivers, ["G2BBB"])
    }
}

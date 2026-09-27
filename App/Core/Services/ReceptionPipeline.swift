import Foundation

struct WindowUpdate: Sendable {
    let snapshot: ListenerSnapshot
    let lastReportAt: Date?
}

/// Only the small inbox is shared between threads, under its lock. History and
/// all sorting/statistics belong exclusively to the utility queue. Receiving a
/// report never waits for a histogram or box plot calculation to finish.
final class ReceptionPipeline: @unchecked Sendable {
    private let filter: ReceptionFilter
    private let capacity: Int
    private let queue = DispatchQueue(label: "com.tallackn.PSKReporterCounter.window", qos: .utility)
    private let lock = NSLock()
    private var inbox: [ReceivedReception] = [] // lock only
    private var overflowed = false             // lock only
    private var history: [ReceivedReception] = [] // utility queue only
    private var lastReportAt: Date?               // utility queue only

    init(filter: ReceptionFilter, capacity: Int = 200_000) {
        self.filter = filter
        self.capacity = capacity
    }

    func receive(_ report: ReceivedReception) {
        lock.lock()
        defer { lock.unlock() }
        guard inbox.count < capacity else { overflowed = true; return }
        inbox.append(report)
    }

    func reset() {
        lock.lock()
        inbox.removeAll()
        overflowed = false
        lock.unlock()
        queue.async { [self] in history.removeAll(); lastReportAt = nil }
    }

    func snapshot(interval: ReportingInterval, countUniqueStations: Bool = true, at date: Date) async -> Result<WindowUpdate, ReporterError> {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                dispatchPrecondition(condition: .onQueue(queue))
                lock.lock()
                let received = inbox
                let overflow = overflowed
                inbox = []
                overflowed = false
                lock.unlock()

                let cutoff = date.addingTimeInterval(-interval.seconds)
                history.removeAll { $0.receivedAt <= cutoff }
                let eligible = received.filter { filter.matches($0.report) && $0.receivedAt > cutoff }
                guard !overflow, history.count + eligible.count <= capacity else {
                    history.removeAll()
                    continuation.resume(returning: .failure(ReporterError("Too many reception reports",
                        detail: "The live window exceeded its bounded report buffer. The count would be incomplete.")))
                    return
                }
                history.append(contentsOf: eligible)
                if let newest = received.map(\.receivedAt).max() { lastReportAt = max(lastReportAt ?? newest, newest) }
                let result = ListenerSnapshot(reports: history, filter: filter, interval: interval, countUniqueStations: countUniqueStations, endedAt: date)
                continuation.resume(returning: .success(WindowUpdate(snapshot: result, lastReportAt: lastReportAt)))
            }
        }
    }
}

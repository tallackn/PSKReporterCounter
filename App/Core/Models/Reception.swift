import Foundation

public enum Callsign {
    public static func normalise(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public static func isValid(_ value: String) -> Bool {
        let call = normalise(value)
        return call.range(of: "^[A-Z0-9]+(?:[/-][A-Z0-9]+)*$", options: .regularExpression) != nil
            && (3...32).contains(call.count)
            && call.range(of: "[A-Z]", options: .regularExpression) != nil
            && call.range(of: "[0-9]", options: .regularExpression) != nil
    }
}

public enum ReportingInterval: Int, CaseIterable, Identifiable, Sendable {
    case one = 1, five = 5, ten = 10, fifteen = 15, thirty = 30, sixty = 60, oneTwenty = 120
    public var id: Int { rawValue }
    public var seconds: TimeInterval { Double(rawValue * 60) }
    public var label: String { "\(rawValue) \(rawValue == 1 ? "minute" : "minutes")" }
}

public enum RadioBand: String, CaseIterable, Identifiable, Sendable {
    case all = "+", b160 = "160m", b80 = "80m", b60 = "60m", b40 = "40m", b30 = "30m"
    case b20 = "20m", b17 = "17m", b15 = "15m", b12 = "12m", b10 = "10m"
    case b6 = "6m", b4 = "4m", b2 = "2m", b70cm = "70cm", b23cm = "23cm"
    public var id: String { rawValue }
    public var label: String { self == .all ? "All bands" : rawValue }
}

public enum OperatingMode: String, CaseIterable, Identifiable, Sendable {
    case all = "+", ft8 = "FT8", ft4 = "FT4", cw = "CW", mfsk = "MFSK"
    case jt9 = "JT9", jt65 = "JT65", psk31 = "PSK31", psk63 = "PSK63"
    case rtty = "RTTY", olivia = "OLIVIA", ssb = "SSB", js8 = "JS8"
    case q65 = "Q65", msk144 = "MSK144", wspr = "WSPR"
    public var id: String { rawValue }
    public var label: String { self == .all ? "All modes" : rawValue }
}

public struct ReceptionFilter: Equatable, Sendable {
    public let callsign: String
    public let band: RadioBand
    public let mode: OperatingMode
    public init(callsign: String, band: RadioBand = .all, mode: OperatingMode = .all) {
        self.callsign = Callsign.normalise(callsign)
        self.band = band
        self.mode = mode
    }
    public var topic: String { "pskr/filter/v2/\(band.rawValue)/\(mode.rawValue)/\(callsign)/#" }
    public var description: String { "\(callsign) · \(band.label) · \(mode.label)" }
    public func matches(_ report: Reception) -> Bool {
        report.sender == callsign
            && (band == .all || report.band?.lowercased() == band.rawValue.lowercased())
            && (mode == .all || report.mode?.uppercased() == mode.rawValue)
    }
}

public struct ReporterError: LocalizedError, Sendable {
    public let summary: String
    public let detail: String
    public init(_ summary: String, detail: String) { self.summary = summary; self.detail = detail }
    public var errorDescription: String? { summary }
    public var failureReason: String? { detail }
}

public struct Reception: Equatable, Sendable {
    public let sender: String
    public let receiver: String
    public let timestamp: Date
    public let band: String?
    public let mode: String?
    public let signalToNoise: Double?

    public init(sender: String, receiver: String, timestamp: Date, band: String? = nil, mode: String? = nil, signalToNoise: Double? = nil) {
        self.sender = Callsign.normalise(sender)
        self.receiver = Callsign.normalise(receiver)
        self.timestamp = timestamp
        self.band = band
        self.mode = mode
        self.signalToNoise = signalToNoise.flatMap { $0.isFinite ? $0 : nil }
    }

    public static func decodeLive(_ data: Data) throws -> Reception {
        struct Signal: Decodable {
            let value: Double?
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let number = (try? container.decode(Double.self))
                    ?? (try? container.decode(String.self)).flatMap(Double.init)
                value = number.flatMap { $0.isFinite ? $0 : nil }
            }
        }
        struct Spot: Decodable { let sc: String; let rc: String; let t: Double; let b: String?; let md: String?; let rp: Signal? }
        do {
            let spot = try JSONDecoder().decode(Spot.self, from: data)
            guard !Callsign.normalise(spot.sc).isEmpty, !Callsign.normalise(spot.rc).isEmpty, spot.t.isFinite, spot.t > 0 else {
                throw ReporterError("Invalid reception report", detail: "The live report has an empty callsign or an invalid reception timestamp.")
            }
            return Reception(sender: spot.sc, receiver: spot.rc, timestamp: Date(timeIntervalSince1970: spot.t), band: spot.b, mode: spot.md, signalToNoise: spot.rp?.value)
        } catch let error as ReporterError { throw error }
        catch { throw ReporterError("Cannot read a live report", detail: error.localizedDescription) }
    }
}

public struct ReceivedReception: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let report: Reception
    public let receivedAt: Date
    public init(report: Reception, receivedAt: Date) {
        self.id = UUID()
        self.report = report
        self.receivedAt = receivedAt
    }
}

/// A snapshot of reports arriving within a sliding window. Receiver
/// timestamps can be several minutes older because reporting is batched upstream.
public struct ListenerSnapshot: Equatable, Sendable {
    public let filter: ReceptionFilter
    public let interval: ReportingInterval
    public let endedAt: Date
    public let countUniqueStations: Bool
    public let receivers: Set<String>
    public let selectedReports: [ReceivedReception]
    public let arrivalBins: [ArrivalBin]
    public let signalSummary: SignalSummary?
    public var count: Int { selectedReports.count }
    public var unitLabel: String { countUniqueStations ? (count == 1 ? "unique station" : "unique stations") : (count == 1 ? "report" : "reports") }
    public var callsign: String { filter.callsign }
    public var startedAt: Date { endedAt.addingTimeInterval(-interval.seconds) }

    public init(reports: [ReceivedReception], filter: ReceptionFilter, interval: ReportingInterval, countUniqueStations: Bool = true, endedAt now: Date) {
        self.filter = filter
        self.interval = interval
        self.endedAt = now
        self.countUniqueStations = countUniqueStations
        let cutoff = now.addingTimeInterval(-interval.seconds)
        let eligible = reports.filter { filter.matches($0.report) && !$0.report.receiver.isEmpty
            && $0.receivedAt > cutoff && $0.receivedAt <= now }
        let selected: [ReceivedReception]
        if countUniqueStations {
            var earliest: [String: ReceivedReception] = [:]
            for report in eligible {
                if let previous = earliest[report.report.receiver], previous.receivedAt <= report.receivedAt { continue }
                earliest[report.report.receiver] = report
            }
            selected = Array(earliest.values)
        } else {
            selected = eligible
        }
        selectedReports = selected.sorted {
            $0.receivedAt == $1.receivedAt ? $0.report.receiver < $1.report.receiver : $0.receivedAt < $1.receivedAt
        }
        receivers = Set(selectedReports.map(\.report.receiver))
        arrivalBins = ArrivalBin.make(from: selectedReports)
        signalSummary = SignalSummary(values: selectedReports.compactMap(\.report.signalToNoise))
    }
}

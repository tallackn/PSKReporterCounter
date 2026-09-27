import CocoaMQTT
import Foundation

@MainActor
public protocol LiveFeedConnection: AnyObject {
    var onConnected: (() -> Void)? { get set }
    var onReport: (@Sendable (ReceivedReception) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }
    var onMalformedReport: ((Error) -> Void)? { get set }
    func connect(filter: ReceptionFilter) throws
    func disconnect()
}

/// CocoaMQTT owns MQTT framing, QoS, keepalive and TLS transport. This adapter
/// owns the PSK Reporter subscription, decoding and application callbacks.
@MainActor
public final class LiveFeed: LiveFeedConnection {
    public var onConnected: (() -> Void)?
    public var onReport: (@Sendable (ReceivedReception) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public var onMalformedReport: ((Error) -> Void)?
    private var client: CocoaMQTT?
    private var connectionTimeout: Timer?
    private var sessionID = UUID()

    public init() {}

    public func connect(filter: ReceptionFilter) throws {
        disconnect()
        guard Callsign.isValid(filter.callsign) else {
            throw ReporterError("Invalid callsign", detail: "A valid transmitting callsign is required before subscribing.")
        }
        let identifier = "pskc" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(18)
        let mqtt = CocoaMQTT(clientID: identifier, host: "mqtt.pskreporter.info", port: 1884)
        client = mqtt
        let sessionID = self.sessionID
        mqtt.enableSSL = true
        mqtt.cleanSession = true
        mqtt.keepAlive = 30
        mqtt.autoReconnect = false // The model provides visible, bounded retries.
        mqtt.delegateQueue = DispatchQueue(label: "com.tallackn.PSKReporterCounter.mqtt", qos: .utility)
        mqtt.logLevel = .off
        mqtt.didConnectAck = { [weak self] _, ack in
            Task { @MainActor in
                guard let self, self.sessionID == sessionID else { return }
                guard ack == .accept else {
                    self.fail(ReporterError("Live feed connection refused", detail: "The MQTT broker returned \(ack)."))
                    return
                }
                // The broker selects the sender, band and mode before delivery.
                self.client?.subscribe(filter.topic, qos: .qos0)
            }
        }
        mqtt.didSubscribeTopics = { [weak self] _, success, failed in
            let accepted = failed.isEmpty && success[filter.topic] != nil
            Task { @MainActor in
                guard let self, self.sessionID == sessionID else { return }
                guard accepted else {
                    self.fail(ReporterError("Live feed subscription refused", detail: "The broker did not accept \(filter.topic). Failed topics: \(failed)."))
                    return
                }
                self.connectionTimeout?.invalidate()
                self.connectionTimeout = nil
                self.onConnected?()
            }
        }
        let deliverReport = onReport
        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            let receivedAt = Date()
            let data = Data(message.payload)
            do {
                guard data.count <= 65_536 else {
                    throw ReporterError("Reception report is too large", detail: "The JSON payload exceeds 64 KB.")
                }
                let report = try Reception.decodeLive(data)
                if filter.matches(report) { deliverReport?(ReceivedReception(report: report, receivedAt: receivedAt)) }
            } catch {
                Task { @MainActor in
                    guard let self, self.sessionID == sessionID else { return }
                    self.onMalformedReport?(error)
                }
            }
        }
        mqtt.didDisconnect = { [weak self] _, error in
            Task { @MainActor in
                guard let self, self.sessionID == sessionID else { return }
                self.fail(error ?? ReporterError("Live feed disconnected", detail: "mqtt.pskreporter.info closed the connection."))
            }
        }
        let timeout = Timer(timeInterval: 25, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.sessionID == sessionID else { return }
                self.fail(ReporterError("Live feed connection timed out", detail: "The broker did not accept the connection and subscription within 25 seconds."))
            }
        }
        RunLoop.main.add(timeout, forMode: .common)
        connectionTimeout = timeout
        if !mqtt.connect(timeout: 20) {
            fail(ReporterError("Cannot open the live feed", detail: "CocoaMQTT could not start a TLS connection to mqtt.pskreporter.info:1884."))
        }
    }

    public func disconnect() {
        sessionID = UUID()
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        let old = client
        client = nil // Ignore all callbacks from the old session.
        old?.disconnect()
    }

    private func fail(_ error: Error) {
        disconnect()
        onFailure?(error)
    }
}

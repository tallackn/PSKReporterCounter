import XCTest
@testable import PSKReporterCore

final class FilterTests: XCTestCase {
    func testSenderOnlySubscriptionAndAllDefaults() {
        let filter = ReceptionFilter(callsign: " zl1abc ")
        XCTAssertEqual(filter.topic, "pskr/filter/v2/+/+/ZL1ABC/#")
        XCTAssertEqual(filter.band, .all)
        XCTAssertEqual(filter.mode, .all)
    }

    func testSelectedBandAndModeAreFilteredAtTheBroker() {
        let filter = ReceptionFilter(callsign: "ZL1ABC/P", band: .b20, mode: .ft8)
        XCTAssertEqual(filter.topic, "pskr/filter/v2/20m/FT8/ZL1ABC/P/#")
    }

    func testPayloadMustAlsoMatchTheExactSenderBandAndMode() {
        let filter = ReceptionFilter(callsign: "ZL1ABC", band: .b20, mode: .ft8)
        func spot(sender: String = "ZL1ABC", receiver: String = "G1ABC", band: String? = "20m", mode: String? = "FT8") -> Reception {
            Reception(sender: sender, receiver: receiver, timestamp: Date(), band: band, mode: mode)
        }
        XCTAssertTrue(filter.matches(spot()))
        XCTAssertFalse(filter.matches(spot(sender: "G1ABC", receiver: "ZL1ABC")))
        XCTAssertFalse(filter.matches(spot(sender: "ZL1ABC/P")))
        XCTAssertFalse(filter.matches(spot(band: "40m")))
        XCTAssertFalse(filter.matches(spot(mode: "FT4")))
        XCTAssertFalse(filter.matches(spot(band: nil)))
        XCTAssertTrue(ReceptionFilter(callsign: "ZL1ABC").matches(spot(band: nil, mode: nil)))
    }

    func testDocumentedPayloadDecodes() throws {
        let data = Data(#"{"sq":30142870791,"f":21074653,"md":"FT8","rp":-5,"t":1662407712,"t_tx":1662407697,"sc":"SP2EWQ","rc":"CU3AT","b":"15m"}"#.utf8)
        let report = try Reception.decodeLive(data)
        XCTAssertEqual(report.sender, "SP2EWQ")
        XCTAssertEqual(report.receiver, "CU3AT")
        XCTAssertEqual(report.timestamp.timeIntervalSince1970, 1662407712)
        XCTAssertEqual(report.band, "15m")
        XCTAssertEqual(report.mode, "FT8")
        XCTAssertEqual(report.signalToNoise, -5)
    }

    func testInvalidPayloadsAreErrorsRatherThanZeroCounts() {
        for json in ["{}", "<html>Unavailable</html>", #"{"sc":"ZL1ABC","rc":"","t":100}"#, #"{"sc":"ZL1ABC","rc":"G1ABC","t":-1}"#] {
            XCTAssertThrowsError(try Reception.decodeLive(Data(json.utf8)))
        }
    }
}

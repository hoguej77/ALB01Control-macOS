import XCTest
@testable import ALB01Protocol

final class ProtocolSafetyTests: XCTestCase {
    func testInvalidLampReplyIsRejectedBeforeNoChangeWrite() {
        var reply = ALB01Protocol.makeReport([0xEC, 0x31, 1])
        reply[10] = 255; reply[11] = 255
        XCTAssertThrowsError(try ALB01Protocol.parseLampReply(reply))
    }

    func testNonFiniteControlValuesCannotCrashPacketBuilders() {
        XCTAssertLessThanOrEqual(ALB01Protocol.lampChannels(on: true, brightnessPercent: .nan, kelvin: .infinity).total, 178)
        XCTAssertEqual(ALB01Protocol.RGB(255, 128, 0).scaled(brightnessPercent: .nan), .init(0, 0, 0))
    }
}

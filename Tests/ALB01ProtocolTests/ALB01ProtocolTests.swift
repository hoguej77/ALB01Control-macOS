import XCTest
@testable import ALB01Protocol

final class ALB01ProtocolTests: XCTestCase {
    private func assertReport(_ report: [UInt8], prefix: [UInt8], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(report.count, 65, file: file, line: line)
        XCTAssertEqual(Array(report.prefix(prefix.count)), prefix, file: file, line: line)
        XCTAssertEqual(report[0], 0xEC, file: file, line: line)
    }

    func testEveryCommandIsASixtyFiveByteECReport() throws {
        let commands = [
            ALB01Protocol.configRequest(),
            ALB01Protocol.lampGetRequest(),
            ALB01Protocol.lampReadRequest(),
            ALB01Protocol.lampSet(.init(cool: 39, warm: 66)),
            ALB01Protocol.rearEffect(.staticColor, color: .init(1, 2, 3)),
            ALB01Protocol.directModeInitialization(),
            try ALB01Protocol.directFrame([.init(1, 2, 3)]),
        ]
        for command in commands { XCTAssertNoThrow(try ALB01Protocol.validateReport(command)) }
    }

    func testRearEffectPrefixes() {
        assertReport(ALB01Protocol.rearEffect(.staticColor, color: .init(0xFF, 0x00, 0x33)), prefix: [0xEC, 0x35, 0, 0, 0, 0x01, 0, 0, 1, 0xFF, 0, 0x33])
        assertReport(ALB01Protocol.rearEffect(.breathing, color: .init(0xFF, 0x00, 0x33)), prefix: [0xEC, 0x35, 0, 0, 0, 0x02, 0, 0, 1, 0xFF, 0, 0x33])
        assertReport(ALB01Protocol.rearEffect(.spectrum), prefix: [0xEC, 0x35, 0, 0, 0, 0x04, 0, 0, 1, 0, 0, 0])
        assertReport(ALB01Protocol.rearEffect(.off), prefix: [0xEC, 0x35, 0, 0, 0, 0x01, 0, 0, 1, 0, 0, 0])
    }

    func testDirectModeAndFrames() throws {
        assertReport(ALB01Protocol.directModeInitialization(), prefix: [0xEC, 0x35, 0, 0, 0, 0xFF, 0, 0, 1])
        let frame = try ALB01Protocol.directFrame([.init(0xFF, 0, 0), .init(0, 0xFF, 0), .init(0, 0, 0xFF)])
        assertReport(frame, prefix: [0xEC, 0x40, 0x84, 0, 3, 0xFF, 0, 0, 0, 0xFF, 0, 0, 0, 0xFF])
    }

    func testDirectFrameTwentyLEDLimitAndNoOutOfBoundsWrites() throws {
        let colors = Array(repeating: ALB01Protocol.RGB(1, 2, 3), count: 20)
        let frame = try ALB01Protocol.directFrame(colors)
        XCTAssertEqual(frame.count, 65)
        XCTAssertEqual(frame[4], 20)
        XCTAssertEqual(Array(frame[62...64]), [1, 2, 3])
        XCTAssertThrowsError(try ALB01Protocol.directFrame([]))
        XCTAssertThrowsError(try ALB01Protocol.directFrame(Array(repeating: .init(0, 0, 0), count: 21)))
    }

    func testLampMappingVectorsAndSample() throws {
        XCTAssertEqual(ALB01Protocol.lampChannels(on: false, brightnessPercent: 100, kelvin: 2700), .init(cool: 0, warm: 0))
        XCTAssertEqual(ALB01Protocol.lampChannels(on: true, brightnessPercent: 100, kelvin: 2700), .init(cool: 0, warm: 178))
        XCTAssertEqual(ALB01Protocol.lampChannels(on: true, brightnessPercent: 100, kelvin: 6500), .init(cool: 178, warm: 0))
        XCTAssertEqual(ALB01Protocol.lampChannels(on: true, brightnessPercent: 50, kelvin: 4600), .init(cool: 44, warm: 45))
        assertReport(ALB01Protocol.lampSet(.init(cool: 0x0C, warm: 0x14)), prefix: [0xEC, 0x35, 0x01, 0, 0, 0x01, 0, 0, 1, 0x0C, 0x14])
        XCTAssertLessThanOrEqual(ALB01Protocol.lampChannels(on: true, brightnessPercent: 100, kelvin: 4300).total, 178)
    }

    func testLampReplyParser() throws {
        var reply = ALB01Protocol.makeReport([0xEC, 0x31, 0x01])
        reply[10] = 39
        reply[11] = 66
        XCTAssertEqual(try ALB01Protocol.parseLampReply(reply), .init(cool: 39, warm: 66))
        XCTAssertThrowsError(try ALB01Protocol.parseLampReply(ALB01Protocol.makeReport([0xEC, 0x30])))
    }

    func testConfigParser() throws {
        var reply = ALB01Protocol.makeReport([0xEC, 0x30])
        reply[32] = 3
        XCTAssertEqual(try ALB01Protocol.parseLEDCount(from: reply), 3)
    }

    func testBrightnessScalingPreservesColorBalance() {
        XCTAssertEqual(ALB01Protocol.RGB(255, 128, 64).scaled(brightnessPercent: 50), .init(128, 64, 32))
        XCTAssertEqual(ALB01Protocol.RGB(255, 128, 64).scaled(brightnessPercent: 0), .init(0, 0, 0))
        XCTAssertEqual(ALB01Protocol.RGB(255, 128, 64).scaled(brightnessPercent: 100), .init(255, 128, 64))
    }
}

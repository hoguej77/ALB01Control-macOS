import XCTest
@testable import ALB01Protocol

final class ScreenColorsTests: XCTestCase {
    func testBGRAHorizontalZonesRespectPaddedRows() {
        // Width 9, three 3-pixel zones, row padding must never enter averages.
        var row: [UInt8] = []
        for c: ALB01Protocol.RGB in [.init(255, 0, 0), .init(0, 255, 0), .init(0, 0, 255)] {
            for _ in 0..<3 { row += [c.blue, c.green, c.red, 255] }
        }
        row += [255, 255, 255, 255]
        let image = row + row + row
        let result = image.withUnsafeBufferPointer { ScreenColors.sample($0, width: 9, height: 3, rowBytes: 40, ledCount: 3, uniform: false) }
        XCTAssertEqual(result, [.init(255, 0, 0), .init(0, 255, 0), .init(0, 0, 255)])
        let uniform = image.withUnsafeBufferPointer { ScreenColors.sample($0, width: 9, height: 3, rowBytes: 40, ledCount: 3, uniform: true) }
        XCTAssertEqual(uniform, Array(repeating: .init(85, 85, 85), count: 3))
    }

    func testMalformedBuffersNeverReadBeyondBounds() {
        let bytes = [UInt8](repeating: 0, count: 16)
        bytes.withUnsafeBufferPointer {
            XCTAssertNil(ScreenColors.sample($0, width: 4, height: 2, rowBytes: 16, ledCount: 3, uniform: false))
            XCTAssertNil(ScreenColors.sample($0, width: 4, height: 1, rowBytes: 8, ledCount: 3, uniform: false))
            XCTAssertNil(ScreenColors.sample($0, width: 1, height: 1, rowBytes: 4, ledCount: 3, uniform: false))
            XCTAssertNil(ScreenColors.sample($0, width: 4, height: 1, rowBytes: 16, ledCount: 21, uniform: false))
        }
    }

    func testSmoothingIntensityAndPhysicalOrder() {
        let frame: [ALB01Protocol.RGB] = [.init(200, 100, 0), .init(0, 100, 200)]
        XCTAssertEqual(ScreenColors.blend(frame, previous: [], retention: 0.9, intensity: 50, reverse: true), [.init(0, 50, 100), .init(100, 50, 0)])
        XCTAssertEqual(ScreenColors.blend([.init(200, 100, 0)], previous: [.init(0, 0, 200)], retention: 0.5, intensity: 100, reverse: false), [.init(100, 50, 100)])
    }

    func testMailboxDropsOlderFramesAndClosesPermanently() {
        let mailbox = LatestFrameMailbox<Int>()
        XCTAssertTrue(mailbox.offer(1))
        XCTAssertFalse(mailbox.offer(2))
        XCTAssertFalse(mailbox.offer(3))
        XCTAssertEqual(mailbox.take(), 3)
        XCTAssertNil(mailbox.take())
        XCTAssertTrue(mailbox.offer(4))
        mailbox.close()
        XCTAssertNil(mailbox.take())
        XCTAssertFalse(mailbox.offer(5))
        // A fresh session cannot receive old-session pending work.
        let newSession = LatestFrameMailbox<Int>()
        XCTAssertNil(newSession.take())
        XCTAssertTrue(newSession.offer(6))
        XCTAssertEqual(newSession.take(), 6)
    }

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

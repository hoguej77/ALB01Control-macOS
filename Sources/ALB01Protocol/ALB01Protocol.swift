import Foundation

public enum ALB01Protocol {
    public static let vendorID = 0x0B05
    public static let productID = 0x1AC8
    public static let usagePage = 0xFF72
    public static let usage = 0x00A1
    public static let reportID: UInt8 = 0xEC
    public static let reportLength = 65
    public static let maxDirectLEDs = 20
    public static let maximumLampTotal = 178
    public static let configLEDCountIndex = 32

    public enum ProtocolError: LocalizedError, Equatable, Sendable {
        case invalidReportLength(Int)
        case unexpectedConfigReply
        case unexpectedLampReply
        case invalidLEDCount(Int)
        case invalidLampChannels

        public var errorDescription: String? {
            switch self {
            case .invalidReportLength(let count): return "ALB01 reports must be 65 bytes, received \(count)."
            case .unexpectedConfigReply: return "The reply was not an ALB01 EC30 config report."
            case .unexpectedLampReply: return "The reply was not an ALB01 EC3101 lamp report."
            case .invalidLEDCount(let count): return "ALB01 direct mode supports 1...20 LEDs, not \(count)."
            case .invalidLampChannels: return "Lamp reply exceeds the verified 178-point power budget. Controls remain locked."
            }
        }
    }

    public struct RGB: Equatable, Sendable, Codable {
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8

        public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Preserves hue by scaling every channel; it never clips an individual channel.
        public func scaled(brightnessPercent: Double) -> RGB {
            let factor = brightnessPercent.isFinite ? min(max(brightnessPercent, 0), 100) / 100 : 0
            return RGB(
                UInt8((Double(red) * factor).rounded()),
                UInt8((Double(green) * factor).rounded()),
                UInt8((Double(blue) * factor).rounded())
            )
        }
    }

    public struct LampChannels: Equatable, Sendable {
        public let cool: UInt8
        public let warm: UInt8

        public init(cool: UInt8, warm: UInt8) {
            self.cool = cool
            self.warm = warm
        }

        public var isOff: Bool { cool == 0 && warm == 0 }
        public var total: Int { Int(cool) + Int(warm) }
        public var estimatedBrightnessPercent: Double { Double(total) / Double(ALB01Protocol.maximumLampTotal) * 100 }
        public var estimatedKelvin: Double {
            guard total > 0 else { return 2700 }
            return 2700 + Double(cool) / Double(total) * 3800
        }
    }

    public enum AuraEffect: String, CaseIterable, Sendable, Codable {
        case off
        case staticColor
        case breathing
        case spectrum
    }

    public static func makeReport(_ prefix: [UInt8]) -> [UInt8] {
        precondition(prefix.count <= reportLength, "ALB01 packet prefix exceeds 65 bytes")
        return prefix + Array(repeating: 0, count: reportLength - prefix.count)
    }

    public static func validateReport(_ report: [UInt8]) throws {
        guard report.count == reportLength else { throw ProtocolError.invalidReportLength(report.count) }
        guard report.first == reportID else { throw ProtocolError.invalidReportLength(report.count) }
    }

    public static func configRequest() -> [UInt8] { makeReport([reportID, 0xB0]) }
    public static func lampGetRequest() -> [UInt8] { makeReport([reportID, 0x31, 0x01]) }
    public static func lampReadRequest() -> [UInt8] { makeReport([reportID, 0xB1, 0x01]) }

    public static func parseLEDCount(from reply: [UInt8]) throws -> Int {
        guard reply.count == reportLength, reply[0] == reportID, reply[1] == 0x30 else {
            throw ProtocolError.unexpectedConfigReply
        }
        return Int(reply[configLEDCountIndex])
    }

    public static func lampChannels(on: Bool, brightnessPercent: Double, kelvin: Double) -> LampChannels {
        guard on else { return LampChannels(cool: 0, warm: 0) }
        let brightness = brightnessPercent.isFinite ? min(max(brightnessPercent, 0), 100) : 0
        let total = max(1, Int((brightness / 100 * Double(maximumLampTotal)).rounded()))
        let temperature = kelvin.isFinite ? min(max(kelvin, 2700), 6500) : 4600
        // DisplayWidget/RIGStats' 50% at 4600 K reference is 44/45. Banker's
        // rounding turns its exactly-half cool value (44.5) into 44.
        let cool = Int((Double(total) * ((temperature - 2700) / 3800)).rounded(.toNearestOrEven))
        return LampChannels(cool: UInt8(cool), warm: UInt8(total - cool))
    }

    public static func lampSet(_ channels: LampChannels) -> [UInt8] {
        precondition(channels.total <= maximumLampTotal, "Lamp channels exceed the ALB01 178-point power budget")
        return makeReport([reportID, 0x35, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, channels.cool, channels.warm])
    }

    public static func parseLampReply(_ reply: [UInt8]) throws -> LampChannels {
        guard reply.count == reportLength, reply[0] == reportID, reply[1] == 0x31, reply[2] == 0x01 else {
            throw ProtocolError.unexpectedLampReply
        }
        let channels = LampChannels(cool: reply[10], warm: reply[11])
        guard channels.total <= maximumLampTotal else { throw ProtocolError.invalidLampChannels }
        return channels
    }

    public static func rearEffect(_ effect: AuraEffect, color: RGB = RGB(0, 0, 0)) -> [UInt8] {
        let mode: UInt8
        let effectiveColor: RGB
        switch effect {
        case .off: mode = 0x01; effectiveColor = RGB(0, 0, 0)
        case .staticColor: mode = 0x01; effectiveColor = color
        case .breathing: mode = 0x02; effectiveColor = color
        case .spectrum: mode = 0x04; effectiveColor = RGB(0, 0, 0)
        }
        return makeReport([reportID, 0x35, 0x00, 0x00, 0x00, mode, 0x00, 0x00, 0x01, effectiveColor.red, effectiveColor.green, effectiveColor.blue])
    }

    public static func directModeInitialization() -> [UInt8] {
        makeReport([reportID, 0x35, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x01])
    }

    public static func directFrame(_ colors: [RGB]) throws -> [UInt8] {
        guard (1...maxDirectLEDs).contains(colors.count) else { throw ProtocolError.invalidLEDCount(colors.count) }
        var report = makeReport([reportID, 0x40, 0x84, 0x00, UInt8(colors.count)])
        for (index, color) in colors.enumerated() {
            let offset = 5 + index * 3
            report[offset] = color.red
            report[offset + 1] = color.green
            report[offset + 2] = color.blue
        }
        return report
    }

    public static func hex(_ report: [UInt8]) -> String {
        report.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

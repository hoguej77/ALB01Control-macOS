import Foundation
import ALB01Protocol

enum LightingAutomationError: LocalizedError {
    case unavailable, invalidBrightness, invalidTemperature, unknownScene
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Connect the ALB01, wait for the app to finish its current operation, and try again."
        case .invalidBrightness: return "Brightness must be a whole number from 1 to 100."
        case .invalidTemperature: return "Temperature must be from 2700 to 6500 Kelvin."
        case .unknownScene: return "Choose one of ALB01Control's lighting scenes."
        }
    }
}

enum LightingAutomationAction: Sendable {
    case power(Bool), brightness(Int), temperature(Int), scene(String), allOff
    func validate() throws {
        switch self {
        case .brightness(let value) where !(1...100).contains(value): throw LightingAutomationError.invalidBrightness
        case .temperature(let value) where !(2700...6500).contains(value): throw LightingAutomationError.invalidTemperature
        case .scene(let id) where !LightingPreset.builtIns.contains(where: { $0.id == id }): throw LightingAutomationError.unknownScene
        default: break
        }
    }
}

enum AmbientPalette {
    /// An aesthetic sRGB complement, not a calibrated color-temperature measurement.
    static func matchingDesk(kelvin: Double) -> ALB01Protocol.RGB {
        let t = min(max(kelvin.isFinite ? (kelvin - 2700) / 3800 : 0.5, 0), 1)
        return .init(UInt8((255 - 30 * t).rounded()), UInt8((180 + 60 * t).rounded()), UInt8((100 + 155 * t).rounded()))
    }
}

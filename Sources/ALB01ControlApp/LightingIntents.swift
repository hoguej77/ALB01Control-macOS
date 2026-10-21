import AppIntents

enum MacLightingScene: String, AppEnum {
    case focus, daylight, evening, cinema, ambient, custom1, custom2
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lighting Scene")
    static let caseDisplayRepresentations: [MacLightingScene: DisplayRepresentation] = [
        .focus: "Focus", .daylight: "Daylight", .evening: "Evening", .cinema: "Cinema",
        .ambient: "Ambient", .custom1: "Custom 1", .custom2: "Custom 2"
    ]
    var presetID: String {
        switch self {
        case .focus: "reading"; case .daylight: "game"; case .evening: "night"
        case .cinema: "theater"; case .ambient: "music"; case .custom1: "user1"; case .custom2: "user2"
        }
    }
}

struct SetDeskPowerIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Desk Light Power"
    static let description = IntentDescription("Turn your ALB01 desk light on or off. Its brightness and warmth are remembered.")
    static let openAppWhenRun = true
    @Parameter(title: "On", default: true) var on: Bool
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await ControlViewModel.shared.executeShortcut(.power(on))
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
struct SetDeskBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Desk Light Brightness"
    static let description = IntentDescription("Set 1–100 percent brightness and turn the desk light on.")
    static let openAppWhenRun = true
    @Parameter(title: "Brightness Percent", default: 50) var percent: Int
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await ControlViewModel.shared.executeShortcut(.brightness(percent))
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
struct SetDeskTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Desk Light Warmth"
    static let description = IntentDescription("Set 2700–6500 Kelvin and turn the desk light on. Lower values are warmer.")
    static let openAppWhenRun = true
    @Parameter(title: "Temperature Kelvin", default: 4600) var kelvin: Int
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await ControlViewModel.shared.executeShortcut(.temperature(kelvin))
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
struct ApplyMacLightingSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Lighting Scene"
    static let description = IntentDescription("Apply Focus, Daylight, Evening, Cinema, Ambient, or a saved custom scene to your light bar.")
    static let openAppWhenRun = true
    @Parameter(title: "Scene", default: .focus) var scene: MacLightingScene
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await ControlViewModel.shared.executeShortcut(.scene(scene.presetID))
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
struct SwitchOffLightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Off Desk and Ambient Lights"
    static let description = IntentDescription("Turn off both parts of your ALB01 light bar.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await ControlViewModel.shared.executeShortcut(.allOff)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

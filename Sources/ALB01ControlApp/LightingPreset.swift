import Foundation
import ALB01Protocol

/// DisplayWidget-style slots with independently chosen macOS starter settings.
/// Names follow ASUS's ALB01 screenshot; values are not claimed as factory data.
struct LightingPreset: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let detail: String
    var frontOn: Bool
    var brightness: Double
    var kelvin: Double
    var rearEffect: ALB01Protocol.AuraEffect
    var rearColor: ALB01Protocol.RGB
    var rearBrightness: Double

    mutating func validate() {
        var settings = SavedSettings()
        settings.brightness = brightness
        settings.kelvin = kelvin
        settings.rearBrightness = rearBrightness
        settings.validate()
        brightness = settings.brightness
        kelvin = settings.kelvin
        rearBrightness = settings.rearBrightness
    }

    static let builtIns: [LightingPreset] = [
        .init(id: "reading", name: "Reading", detail: "Neutral desk light with rear RGB off.",
              frontOn: true, brightness: 60, kelvin: 5000, rearEffect: .off, rearColor: .init(255, 255, 255), rearBrightness: 40),
        .init(id: "game", name: "Game", detail: "Low desk light with a rear spectrum cycle.",
              frontOn: true, brightness: 30, kelvin: 4600, rearEffect: .spectrum, rearColor: .init(255, 0, 0), rearBrightness: 100),
        .init(id: "night", name: "Night View", detail: "Dim warm desk light with gentle amber backlighting.",
              frontOn: true, brightness: 10, kelvin: 2700, rearEffect: .staticColor, rearColor: .init(255, 100, 20), rearBrightness: 15),
        .init(id: "theater", name: "Theater", detail: "Desk light off with low, steady neutral backlighting.",
              frontOn: false, brightness: 20, kelvin: 4000, rearEffect: .staticColor, rearColor: .init(255, 255, 255), rearBrightness: 20),
        .init(id: "music", name: "Music", detail: "Purple breathing ambience. Not audio-reactive; no microphone or audio capture.",
              frontOn: false, brightness: 20, kelvin: 4000, rearEffect: .breathing, rearColor: .init(160, 50, 255), rearBrightness: 60),
        .init(id: "user1", name: "User Mode 1", detail: "Save your current front and rear settings in this slot.",
              frontOn: true, brightness: 50, kelvin: 4600, rearEffect: .staticColor, rearColor: .init(64, 140, 255), rearBrightness: 50),
        .init(id: "user2", name: "User Mode 2", detail: "A second customizable front-and-rear preset.",
              frontOn: true, brightness: 30, kelvin: 2700, rearEffect: .staticColor, rearColor: .init(255, 100, 20), rearBrightness: 30),
    ]

    static let standardColors: [(name: String, color: ALB01Protocol.RGB)] = [
        ("Red", .init(255, 0, 0)), ("Green", .init(0, 255, 0)), ("Blue", .init(0, 0, 255)),
        ("Yellow", .init(255, 255, 0)), ("Purple", .init(128, 0, 128)), ("Orange", .init(255, 165, 0)),
        ("Pink", .init(255, 105, 180)), ("Light blue", .init(135, 206, 235)), ("White", .init(255, 255, 255)),
    ]
}

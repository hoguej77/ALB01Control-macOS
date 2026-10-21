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
        .init(id: "reading", name: "Focus", detail: "Clear neutral desk light, with the backlight off.",
              frontOn: true, brightness: 60, kelvin: 5000, rearEffect: .off, rearColor: .init(255, 255, 255), rearBrightness: 40),
        .init(id: "game", name: "Daylight", detail: "Bright cool desk light with a soft neutral backlight.",
              frontOn: true, brightness: 70, kelvin: 6000, rearEffect: .staticColor, rearColor: .init(235, 242, 255), rearBrightness: 20),
        .init(id: "night", name: "Evening", detail: "Dim warm desk light with gentle amber backlighting.",
              frontOn: true, brightness: 10, kelvin: 2700, rearEffect: .staticColor, rearColor: .init(255, 100, 20), rearBrightness: 15),
        .init(id: "theater", name: "Cinema", detail: "Desk light off with a subtle neutral backlight.",
              frontOn: false, brightness: 20, kelvin: 4000, rearEffect: .staticColor, rearColor: .init(255, 255, 255), rearBrightness: 10),
        .init(id: "music", name: "Ambient", detail: "Desk light off with a steady warm backlight.",
              frontOn: false, brightness: 20, kelvin: 4000, rearEffect: .staticColor, rearColor: .init(255, 210, 160), rearBrightness: 25),
        .init(id: "user1", name: "Custom 1", detail: "Save your current desk and ambient lighting here.",
              frontOn: true, brightness: 50, kelvin: 4600, rearEffect: .staticColor, rearColor: .init(64, 140, 255), rearBrightness: 50),
        .init(id: "user2", name: "Custom 2", detail: "A second custom desk-and-ambient scene.",
              frontOn: true, brightness: 30, kelvin: 2700, rearEffect: .staticColor, rearColor: .init(255, 100, 20), rearBrightness: 30),
    ]

    static let standardColors: [(name: String, color: ALB01Protocol.RGB)] = [
        ("Red", .init(255, 0, 0)), ("Green", .init(0, 255, 0)), ("Blue", .init(0, 0, 255)),
        ("Yellow", .init(255, 255, 0)), ("Purple", .init(128, 0, 128)), ("Orange", .init(255, 165, 0)),
        ("Pink", .init(255, 105, 180)), ("Light blue", .init(135, 206, 235)), ("White", .init(255, 255, 255)),
    ]
}

import XCTest
@testable import ALB01ControlApp
import ALB01Protocol

final class InputAndMigrationTests: XCTestCase {
    @MainActor
    func testRemovedScreenSettingsDoNotDiscardSavedLighting() throws {
        let suite = "CaptureRemovalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy: [String: Any] = ["brightness": 37, "kelvin": 4100,
            "rearEffect": "breathing", "rearColor": ["red": 11, "green": 22, "blue": 33],
            "rearBrightness": 44, "displayID": 123, "uniform": true, "reverse": true,
            "intensity": 90, "smoothing": 0.4, "fps": 60]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "settings.v1")
        let model = ControlViewModel(defaults: defaults)
        XCTAssertEqual(model.settings.brightness, 37)
        XCTAssertEqual(model.settings.kelvin, 4100)
        XCTAssertEqual(model.settings.rearBrightness, 44)
        XCTAssertEqual(model.settings.rearEffect, .breathing)
        XCTAssertEqual(model.settings.rearColor, .init(11, 22, 33))
        model.save()
        let saved = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "settings.v1"))) as? [String: Any])
        for key in ["displayID", "uniform", "reverse", "intensity", "smoothing", "fps"] {
            XCTAssertNil(saved[key], key)
        }
        XCTAssertFalse(model.busy)
        XCTAssertNil(model.measuredLamp)
    }
    func testFocusingRoundedHardwareReadbackDoesNotRequestAnotherWrite() {
        XCTAssertTrue(LampValueInput.isUnchanged("59", current: 58.988764))
        XCTAssertTrue(LampValueInput.isUnchanged("4111", current: 4111.428571))
        XCTAssertFalse(LampValueInput.isUnchanged("60", current: 58.988764))
    }
    func testExactInputRejectsInvalidAndOutOfRangeValues() {
        for invalid in ["", "nan", "inf", "44.5", "0", "101", "99999999999999999999999999999"] {
            XCTAssertNil(LampValueInput.parse(invalid, range: 1...100), invalid)
        }
        XCTAssertNil(LampValueInput.parse("2699", range: 2700...6500))
        XCTAssertNil(LampValueInput.parse("6501", range: 2700...6500))
    }

    func testExactInputAcceptsBoundariesAndWhitespace() {
        XCTAssertEqual(LampValueInput.parse(" 1 ", range: 1...100), 1)
        XCTAssertEqual(LampValueInput.parse("100", range: 1...100), 100)
        XCTAssertEqual(LampValueInput.parse("2700", range: 2700...6500), 2700)
        XCTAssertEqual(LampValueInput.parse("6500", range: 2700...6500), 6500)
    }

    @MainActor
    func testLegacyMusicSceneGetsHonestMetadataWithoutLosingCustomization() throws {
        let suite = "InputAndMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = LightingPreset(id: "music", name: "Music", detail: "Legacy description",
            frontOn: true, brightness: 37, kelvin: 4100, rearEffect: .staticColor,
            rearColor: .init(11, 22, 33), rearBrightness: 44)
        defaults.set(try JSONEncoder().encode(["music": legacy]), forKey: "presets.v1")
        let model = ControlViewModel(defaults: defaults)
        model.selectedPresetID = "music"
        XCTAssertEqual(model.selectedPreset.name, "Ambient")
        XCTAssertEqual(model.selectedPreset.brightness, 37)
        XCTAssertEqual(model.selectedPreset.kelvin, 4100)
        XCTAssertEqual(model.selectedPreset.rearEffect, .staticColor)
        XCTAssertEqual(model.selectedPreset.rearColor, .init(11, 22, 33))
        XCTAssertEqual(model.selectedPreset.rearBrightness, 44)
        XCTAssertTrue(model.selectedPreset.frontOn)
        XCTAssertFalse(model.busy)
        XCTAssertNil(model.measuredLamp)
    }
}

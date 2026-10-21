import XCTest
@testable import ALB01ControlApp
import ALB01Protocol

final class PresetTests: XCTestCase {
    func testDisplayWidgetStyleSlotsAndSafeChannelBudget() {
        XCTAssertEqual(LightingPreset.builtIns.map(\.name),
                       ["Focus", "Daylight", "Evening", "Cinema", "Ambient", "Custom 1", "Custom 2"])
        XCTAssertEqual(Set(LightingPreset.builtIns.map(\.id)).count, 7)
        for p in LightingPreset.builtIns {
            let channels = ALB01Protocol.lampChannels(on: p.frontOn, brightnessPercent: p.brightness, kelvin: p.kelvin)
            XCTAssertLessThanOrEqual(channels.total, 178)
            XCTAssertEqual(channels.isOff, !p.frontOn)
            XCTAssertTrue((2700...6500).contains(p.kelvin))
        }
    }

    @MainActor
    func testCustomPresetSurvivesReloadWithoutHardwareWrite() {
        let name = "PresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        model.acceptReadback(.init(cool: 44, warm: 45))
        model.selectedPresetID = "user1"
        model.settings.rearEffect = .breathing
        model.settings.rearColor = .init(15, 30, 60)
        model.saveCurrentPreset()
        XCTAssertFalse(model.busy)
        let reloaded = ControlViewModel(defaults: defaults)
        reloaded.selectedPresetID = "user1"
        XCTAssertTrue(reloaded.selectedPreset.frontOn)
        XCTAssertEqual(reloaded.selectedPreset.brightness, 50, accuracy: 0.001)
        XCTAssertEqual(reloaded.selectedPreset.rearColor, .init(15, 30, 60))
        XCTAssertEqual(reloaded.selectedPreset.rearEffect, .breathing)
    }

    @MainActor
    func testPresetResetAndEraseDoNotApplyLights() {
        let name = "PresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        model.acceptReadback(.init(cool: 12, warm: 20))
        model.saveCurrentPreset()
        XCTAssertNotNil(model.presetOverrides["reading"])
        model.resetSelectedPreset()
        XCTAssertNil(model.presetOverrides["reading"])
        XCTAssertEqual(model.selectedPreset, LightingPreset.builtIns[0])
        XCTAssertEqual(model.measuredLamp, .init(cool: 12, warm: 20))
        model.saveCurrentPreset()
        model.eraseSettings()
        XCTAssertNil(defaults.data(forKey: "presets.v1"))
        XCTAssertTrue(model.presetOverrides.isEmpty)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(model.measuredLamp, .init(cool: 12, warm: 20))
    }

    @MainActor
    func testAddingPresetsKeepsExistingSettings() {
        let name = "PresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let old = ControlViewModel(defaults: defaults)
        old.settings.brightness = 37
        old.settings.reverse = true
        old.save()
        let reloaded = ControlViewModel(defaults: defaults)
        XCTAssertEqual(reloaded.settings.brightness, 37)
        XCTAssertTrue(reloaded.settings.reverse)
        XCTAssertEqual(reloaded.selectedPreset.id, "reading")
        XCTAssertTrue(reloaded.presetOverrides.isEmpty)
    }
}

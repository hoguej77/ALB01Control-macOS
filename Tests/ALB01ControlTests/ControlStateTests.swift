import XCTest
@testable import ALB01ControlApp
import ALB01Protocol

final class ControlStateTests: XCTestCase {
    @MainActor
    func testTurningOffPreservesLastLitBrightnessAndTemperature() {
        let name = "ALB01ControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        model.acceptReadback(.init(cool: 44, warm: 45))
        let brightness = model.settings.brightness
        let temperature = model.settings.kelvin
        model.acceptReadback(.init(cool: 0, warm: 0))
        XCTAssertFalse(model.frontOn)
        XCTAssertEqual(model.settings.brightness, brightness)
        XCTAssertEqual(model.settings.kelvin, temperature)
        let reloaded = ControlViewModel(defaults: defaults)
        XCTAssertEqual(reloaded.settings.brightness, brightness)
        XCTAssertEqual(reloaded.settings.kelvin, temperature)
    }

    @MainActor
    func testCommandsCannotOverlapAcrossAwait() async {
        let name = "ALB01ControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        var count = 0
        model.run { count += 1; try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(model.busy)
        model.run { count += 1 }
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(count, 1)
        XCTAssertFalse(model.busy)
    }

    @MainActor
    func testEraseDoesNotApplyHardwareSettings() {
        let name = "ALB01ControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        model.settings.rearEffect = .breathing
        model.settings.reverse = true
        model.save()
        model.acceptReadback(.init(cool: 12, warm: 20))
        model.eraseSettings()
        XCTAssertNil(defaults.data(forKey: "settings.v1"))
        XCTAssertEqual(model.measuredLamp, .init(cool: 12, warm: 20))
        XCTAssertFalse(model.busy)
        XCTAssertFalse(model.settings.reverse)
    }

    @MainActor
    func testEraseCancelsPendingRearChange() async {
        let name = "ALB01ControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = ControlViewModel(defaults: defaults)
        model.scheduleRear()
        model.eraseSettings()
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(defaults.data(forKey: "settings.v1"))
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.busy)
        XCTAssertTrue(model.status.contains("No light-setting command sent"))
    }

    func testSavedNumbersAreClampedAndFPSValidated() {
        var saved = SavedSettings()
        saved.brightness = .nan; saved.kelvin = 9000; saved.fps = 400
        saved.smoothing = .infinity; saved.intensity = -1
        saved.validate()
        XCTAssertEqual(saved.brightness, 60)
        XCTAssertEqual(saved.kelvin, 6500)
        XCTAssertEqual(saved.fps, 30)
        XCTAssertEqual(saved.smoothing, 0.2)
        XCTAssertEqual(saved.intensity, 0)
    }
}

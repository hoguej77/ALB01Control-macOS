import XCTest
@testable import ALB01ControlApp

final class AutomationTests: XCTestCase {
    func testAutomationRejectsUnsafeRangesAndUnknownScenes() {
        XCTAssertThrowsError(try LightingAutomationAction.brightness(0).validate())
        XCTAssertThrowsError(try LightingAutomationAction.brightness(101).validate())
        XCTAssertThrowsError(try LightingAutomationAction.temperature(2699).validate())
        XCTAssertThrowsError(try LightingAutomationAction.temperature(6501).validate())
        XCTAssertThrowsError(try LightingAutomationAction.scene("missing").validate())
        XCTAssertNoThrow(try LightingAutomationAction.brightness(100).validate())
        XCTAssertNoThrow(try LightingAutomationAction.temperature(2700).validate())
    }

    func testEveryShortcutSceneResolvesToAnExistingPersistentScene() {
        let ids = Set(LightingPreset.builtIns.map(\.id))
        for scene in MacLightingScene.allCases {
            XCTAssertTrue(ids.contains(scene.presetID))
            XCTAssertNoThrow(try LightingAutomationAction.scene(scene.presetID).validate())
        }
    }

    @MainActor
    func testInvalidShortcutDoesNotStartHardwareDiscovery() async {
        let suite = "AutomationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ControlViewModel(defaults: defaults)
        do {
            _ = try await model.executeShortcut(.brightness(-1))
            XCTFail("Unsafe command must fail before discovery")
        } catch {
            XCTAssertFalse(model.busy)
            XCTAssertFalse(model.connected)
            XCTAssertNil(model.measuredLamp)
            XCTAssertTrue(model.activity.isEmpty)
        }
    }
}

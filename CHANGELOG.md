# Changelog

## 0.4.0-beta.3 — 2026-10-20

- Reworked the lighting interface around an original ALB01/ROG-inspired visual system: black hardware surfaces, restrained red action states, warm/cool desk-light cues, technical chamfered panels, and macOS system typography.
- Replaced rounded display styling and cyan-first controls. The interface does not copy ASUS artwork or bundle an unlicensed proprietary ROG typeface.
- Renamed the rear `Breathe` affordance to `Pulse` and `Rainbow` to `Spectrum`; these remain the same documented hardware effects.
- App version 0.4.0 (15); all 27 automated tests pass.

## 0.4.0-beta.2 — 2026-10-20

- Removed Screen Sync, its capture engine/dependency, sampling queues, display enumeration, permissions, frame counters, rate settings, and calibration. Older customized lighting values survive migration. Capture remains in Git history for future research, not in this release.
- User reported Safari video returning after the earlier app quit; root cause is unconfirmed. No claim of a proven Safari fix.

- Rebuilt the window as Lighting Studio with a navigation rail, monitor/light-bar preview, clearer desk and ambient controls, and a light-bar menu icon.
- Added System/Light/Dark appearance, keyboard navigation, validated numeric brightness/temperature entry, and persistent Jonathan Hogue credit.
- Replaced PC-style starter scenes with Focus, Daylight, Evening, Cinema, Ambient, and two custom slots. Existing custom values are preserved.
- Added Match desk warmth for a complementary, soft solid backlight. Breathing remains optional, not a music-reactive scene.
- Added five experimental App Intent actions and native Xcode Release packaging with extracted metadata. Shortcuts discovers the actions, but the tested ad-hoc build cannot execute them because macOS requires an Apple Team ID. Siri is not ready in this build.
- 27 lighting/protocol/state/input/automation tests pass locally. Removed screen-sampling tests with the retired code, retaining protocol safety coverage. App version 0.4.0 (14).

## 0.3.0-beta.2 — 2026-10-19

- Added seven DisplayWidget-style preset slots: Reading, Game, Night View, Theater, Music, and two User Modes.
- Added Apply, Save current, and Reset actions; saved presets persist independently of older preferences.
- Explicitly label starter settings as macOS choices, not ASUS factory defaults. Music is ambient breathing, not audio-reactive.
- Added nine rear color swatches.
- Preset application stops capture/calibration before taking control; front writes retain verified readback and the 178-point channel budget.
- Fixed the async serialization test's timing assumption; added four preset regressions (23 tests total).
- Bundle version 0.3.0 (9). Screen Sync and recovery limitations remain as documented.

## 0.3.0-beta.1 — 2026-10-19

- Added a regular tabbed window opened from the menu bar, with version, errors, help, settings, and diagnostics.
- Serialized UI operations so concurrent commands cannot skip first-write verification.
- Kept the last lit brightness and temperature when the lamp is off; physical controls are polled every three seconds.
- Bound authorization to the USB registry instance. Connection changes invalidate the write gate. Multiple attached ALB01 devices are rejected instead of picked randomly.
- Rebuilt Screen Sync with a separate worker and one-frame mailbox per capture session. Stopped sessions cannot submit frames into newer sessions.
- Added capture error handling, complete-frame validation, first-frame timeout, bounded UI progress updates, and per-LED color previews.
- Listed displays without capturing their contents; added an explicit macOS capture-permission request.
- Prevented rear effects and calibration from competing with Screen Sync. Calibration has an explicit end/restore action.
- Stored validated settings, added erase confirmation, and provided both enable and disable for launch at login.
- Added regression tests for UI state and BGRA sampling, plus release-check scaffolding.

- Added a native Xcode application project, MIT license under Jonathan Hogue, research credits, and release documentation.
- Treat capture preflight as advisory; Start Sync uses ScreenCaptureKit's actual authorization result.

- Final polish: visible beta status, full license viewer, repository/help link, clearer capture-permission wording, and cancellation of pending rear changes when erasing preferences.

First public beta candidate; app bundle version 0.3.0 (8). Packet/unit-test success is distinguished from visual hardware confirmation and ScreenCaptureKit validation on the installed app. See VALIDATION.md for outstanding checks.

## 0.2.0 — prototype

Added basic diagnostics, preferences, and Screen Sync permission status. Capture lifecycle and UI verification remained incomplete.

## 0.1.x — protocol prototype

Implemented native HID discovery, readback, front/rear packet builders, and the initial SwiftUI controls.

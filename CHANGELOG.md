# Changelog

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

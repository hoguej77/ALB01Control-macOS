# ALB01Control for macOS — v0.3.0-beta.2

An independent, native Swift/SwiftUI controller for the ASUS ROG Aura Monitor Light Bar ALB01.

## Downloads

- **ALB01Control-v0.3.0-beta.2-macos-arm64.zip** — Apple Silicon app, macOS 14+ deployment target. Extract and move the app to Applications.
- **ALB01Control-v0.3.0-beta.2-source.zip** — matching source, Xcode project, tests, documentation, and MIT license. GitHub also provides tag-based source archives.
- **SHA256SUMS.txt** — checksums for the two ZIPs.

The app bundle identifies itself as 0.3.0 (9). This is a **beta**, not a stable or ASUS-endorsed release. It is ad-hoc signed and **not Apple-notarized**; macOS may block opening it. Review the code/checksums and README installation guidance before approving it. No Intel binary is included.

## New in beta 2

Reading, Game, Night View, Theater, Music, User Mode 1, and User Mode 2 preset slots, with Apply/Save/Reset and nine standard rear colors. Slot names match ASUS's ALB01 DisplayWidget screenshot; numeric defaults are independently chosen macOS starter settings, not ASUS factory values. Music is ambient breathing, not audio-reactive. Strobing and full Armoury Crate parity are not included.

This release also includes the deterministic async-test correction from main after beta 1.

## Included

- Front lamp power, brightness, temperature, and device readback.
- Rear Aura off/static/breathing/spectrum controls.
- Experimental ScreenCaptureKit sync with discovered LED count, per-zone or uniform colors, smoothing, reverse order, calibration, and a latest-frame-only queue.
- Menu-bar access, tabbed control window, diagnostics, saved preferences, erase-data confirmation, and launch-at-login control.
- Read-only discovery followed by same-state lamp verification before control writes.

## Validation and known limitations

- 23 automated tests pass; release Swift build and native Xcode project build pass locally.
- Previous attached-device testing verified VID/PID, HID usage, 65-byte reports, config, three discovered LEDs, front-lamp write/readback, off/restore, and brightness/temperature mapping.
- **Live Screen Sync is not yet verified end-to-end.** macOS displayed permission enabled while the earlier app's preflight check returned denied. This build attempts the actual ScreenCaptureKit operation; that change still needs installed-app validation.
- Rear commands have USB-acceptance evidence, not confirmed visual output or measured rear-state readback.
- Sleep/wake, KVM changes, reconnection, and long-running capture require further live testing.
- Stopping sync restores the last rear mode sent in this app session; when unknown, it uses rear Off.
- Only one connected ALB01 is supported. Screen capture supports at most 20 discovered LEDs.
- macOS 14 is the deployment target, not a claim that every macOS version has been tested.

See VALIDATION.md for the evidence boundary. The app does not save or upload screen images, capture audio, or send telemetry.

## Credits and license

Copyright © 2026 Jonathan Hogue. Original app code: MIT License.

Protocol research thanks to [dvalfrid/rigstats](https://github.com/dvalfrid/rigstats) and [UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker](https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker). OpenRGB was used as a protocol reference only; no GPL implementation was copied. ASUS documentation informed product capabilities. Exact research revisions and links are in RESEARCH.md.

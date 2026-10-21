# ALB01Control for macOS

ALB01Control is a native macOS menu-bar controller for the ASUS ROG Aura Monitor Light Bar (ALB01). It talks to the light bar directly through macOS IOKit HID—no Python runtime, driver, Armoury Crate, or network service.

**Beta software:** front-lamp controls have hardware-readback validation, but visible rear effects and reconnect/sleep behavior are not fully validated. Do not treat this as a stable or official ASUS release.

## Download and install

Use the **Releases** section of this repository for the Apple Silicon (`arm64`) app ZIP, matching source archive, release notes, and SHA-256 checksums. The app targets macOS 14 or newer; compatibility has not been tested on every supported macOS version. No Intel binary is provided in this beta.

1. Extract the app ZIP and move `ALB01Control.app` to Applications.
2. Open it and connect your ALB01 through a USB data cable.
3. This beta is ad-hoc signed, **not Developer ID signed or notarized**. macOS may block it. Review the source and release checksum before deciding whether to use macOS's per-app **Open Anyway** option in Privacy & Security. Do not disable Gatekeeper globally. Building from source is also supported.
4. Screen Sync is removed from this version. No Screen Recording permission is needed or requested. You may revoke any permission granted to an older version.

See [release notes](RELEASE_NOTES.md) and [validation status](VALIDATION.md) before installing.

Use Xcode 16+ (Swift 6), targeting macOS 14+. Open `ALB01Control.xcodeproj` for a native application target, or `Package.swift` for the shared modules, diagnostic CLI, and tests. Local development is unsandboxed; a sandboxed distribution would need the USB-device entitlement.

## What it controls

ASUS describes three physical lighting arrangements: the front desk/screen light, the rear Aura RGB lighting, and both together. ALB01Control keeps those areas independent so their behavior is unambiguous.

| Area | Controls | Verification |
| --- | --- | --- |
| Front desk light | Power, 1–100% brightness, 2700–6500 K | Each change reads the channels back from the device. |
| Rear Aura RGB | Off, static, breathing, spectrum, color, brightness | HID writes are allowed only after the safety check. |

The ALB01 is USB 5 V / 1 A (5 W maximum). ASUS documents a physical power/Aura button and a brightness/color-temperature roller; use **Refresh** beside Live readback after physical changes.

## Mac lighting scenes

The 0.4.0 beta includes **Focus, Daylight, Evening, Cinema, Ambient, Custom 1, and Custom 2**. These are independently chosen, adjustable Mac lighting scenes. Existing stored scene identifiers and customized light values are preserved. Older 0.3.0 downloads retain the earlier PC-style names.

- Select a slot, then **Apply scene** to set the front and rear together.
- **Save current** stores the current app settings in that slot, including front power state, brightness, temperature, rear effect, color, and intensity. It does not read an unknown rear hardware mode.
- **Reset** restores that slot's starter values without changing the lights; click Apply scene when ready.
- Nine standard color swatches provide one-click rear colors.
- **Match desk warmth** creates a soft 20% solid backlight that complements the current desk-light warmth. It is an aesthetic sRGB palette, not a calibrated white-point measurement.
- No audio-reactive mode is implemented; the app requests no microphone/audio permission.
- Strobing and broader Armoury Crate effects are not implemented. These presets do not imply full Armoury Crate parity.

## Siri and Shortcuts (0.4.0 preview)

The native app exposes five Mac App Intent actions: Set Desk Light Power, Set Desk Light Brightness, Set Desk Light Warmth, Apply Lighting Scene, and Switch Off Desk and Ambient Lights.

**Current limitation:** all five actions appear in macOS Shortcuts, but execution failed on the local ad-hoc build. The system rejected the app process because it could not obtain an Apple Team ID. No valid Apple signing identity is installed. Siri/Shortcuts control is experimental, not a working feature of this unsigned preview; ordinary lighting controls remain independent of it. A genuinely Apple-team-signed build and another end-to-end test are required. Do not fabricate a Team ID or weaken system protections.

Open Shortcuts, create a shortcut, search for ALB01Control in the action library, configure an action, and save it with a short name such as **Desk Light Off**. Siri can run the saved shortcut by name when Siri is enabled on the Mac. Apple distinguishes these Mac actions from automatically provisioned App Shortcuts. See the [platform guidance](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts).

Actions open the app, use the same serialized controller as the UI, validate ranges, and wait for front-lamp readback. A disconnected/busy device returns an error instead of a success claim. Brightness and warmth actions turn the desk light on.

Use `Scripts/build-app.sh` to package the native Xcode Release app, including extracted App Intents metadata. A hand-made app bundle around a SwiftPM executable does not include this metadata.
Set `ALB01_SIGN_IDENTITY` to an existing valid Apple code-signing identity to sign the local package; otherwise the script explicitly produces an ad-hoc preview. This does not notarize the app or establish that its actions execute successfully.

## Safe first use

1. Connect the bar through a USB **data** path, not charge-only power.
2. Open **ALB01Control**. Its window contains Lighting studio, Diagnostics, and Settings & about. The menu-bar item provides quick power and window access. Startup performs read-only discovery.
3. Confirm Connection reports `0B05:1AC8`, `FF72/00A1`, and 65-byte input/output reports.
4. The first control action writes back the already-read front-lamp state and verifies it. That check has no visible lamp change.
5. Use the controls: Power/effect/color apply immediately; brightness sliders apply when released. The buttons repeat the current setting.

The app does not seize the HID device. Authorization is tied to the registry instance of the USB connection. A sleep/wake, KVM, cable, or hub failure invalidates it. Read-only USB reconnection retries every three seconds. The app refuses ambiguous multiple-bar connections.

## Lighting only — no screen capture

Screen Sync, screen-color sampling, display selection, frame counters, capture-rate options, and calibration were removed in 0.4.0 (15). The app does not link ScreenCaptureKit, request Screen Recording permission, enumerate displays, inspect Safari, or track monitor refresh rate. Its three-second readback checks only the USB light bar, not the screen or GPU.

The user reported Safari video turning black while the earlier app was open and returning after it quit. This is evidence of an interaction, not a verified root cause. The capture implementation remains available in Git history for a separately researched and profiled future version; it is not shipped as a hidden toggle.

## Help, data, and recovery

**Copy report** on Diagnostics includes app version, OS version, product name, VID/PID, HID usage, report sizes, LED count, configuration reply, and recent activity. Review it before attaching it to an issue.

**Erase saved app data** clears this app's stored preferences and in-memory activity after confirmation. It sends no light-setting command. macOS permissions, launch-at-login registration, and system Console messages are managed separately. The Help & Settings tab provides both enable and disable for launch at login.

Device readback polls every three seconds and pauses while a control is being edited. Turning off preserves the last lit brightness and temperature for the next power-on. The front lamp's readback is measured; rear effect status reports USB command acceptance, not visually verified output.

If discovery fails:

1. Use a known-good USB-C data cable.
2. Bypass the KVM/hub and connect directly to the Mac.
3. Confirm the CLI discovery values below; reconnect one USB hop at a time.
4. If the device is present but writes fail, power-cycle the bar and click **Refresh read-only probe**.

The development bar enumerated through a USB hub, but cable/KVM/power changes can break the route. ASUS notes that input below 5 V can make the power indicator blink; use a port that supplies the documented 5 V input.

## CLI diagnostics

The CLI defaults to read-only behavior:

```zsh
swift run alb01-diagnostics
swift run alb01-diagnostics --discover-only
```

State-changing tests require opt-in:

```zsh
# Exact current lamp state write-back and readback
swift run alb01-diagnostics --verify-writeback

# Off → readback → restore original front-lamp state
swift run alb01-diagnostics --verify-writeback --lamp-off-on-test

# 50% / 4600 K (expected 44/45) → readback → restore
swift run alb01-diagnostics --verify-writeback --lamp-mapping-test

# Static → breathing → spectrum → off for rear Aura
swift run alb01-diagnostics --verify-writeback --rear-acceptance-sequence
```

## Build and test

```zsh
swift test
zsh Scripts/build-app.sh
open dist/ALB01Control.app
```

The script produces an ad-hoc-signed local bundle, not a notarized release. Beta downloads disclose this limitation; a polished distribution should use Apple Developer signing/notarization. The checked-in Xcode project can be opened directly without XcodeGen. Maintainers can regenerate it from `project.yml` using XcodeGen.

From a clean, committed checkout, `zsh Scripts/package-release.sh v0.4.0-beta.1` builds the app and creates matching app/source ZIPs, release notes, and checksums under `release-artifacts/`. The script refuses to overwrite an existing release directory. Build the release commit/tag you intend to publish; no credentials or signing certificates belong in the repository.

## Protocol and test coverage

`ALB01Protocol` independently validates every report before IOKit receives it:

- VID/PID `0B05:1AC8`, Aura HID collection `FF72/00A1`;
- report prefix `EC`, exactly 65 bytes;
- `EC B0` config probe and LED count from `EC30` byte 32;
- `EC31 01` / `EC B1 01` front-lamp read and channels from `EC3101` bytes 10/11;
- `EC3501000001000001 COOL WARM` front write, capped at 178 total;
- static, breathing, spectrum, direct mode, and max-20 LED direct frames.

Unit tests check packet size/prefixes, parser offsets, brightness mapping, frame limits, and proportional RGB. Hardware verification has confirmed discovery, config/LED count, lamp readback, no-change write/readback, Off/readback/restore, 50%/4600 K readback, and direct-frame acceptance. No screen capture is included.

## GitHub readiness

Copyright © 2026 Jonathan Hogue. Original app code is available under the [MIT License](LICENSE). This is an independent macOS implementation, not an official ASUS product or a Windows executable port.

The project has no network telemetry and stores local preferences in `UserDefaults`. Activity is held in memory, and operational messages are sent to macOS Console. The macOS CI workflow is configured to run non-hardware tests and build the bundle. See VALIDATION.md for checks completed locally and remaining beta limitations, and CHANGELOG.md, RESEARCH.md, and CONTRIBUTING.md for release history, source revisions, and contribution guidance.

### Research acknowledgments

Thanks to dvalfrid's **RIGStats** for hardware-verified ALB01 front-light protocol research, and UladzimirB-dev's **Monitor-Lightbar-alb01-Unlocker** for rear Aura and Ambilight research. Their repositories remain the upstream research references linked below; this app adds a separate native macOS implementation.

No source code was copied from [RIGStats](https://github.com/dvalfrid/rigstats) (MIT), [Monitor-Lightbar-alb01-Unlocker](https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker) (MIT), or [OpenRGB’s AsusMonitorController](https://github.com/CalcProgrammer1/OpenRGB/tree/master/Controllers/AsusMonitorController) (GPL-2.0-or-later); they were research references only.

Official references: [ASUS ALB01 product page](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/) and [ASUS ALB01 manual/support page](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/helpdesk_manual/).

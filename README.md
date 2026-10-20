# ALB01Control for macOS

ALB01Control is a native macOS menu-bar controller for the ASUS ROG Aura Monitor Light Bar (ALB01). It talks to the light bar directly through macOS IOKit HID—no Python runtime, driver, Armoury Crate, or network service.

**Beta software:** front-lamp controls have hardware-readback validation, but live Screen Sync, visible rear effects, and reconnect/sleep behavior are not fully validated. Do not treat this as a stable or official ASUS release.

## Download and install

Use the **Releases** section of this repository for the Apple Silicon (`arm64`) app ZIP, matching source archive, release notes, and SHA-256 checksums. The app targets macOS 14 or newer; compatibility has not been tested on every supported macOS version. No Intel binary is provided in this beta.

1. Extract the app ZIP and move `ALB01Control.app` to Applications.
2. Open it and connect your ALB01 through a USB data cable.
3. This beta is ad-hoc signed, **not Developer ID signed or notarized**. macOS may block it. Review the source and release checksum before deciding whether to use macOS's per-app **Open Anyway** option in Privacy & Security. Do not disable Gatekeeper globally. Building from source is also supported.
4. Screen Sync additionally requires Screen Recording permission. It processes display colors locally and captures no audio.

See [release notes](RELEASE_NOTES.md) and [validation status](VALIDATION.md) before installing.

Use Xcode 16+ (Swift 6), targeting macOS 14+. Open `ALB01Control.xcodeproj` for a native application target, or `Package.swift` for the shared modules, diagnostic CLI, and tests. Local development is unsandboxed; a sandboxed distribution would need the USB-device entitlement.

## What it controls

ASUS describes three physical lighting arrangements: the front desk/screen light, the rear Aura RGB lighting, and both together. ALB01Control keeps those areas independent so their behavior is unambiguous.

| Area | Controls | Verification |
| --- | --- | --- |
| Front desk light | Power, 1–100% brightness, 2700–6500 K | Each change reads the channels back from the device. |
| Rear Aura RGB | Off, static, breathing, spectrum, color, brightness | HID writes are allowed only after the safety check. |
| Screen Sync | Per-LED/uniform, intensity, smoothing, 30/60 fps, calibration | The app counts direct HID frames delivered. |

The ALB01 is USB 5 V / 1 A (5 W maximum). ASUS documents a physical power/Aura button and a brightness/color-temperature roller; use **Refresh** beside Live readback after physical changes.

## Safe first use

1. Connect the bar through a USB **data** path, not charge-only power.
2. Open **ALB01Control**. Its regular window contains Lights, Screen Sync, Diagnostics, and Help & Settings tabs. The menu-bar item provides quick power and window access. Startup performs read-only discovery.
3. Confirm Connection reports `0B05:1AC8`, `FF72/00A1`, and 65-byte input/output reports.
4. The first control action writes back the already-read front-lamp state and verifies it. That check has no visible lamp change.
5. Use the controls: Power/effect/color apply immediately; brightness sliders apply when released. The buttons repeat the current setting.

The app does not seize the HID device. Authorization is tied to the registry instance of the USB connection. A sleep/wake, KVM, cable, or hub failure invalidates it. Read-only reconnection retries every three seconds; Screen Sync requires an explicit restart. The app refuses ambiguous multiple-bar connections.

## Screen Sync

Screen Sync drives **only the rear Aura RGB LEDs**; the desk light remains independent.

1. Click **Request access** on the Screen Sync tab. Enable **Screen Recording** for ALB01Control in System Settings → Privacy & Security → Screen & System Audio Recording, then quit/reopen if macOS requests it.
2. Click **Refresh**. If macOS shows access enabled but the indicator disagrees, Start Sync attempts the actual ScreenCaptureKit operation and reports the result. Development builds can require permission renewal after replacement.
3. Select a display. The Neo G9 is 5120×1440, but capture is intentionally 320×90 BGRA: only color zones are needed, not full-resolution video.
4. Run **Test LED order**. Red → green → blue should appear left-to-right. Click **End calibration**, enable Reverse LED Order if needed, then test again.
5. Start at 30 fps. After the frame counter rises and output is stable, optionally try 60 fps.

Per-LED mode divides the screen horizontally by the discovered LED count. Uniform mode sends the same average color to each LED. Smoothing retains a portion of the previous sample to reduce flicker; intensity proportionally scales RGB without clipping. Stop before changing sampling settings. Stopping sync restores the last Aura effect successfully sent by the current app session; if it has not sent one, it turns the rear LEDs off. The app cannot restore an unknown physical rear mode. Rear controls are disabled while sync or calibration owns the LEDs.

Running means at least one complete capture frame was accepted by the HID transport. The swatches show the colors sent, and the counter updates four times per second. A static screen may not generate frames at the maximum capture rate; protected content may be black. Capture errors are reported, and a four-second first-frame timeout prevents a false Running status.

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
./Scripts/build-app.sh
open dist/ALB01Control.app
```

The script produces an ad-hoc-signed local bundle, not a notarized release. Beta downloads disclose this limitation; a polished distribution should use Apple Developer signing/notarization. The checked-in Xcode project can be opened directly without XcodeGen. Maintainers can regenerate it from `project.yml` using XcodeGen.

From a clean, committed checkout, `zsh Scripts/package-release.sh v0.3.0-beta.1` builds the app and creates matching app/source ZIPs, release notes, and checksums under `release-artifacts/`. The script refuses to overwrite an existing release directory. Build the release commit/tag you intend to publish; no credentials or signing certificates belong in the repository.

## Protocol and test coverage

`ALB01Protocol` independently validates every report before IOKit receives it:

- VID/PID `0B05:1AC8`, Aura HID collection `FF72/00A1`;
- report prefix `EC`, exactly 65 bytes;
- `EC B0` config probe and LED count from `EC30` byte 32;
- `EC31 01` / `EC B1 01` front-lamp read and channels from `EC3101` bytes 10/11;
- `EC3501000001000001 COOL WARM` front write, capped at 178 total;
- static, breathing, spectrum, direct mode, and max-20 LED direct frames.

Unit tests check packet size/prefixes, parser offsets, brightness mapping, frame limits, and proportional RGB. Hardware verification has confirmed discovery, config/LED count, lamp readback, no-change write/readback, Off/readback/restore, 50%/4600 K readback, and direct-frame acceptance. Screen capture requires the user’s macOS permission.

## GitHub readiness

Copyright © 2026 Jonathan Hogue. Original app code is available under the [MIT License](LICENSE). This is an independent macOS implementation, not an official ASUS product or a Windows executable port.

The project has no network telemetry and stores local preferences in `UserDefaults`. Activity is held in memory, and operational messages are sent to macOS Console. The macOS CI workflow is configured to run non-hardware tests and build the bundle. See VALIDATION.md for checks completed locally and remaining beta limitations, and CHANGELOG.md, RESEARCH.md, and CONTRIBUTING.md for release history, source revisions, and contribution guidance.

### Research acknowledgments

Thanks to dvalfrid's **RIGStats** for hardware-verified ALB01 front-light protocol research, and UladzimirB-dev's **Monitor-Lightbar-alb01-Unlocker** for rear Aura and Ambilight research. Their repositories remain the upstream research references linked below; this app adds a separate native macOS implementation.

No source code was copied from [RIGStats](https://github.com/dvalfrid/rigstats) (MIT), [Monitor-Lightbar-alb01-Unlocker](https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker) (MIT), or [OpenRGB’s AsusMonitorController](https://github.com/CalcProgrammer1/OpenRGB/tree/master/Controllers/AsusMonitorController) (GPL-2.0-or-later); they were research references only.

Official references: [ASUS ALB01 product page](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/) and [ASUS ALB01 manual/support page](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/helpdesk_manual/).

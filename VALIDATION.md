# Validation status

Current release: v0.4.0-beta.2 / app 0.4.0 (14), October 20, 2026.

## Lighting-only scope

- Screen Sync removed: no capture engine, ScreenCaptureKit package dependency, display enumeration, frame/rate UI, calibration, or screen permission prompt.
- 27 automated tests cover retained lighting/protocol safety, serialization, scenes, numeric entry, automation input guards, and migration that drops obsolete screen keys without losing lighting values.
- Prior to reinstall, live hardware enumeration reported 0B05:1AC8, FF72/00A1, 65-byte input/output reports, three LEDs, and lamp 39/66; writing the identical 39/66 channels passed readback.
- User reported Safari video returning after the previous app quit. Root cause and post-removal long-running Safari behavior are not verified.
- Voice automation remains blocked by missing Apple team signing. Optical rear output, sleep/KVM recovery, narrow layout, and broad OS compatibility remain unverified.

The sections below preserve historical results; Screen Sync is not an outstanding feature to validate in this release.

## Local 0.4.0 (12) preview — October 20

- 30 automated tests pass, including validated exact entry, scene migration, and automation input guards.
- Native Xcode Release build, Swift 6, optimization `-O`; extracted metadata contains five discoverable App Intents.
- All five actions appeared in the actual macOS Shortcuts library. Desk Light Off failed before execution: the system could not obtain an Apple Team ID from the ad-hoc app. No valid Apple signing identity is installed. Siri is not verified.
- Installed app connected to the three-LED ALB01 and read front-off state. Existing user-selected rear settings were preserved.
- Dark/light appearance and keyboard navigation exercised. Manual narrow-window layout, Screen Sync optical output, and stress testing remain outstanding.

The following sections preserve historical beta 2 results, not new verification of the preview.

## Completed locally

- Swift package: 23 tests passed, zero failures (protocol 8, screen-color/memory-boundary checks 6, UI-state checks 5, preset checks 4).
- Swift release build for arm64 with macOS 14 deployment target.
- Native Xcode project Debug build with signing disabled.
- Local app ad-hoc signature and Info.plist validation.

Build environment: installed Xcode beta with macOS 27 SDK on an Apple Silicon Mac. These are local results, not a claim of remote CI or broad OS compatibility.

## Prior hardware session (2026-10-16)

- Attached ALB01 enumerated as 0B05:1AC8, usage FF72/00A1, with 65-byte input/output reports.
- Configuration reply reported 3 rear LEDs; no hard-coded four-LED assumption.
- Read-only front-lamp state and no-visible-change write/readback succeeded.
- Front off/readback/restore and 50% / 4600 K mapping (44/45 channels) succeeded.
- Installed build 0.3.0 (6) UI exercised off/on, brightness, and temperature with measured feedback.
- Rear/direct command transport accepted packets. This is not visual confirmation.

## Preset hardware/UI session (2026-10-19)

- Installed build 9 connected to the same 3-LED ALB01 and verified front readback.
- Saved existing front-off/rear-breathing app settings to User Mode 1 without sending a light-setting command.
- Applied Reading: front readback confirmed 60.112% / 5008 K (integer-channel quantization of the 60% / 5000 K request); rear-off command accepted.
- Applied saved User Mode 1: front-off readback confirmed, previous stored on-level restored, rear-breathing command accepted.
- Rear visible output was not measured; these results do not establish optical verification.

## Not yet validated

- Build 9 installed-app ScreenCaptureKit first-frame delivery, visible per-LED response, stop/restart, and unchanged front lamp during capture.
- Sleep/wake and physical disconnect/reconnect/KVM stress.
- Long-duration 30/60 fps behavior.
- Intel hardware and all deployment-target OS versions.
- Beta 2 remote GitHub Actions results, until its workflow actually runs. The preceding main revision passed after replacing a timing-sensitive async test with explicit synchronization.

Do not promote this beta to a stable release based solely on unit tests. When reporting hardware problems, review diagnostic output before sharing and do not include private screen content.

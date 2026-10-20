# Validation status

Release candidate: v0.3.0-beta.1 / app 0.3.0 (8), prepared 2026-10-19.

## Completed locally

- Swift package: 19 tests passed, zero failures (protocol 8, screen-color/memory-boundary checks 6, UI-state checks 5).
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

## Not yet validated

- Build 8 installed-app ScreenCaptureKit first-frame delivery, visible per-LED response, stop/restart, and unchanged front lamp during capture.
- Sleep/wake and physical disconnect/reconnect/KVM stress.
- Long-duration 30/60 fps behavior.
- Intel hardware and all deployment-target OS versions.
- Remote GitHub Actions results, until a workflow actually runs.

Do not promote this beta to a stable release based solely on unit tests. When reporting hardware problems, review diagnostic output before sharing and do not include private screen content.

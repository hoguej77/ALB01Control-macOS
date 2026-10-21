# ALB01Control for macOS — v0.4.0-beta.2

An independent native Swift/SwiftUI controller for the ASUS ALB01 monitor light bar. Created by Jonathan Hogue; original code is MIT licensed. Not affiliated with or endorsed by ASUS.

## New in Lighting Studio

- Redesigned window with a navigation rail, light-bar/monitor preview, paired desk and ambient controls, and a light-bar menu icon.
- Focus, Daylight, Evening, Cinema, Ambient, and two custom scenes. Existing customized values are preserved. Scene names describe activities rather than promising PC Armoury Crate parity.
- Match desk warmth: a complementary soft solid backlight. It is an aesthetic palette, not calibrated white-point matching.
- System/Light/Dark appearance, keyboard navigation, exact brightness/temperature entry, and visible author credit.
- Native optimized Xcode Release build with five experimental App Intent actions.
- **Screen Sync removed for now:** no display selector, capture-rate controls, frame counter, calibration, Screen Recording prompt, or ScreenCaptureKit dependency. Ordinary lighting control only.

## Downloads and installation

- **ALB01Control-v0.4.0-beta.2-macos-arm64.zip** — Apple Silicon app; macOS 14+ deployment target. Extract and move ALB01Control.app to Applications.
- **ALB01Control-v0.4.0-beta.2-source.zip** — matching source, Xcode project, tests, documentation, and MIT license.
- **SHA256SUMS.txt** — checksums for both ZIPs.

The app identifies as **0.4.0 (14)**. It is ad-hoc signed, **not Developer ID signed or Apple-notarized**. macOS may block it; review the source, checksum, and README before approving a per-app exception. Do not disable system security protections. No Intel binary is included.

## Validation and important limitations

- All **27 automated tests pass locally**. Native Xcode Release build and signature verification pass. Build optimization is `-O`; no successful Instruments performance trace is claimed.
- The attached ALB01 enumerates with three discovered LEDs and provides front-lamp readback. Earlier device sessions verified no-visible-change write gating, power, brightness, and temperature. Reinstallation preserves preferences and does not apply a scene at startup.
- **Siri/Shortcuts is not operational in this ad-hoc build.** All five actions appear in the real Shortcuts library, but macOS rejects execution because the app has no Apple Team ID. No valid signing identity is installed on the development Mac. An Apple-team-signed build and another end-to-end test are required. Ordinary app controls are independent of this limitation.
- A user reported Safari video blacking out with the earlier app open and returning after quit. The interaction is not root-cause confirmed. Screen capture is removed rather than left enabled or hidden; its earlier implementation remains in Git history for future investigation. This release does not read monitor refresh rate or modify Safari. Sleep/wake and USB/KVM recovery still need hardware stress testing.
- Rear packets have USB-acceptance evidence, not measured optical output or rear-state readback. The preview shows settings, not measured illumination.
- No music/audio-reactive mode, microphone capture, cross-device Aura Sync, or full Armoury Crate parity. Breathing is simply an optional hardware effect.
- macOS 14 is the deployment target, not a claim that every supported OS version has been tested. A manual narrow-window layout check also remains outstanding.

See VALIDATION.md and ENGINEERING_PLAN.md for evidence and remaining work. No screen images or audio are captured. The app sends no telemetry.

## Credits

Copyright © 2026 Jonathan Hogue. MIT License.

Protocol research thanks to [dvalfrid/rigstats](https://github.com/dvalfrid/rigstats) and [UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker](https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker). OpenRGB was a protocol reference only; no GPL implementation was copied. Apple and ASUS primary documentation informed platform and hardware decisions. Exact references are in RESEARCH.md and ENGINEERING_PLAN.md.

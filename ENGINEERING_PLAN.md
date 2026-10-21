# Research-led quality pass — 2026-10-20

This is the implementation contract for one local preview pass, not a stable-release claim.

## Evidence and decisions

| Primary source | Finding | Implementation requirement |
| --- | --- | --- |
| [Apple: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) | Resizable windows, keyboard commands, comfortable information density, personalization | Navigation commands with shortcuts; narrower-window layout; deliberate appearance preference |
| [Apple: Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | macOS default text 13 pt, minimum 10 pt; avoid tiny/light text | Main labels 13 pt; no product text below 10 pt; supporting text at least 11 pt |
| [Apple: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Small text contrast 4.5:1; keyboard access; state conveyed beyond color | Measure palette contrast; named controls and selection traits; visible focus; textual device states |
| [Apple: Color](https://developer.apple.com/design/human-interface-guidelines/color) | Color variants for appearance and contrast preferences | Semantic light/dark colors and Increase Contrast handling |
| [ASUS: ALB01](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/) | Front, rear, and combined lighting; 2700–6500 K; DisplayWidget interface | Keep independent front/rear controls; preserve verified packet range |
| [ASUS: DisplayWidget guide](https://rog.asus.com/us/support/faq/1050223/) | Function support depends on device model | Do not infer all Armoury Crate or monitor functions apply to ALB01 |
| ALB01 DisplayWidget screenshot linked in RESEARCH.md | A Music slot exists; its audio implementation and exact preset values are not specified | Replace the misleading Music activity with a steady Ambient scene; retain its stored ID and customized settings |
| Local capture/mailbox inspection | LatestFrameMailbox already grants one drain and replaces pending frames | Preserve this existing performance behavior; no speculative queue rewrite |

## Fixed scope

1. Refine the current Lighting Studio shell; retain the light-bar symbol and Jonathan Hogue credit.
2. Correct typography, palette contrast, focus treatment, and button hit areas.
3. Reflow control panels and scene tiles when the window narrows.
4. Add System/Light/Dark appearance selection and standard navigation/settings/About commands.
5. Provide exact front brightness/temperature entry with validation; commit through the same serialized readback path.
6. Make scene behavior explicit before Apply, and migrate Music metadata without discarding customized lighting values.
7. Identify rear state as unconfirmed until this session has sent a rear setting.

## User steering incorporated

The user requested native Siri/Shortcuts integration and a Mac-focused lighting flow instead of PC Aura terminology. The pass now includes five App Intents using the shared serialized controller, purpose-based Focus/Daylight/Evening/Cinema/Ambient scenes, and an aesthetic Match Desk Warmth backlight action. Stable scene identifiers and customized values are preserved.

Apple's [Mac App Shortcuts guidance](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts) distinguishes Mac App Intent actions, which users combine into named shortcuts, from preconfigured App Shortcuts. The UI explains saving a named shortcut and invoking it with Siri. No unsupported automatic phrase registration is claimed.

Packaging now uses the native Xcode Release target so the app includes extracted App Intents metadata; a hand-made bundle around a SwiftPM binary omits it. The build refuses missing metadata. Runtime voice recognition and Shortcuts discovery require system testing, separately from compilation.

Real audio-reactive capture, strobing, guessed firmware fields, and new packet modes are outside this pass. Screen Sync is removed from the current product scope, not merely marked experimental.

## Acceptance and delivery

- One complete implementation before running tests/builds; repair only observed failures.
- Regression tests for preset migration and numeric input validation.
- Existing protocol/state/screen-color tests remain passing.
- Release build and native Xcode build pass.
- Inspect actual dark/light layouts, narrow resizing, keyboard navigation, scene staging, and credit/license access.
- Measure primary/secondary text contrast in both palettes.
- Install once after inspection, preserve a recoverable prior app, save screenshots and a source checkpoint.
- Do not claim visual rear output, audio reactivity, or stable-release validation without evidence.

## Final user scope change: lighting only

On October 20 the user asked to remove the entire Screen Sync feature for now after reporting Safari video turning black with the earlier app open and returning after it quit. That observation is not a confirmed root cause. Build 14 removes ScreenCaptureKit and the capture module, display enumeration, capture permissions, rate/frame controls, calibration, and screen-specific settings. Existing lighting preferences and custom scenes remain; obsolete screen keys are ignored and omitted on save. The prior code is preserved in Git history for a separately researched, optimized, hardware-tested future feature. Binary dependency verification must show no ScreenCaptureKit link before reinstalling.

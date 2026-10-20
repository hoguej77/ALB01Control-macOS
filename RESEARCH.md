# Research and implementation boundaries

Reviewed 2026-10-16. No third-party implementation code is incorporated.

## Primary references

- [ASUS ALB01 product page](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/): front Screen Light, rear Aura RGB, and combined use; 2700–6500 K; physical controls and DisplayWidget Center.
- [ASUS support/manual](https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/helpdesk_manual/): 5 V / 1 A power, low-voltage indicator, front/rear physical controls. The manual is not a USB protocol specification.
- [RIGStats AsusMonitorDevice.cs](https://github.com/dvalfrid/rigstats/blob/b9f4cf53d8e580356dfb079a96d82fda4c96b414/sensor-sidecar/Control/Lighting/AsusMonitorDevice.cs): verified ALB01 built-in effect packets, front write/readback, config byte 32, and remembering the last lit setting. Also reviewed AuraUsb.cs, AuraController.cs, LightingTests.cs and docs/control-architecture.md at the same revision. MIT reference.
- [ALB01 Unlocker](https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker/tree/3fd22929d73a84aae624b82c4ce1096addc198e0): Windows screen sampling and tray UX reference. Its hard-coded four LEDs and brightness-unlock claims are not used to override the discovered LED count or the verified front-lamp power budget. MIT reference.
- [OpenRGB AsusMonitorController](https://github.com/CalcProgrammer1/OpenRGB/tree/master/Controllers/AsusMonitorController): protocol background only; no GPL implementation is copied.
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit), [SCStreamDelegate](https://developer.apple.com/documentation/screencapturekit/scstreamdelegate), and [SCFrameStatus](https://developer.apple.com/documentation/screencapturekit/scframestatus): capture lifecycle and complete-frame handling.
- [ASUS ALB01 DisplayWidget screenshot](https://dlcdnwebimgs.asus.com/files/media/BF0909DA-FEFF-4420-B071-71E7495E0C7E/v1/images/ADVANCED-SETTINGS.webp), inspected 2026-10-19: Reading, Game, Night View, Theater, Music, User Mode 1/2; front controls; static/breathing/strobing/color-cycle UI and standard color swatches. The screenshot does not specify all preset channel values. Our named slots use independent starter values; Music does not imply audio reactivity, and strobing is not implemented.

## Capabilities that remain unverified

- Rear effect readback: the app displays command acceptance, not a claimed measured rear state.
- Exact rear mode before app ownership: if this session has never applied an Aura setting, stopping Screen Sync uses rear Off. It does not claim to restore an unknown physical-button mode.
- Firmware identification or update: the config bytes are not labeled as a firmware version without evidence.
- Cross-device ASUS Aura Sync and automatic ambient-light sensing: not implemented or inferred from product marketing.
- Screen Recording permissions require macOS approval for the installed app. Ad-hoc development signing can require permission renewal after replacement.

The stable-release gate includes exercising the installed UI, screen capture permission, first-frame delivery, visible color response, stop/restart, and USB reconnect. Unit tests alone do not satisfy those checks. The initial public beta explicitly documents unfinished validation in VALIDATION.md.

# Contributing

Use Swift 6 and Xcode 16 or newer on macOS 14+. Run `swift test` and `zsh Scripts/build-app.sh`. Tests do not require a light bar and do not send hardware packets.

Maintain these invariants:

- Discovery/read-only probes precede no-change verification; state changes need authorization for the same USB registry instance.
- Front lamp writes stay within the verified 178-point combined channel budget and require readback.
- Direct frames use the discovered LED count, with a maximum of 20.
- Only one rear owner is active: built-in Aura, calibration, or screen sync.
- Capture/USB delivery stays off the UI thread; stopped capture sessions cannot deliver to newer sessions.
- Reports must distinguish accepted USB commands, actual hardware readback, and visual confirmation.

Include OS/app version, concise reproduction steps, and a reviewed diagnostic report in bug reports. Do not attach screenshots of private screen content, signing credentials, or unreviewed logs. Confirm the license before publishing or incorporating third-party source code.

# Lighting Studio preview

Release build: 0.4.0 (14), October 20, 2026. The published beta 2 archives remain the earlier release.

The desktop layout uses a persistent navigation rail, a schematic monitor/light-bar preview, parallel front/rear controls, and a compact scene strip. The visual language is an original macOS interpretation of the ALB01 product presentation: near-black hardware surfaces, a restrained ROG-red primary accent, and a warm-to-cool desk-light scale. It does not include ASUS artwork or a copied/proprietary ROG typeface. Instead it uses the macOS system typeface at comfortable, accessible sizes. Device connection uses a separate green indicator. The preview depicts app settings rather than measured optical output.

The minimum content size is 820 × 650 points. Control pairs switch between one and two columns based on available width; scenes wrap. Main controls use 13-point labels, supporting text is at least 11 points, and schematic captions are at least 10 points. Technical chamfered panels distinguish controls from the window without turning the app into an imitation gaming launcher. Appearance supports System, Light, and Dark; palettes retain high-contrast text and selection never relies on color alone. Scene selection stages a choice; Apply scene sends it. Front sliders and validated exact-entry fields use the same readback workflow.

Jonathan Hogue is credited in the navigation rail, About content, copyright metadata, and bundled MIT license.

Navigation commands use Command-1 through Command-4; Settings uses Command-comma. Five App Intents provide power, brightness, warmth, scenes, and all-off. Production packaging uses Xcode Release optimization and requires extracted intent metadata.

The purpose-based scenes and Match Desk Warmth action treat the rear LEDs as ambient lighting, rather than presenting cross-device ASUS Aura Sync capability. The bar remains ASUS hardware; the Mac experience is independent.

Validation: 27 automated tests pass, including input, migration, and automation guards. The native optimized build includes five extracted discoverable actions. Dark/light UI and navigation were exercised. A native resize drag did not resize the review window, so a manual narrow-window check remains outstanding. Screen Sync is removed, including its framework dependency and screen permission prompt. The app is focused on USB lighting control.

All five actions were also discovered in the real Shortcuts action library. Running Desk Light Off failed at macOS process registration: the ad-hoc app has no Apple Team ID. No valid signing identity is installed. The UI and README label voice/Shortcuts control experimental; action execution and Siri are not verified.

Screen Sync is deferred at the user's request after reported Safari video interference. No screen/display enumeration, capture-rate setting, frame meter, or calibration ships in build 14. Standard USB lamp readback is unrelated to display refresh and remains available. The implementation is recoverable from Git history.

import SwiftUI
import AppKit
import ALB01Protocol

@main
struct ALB01ControlApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var model = ControlViewModel()
    var body: some Scene {
        Window("ALB01Control", id: "controls") {
            ControlPanel().environmentObject(model)
                .task { delegate.shutdown = { await model.prepareForQuit() }; model.start() }
        }
        .defaultSize(width: 680, height: 700)
        .windowResizability(.contentMinSize)
        MenuBarExtra("ALB01", systemImage: model.connected ? "lightbulb.2.fill" : "lightbulb.2") {
            MenuContents().environmentObject(model)
        }
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var shutdown: (() async -> Void)?
    private var terminating = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy must not own the same HID endpoint.
        if let id = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [])
            NSApp.terminate(nil)
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        Task { await shutdown?(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

private struct MenuContents: View {
    @EnvironmentObject var model: ControlViewModel
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Text(model.connected ? "Light bar connected" : "Light bar disconnected")
        Button("Open ALB01Control…") {
            openWindow(id: "controls")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button(model.frontOn ? "Turn desk light off" : "Turn desk light on") { model.setPower(!model.frontOn) }
            .disabled(!model.controlsAvailable)
        if model.syncing { Button("Stop Screen Sync") { model.stopSync() }.disabled(model.busy) }
        Divider()
        Button("Quit ALB01Control") { model.quit() }.keyboardShortcut("q").disabled(model.busy)
    }
}

private struct ControlPanel: View {
    @EnvironmentObject var model: ControlViewModel
    @State private var tab = "lights"
    @State private var confirmErase = false
    @State private var showLicense = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lightbulb.2.fill").font(.largeTitle).foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    HStack {
                        Text("ALB01Control").font(.title2.bold())
                        Text("BETA").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                    Text("ASUS ROG Aura Monitor Light Bar · v\(model.version)").foregroundStyle(.secondary).font(.caption)
                }
                Spacer()
                Circle().fill(model.connected ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(model.connected ? "Connected" : "Disconnected").font(.callout)
                Button("Reconnect") { model.reconnect() }.disabled(model.busy)
            }
            HStack(alignment: .top) {
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.status).font(.callout).textSelection(.enabled)
                Spacer()
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.callout).textSelection(.enabled)
            }
            TabView(selection: $tab) {
                lights.tabItem { Label("Lights", systemImage: "lightbulb") }.tag("lights")
                screenSync.tabItem { Label("Screen Sync", systemImage: "display") }.tag("sync")
                diagnostics.tabItem { Label("Diagnostics", systemImage: "waveform.path.ecg") }.tag("diagnostics")
                help.tabItem { Label("Help & Settings", systemImage: "questionmark.circle") }.tag("help")
            }
        }
        .padding(20).frame(minWidth: 610, minHeight: 580)
        .confirmationDialog("Erase saved preferences and activity?", isPresented: $confirmErase) {
            Button("Erase app data", role: .destructive) { model.eraseSettings() }
        } message: { Text("This clears local app settings and session activity. It sends no command to the lamp, and leaves macOS permissions and launch-at-login unchanged.") }
        .sheet(isPresented: $showLicense) {
            VStack(alignment: .leading, spacing: 16) {
                Text("MIT License").font(.title2.bold())
                ScrollView { Text(licenseText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Button("Done") { showLicense = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 520, height: 420)
        }
    }

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Copyright © 2026 Jonathan Hogue. MIT License. The full license is available in the source repository."
        }
        return text
    }

    private var lights: some View {
        Form {
            Section("Lighting presets") {
                Picker("Preset", selection: $model.selectedPresetID) {
                    ForEach(LightingPreset.builtIns) { Text($0.name).tag($0.id) }
                }.disabled(model.busy)
                Text(model.presetSummary).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Apply preset") { model.applySelectedPreset() }.buttonStyle(.borderedProminent)
                        .disabled(!model.controlsAvailable)
                    Button("Save current to preset") { model.saveCurrentPreset() }
                        .disabled(model.busy || model.syncing || model.calibrating)
                    Button("Reset preset") { model.resetSelectedPreset() }.disabled(model.busy)
                }
                Text("DisplayWidget-style slots with adjustable macOS starter values—not ASUS factory values. Save captures the app’s settings; Reset changes only the saved preset. Apply stops Screen Sync/calibration and changes both lights.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Front desk light") {
                Toggle("Desk light", isOn: Binding(get: { model.frontOn }, set: { model.setPower($0) }))
                    .disabled(!model.controlsAvailable)
                Slider(value: $model.settings.brightness, in: 1...100, step: 1, onEditingChanged: lampEditing) {
                    Text("Brightness · \(Int(model.settings.brightness.rounded()))%")
                }.disabled(!model.controlsAvailable || !model.frontOn)
                Slider(value: $model.settings.kelvin, in: 2700...6500, step: 50, onEditingChanged: lampEditing) {
                    Text("Temperature · \(Int(model.settings.kelvin.rounded())) K")
                }.disabled(!model.controlsAvailable || !model.frontOn)
                HStack {
                    Text("Warm · 2700 K").foregroundStyle(.orange)
                    Spacer()
                    Text("Cool · 6500 K").foregroundStyle(.cyan)
                }.font(.caption)
                Text(model.frontOn ? "Release a slider to apply. Each change is confirmed by device readback." : "Turning on restores the last lit brightness and temperature.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Device readback", value: model.lastReadText)
                HStack {
                    Text("Physical controls are checked every 3 seconds.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh now") { model.refreshReadback() }.disabled(!model.controlsAvailable)
                    Button("Apply desk light") { model.applyLamp() }.disabled(!model.controlsAvailable)
                }
            }
            Section("Rear Aura RGB") {
                Picker("Effect", selection: Binding(get: { model.settings.rearEffect }, set: { model.settings.rearEffect = $0; model.scheduleRear() })) {
                    Text("Off").tag(ALB01Protocol.AuraEffect.off)
                    Text("Static color").tag(ALB01Protocol.AuraEffect.staticColor)
                    Text("Breathing").tag(ALB01Protocol.AuraEffect.breathing)
                    Text("Spectrum cycle").tag(ALB01Protocol.AuraEffect.spectrum)
                }
                ColorPicker("Color", selection: Binding(get: {
                    let c = model.settings.rearColor
                    return Color(red: Double(c.red)/255, green: Double(c.green)/255, blue: Double(c.blue)/255)
                }, set: { color in
                    guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                    func channel(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
                    model.settings.rearColor = .init(channel(c.redComponent), channel(c.greenComponent), channel(c.blueComponent))
                    model.scheduleRear()
                }), supportsOpacity: false)
                .disabled(model.settings.rearEffect == .off || model.settings.rearEffect == .spectrum)
                HStack(spacing: 8) {
                    ForEach(LightingPreset.standardColors, id: \.name) { swatch in
                        Button {
                            model.settings.rearColor = swatch.color
                            model.scheduleRear()
                        } label: {
                            Circle().fill(Color(red: Double(swatch.color.red)/255, green: Double(swatch.color.green)/255, blue: Double(swatch.color.blue)/255))
                                .frame(width: 20, height: 20).overlay(Circle().stroke(.gray, lineWidth: 1))
                        }.buttonStyle(.plain).help(swatch.name).accessibilityLabel(swatch.name)
                    }
                }.disabled(model.settings.rearEffect == .off || model.settings.rearEffect == .spectrum)
                Slider(value: $model.settings.rearBrightness, in: 0...100, step: 1, onEditingChanged: { editing in
                    model.editing = editing
                    if !editing { model.applyRear() }
                }) { Text("Intensity · \(Int(model.settings.rearBrightness))%") }
                .disabled(model.settings.rearEffect == .off || model.settings.rearEffect == .spectrum)
                Text(model.syncing || model.calibrating ? "Screen Sync or calibration owns the rear LEDs. Stop it before changing Aura." : model.rearStatus)
                    .font(.caption).foregroundStyle(.secondary)
                Button("Apply rear Aura") { model.applyRear() }
            }.disabled(!model.controlsAvailable || model.syncing || model.calibrating)
        }.formStyle(.grouped)
    }
    private func lampEditing(_ editing: Bool) {
        model.editing = editing
        if !editing { model.applyLamp() }
    }

    private var screenSync: some View {
        Form {
            Section("Match the rear LEDs to your screen") {
                Text("The front desk light stays independent. Colors are sampled locally; screen images and audio are never saved or uploaded.").font(.callout)
                LabeledContent("Status", value: model.syncState)
                HStack {
                    Label(model.permissionGranted ? "Screen Recording available" : "Screen access not confirmed", systemImage: model.permissionGranted ? "checkmark.shield" : "lock")
                    Spacer()
                    Button("Request access") { model.requestCapturePermission() }.disabled(model.busy)
                    Button("Refresh") { model.refreshDisplays() }.disabled(model.busy)
                }
                Link("Open macOS Screen Recording settings", destination: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                if !model.permissionGranted {
                    Text("If access is already enabled in macOS, try Start Screen Sync. The actual capture result is authoritative.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Display and colors") {
                Picker("Display", selection: $model.settings.displayID) {
                    Text("Choose a display").tag(UInt32?.none)
                    ForEach(model.displays) { display in Text(model.displayName(display)).tag(UInt32?.some(display.id)) }
                }
                Picker("Color layout", selection: $model.settings.uniform) {
                    Text("\(model.ledCount ?? 0) horizontal zones").tag(false)
                    Text("Whole-screen average").tag(true)
                }.pickerStyle(.segmented)
                Toggle("Reverse LED order", isOn: $model.settings.reverse)
                Slider(value: $model.settings.intensity, in: 0...100, step: 1) { Text("Intensity · \(Int(model.settings.intensity))%") }
                Slider(value: $model.settings.smoothing, in: 0...0.9, step: 0.05) { Text("Smoothing · \(Int(model.settings.smoothing * 100))%") }
                Picker("Maximum capture rate", selection: $model.settings.fps) { Text("30 fps").tag(30); Text("60 fps").tag(60) }
                Text("Stop sync to change these settings. Higher smoothing makes changes gentler. A still screen may produce fewer frames than the maximum rate.")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(model.busy || model.syncing || model.calibrating)
            Section("Preview and calibration") {
                HStack(spacing: 4) {
                    ForEach(Array(model.preview.enumerated()), id: \.offset) { index, c in
                        RoundedRectangle(cornerRadius: 6).fill(Color(red: Double(c.red)/255, green: Double(c.green)/255, blue: Double(c.blue)/255))
                            .frame(height: 32).overlay(Text("\(index + 1)").foregroundStyle(.white).shadow(radius: 2))
                    }
                    if model.preview.isEmpty { Text("Sampled LED colors will appear here.").foregroundStyle(.secondary) }
                }
                Text("Frames accepted by USB: \(model.frames)").monospacedDigit()
                if let date = model.lastFrameAt { Text("Latest frame: \(date.formatted(date: .omitted, time: .standard))").font(.caption) }
                HStack {
                    Button(model.syncing ? "Stop Screen Sync" : "Start Screen Sync") { model.syncing ? model.stopSync() : model.startSync() }
                        .buttonStyle(.borderedProminent).disabled(!model.directAvailable)
                    Button(model.calibrating ? "End calibration" : "Test LED order") { model.calibrating ? model.stopSync() : model.calibrate() }
                        .disabled(!model.directAvailable || model.syncing)
                }
                Text("Test sends red → green → blue. End calibration, reverse the order if needed, and test again. On stop, restore the last Aura effect sent by this session; if unknown, turn rear LEDs off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading) {
            HStack { Text("Device and app activity").font(.headline); Spacer(); Button("Copy report") { model.copyDiagnostics() } }
            ScrollView { Text(model.diagnosticReport).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(12) }
            Text("Reports contain device status and local errors, but no screen images. Review before posting on GitHub.").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }
    private var help: some View {
        Form {
            Section("Quick start") {
                Text("Connect the bar using a USB data cable. The app reads its configuration first. Your first change verifies the current lamp setting with a no-change write/readback, then applies your request.")
                Text("Front controls illuminate the desk. Rear Aura colors the wall. They can run together. Screen Sync takes over the rear LEDs until stopped.")
            }
            Section("Troubleshooting") {
                Text("Disconnected: bypass the KVM or hub, reconnect the data cable, and click Reconnect. The app retries read-only discovery every 3 seconds. ASUS specifies 5 V / 1 A USB power.")
                Text("Screen Sync: click Request access, approve ALB01Control in macOS, and reopen if requested. Refresh the display list. Start reports Running only after the first complete frame is delivered. Protected content can appear black.")
                Text("A USB write accepted by macOS does not verify the visible rear color. Only the front lamp has verified readback. Hardware rear-effect readback and firmware update are not implemented.")
            }
            Section("Preferences and data") {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).disabled(model.busy)
                Text("Settings stay in this Mac’s UserDefaults. Activity is kept in memory; operational messages may also appear in macOS Console. No telemetry or screen recordings are stored.").font(.caption)
                Button("Erase saved app data…", role: .destructive) { confirmErase = true }.disabled(model.busy || model.syncing || model.calibrating)
            }
            Section("About · v\(model.version)") {
                Text("Copyright © 2026 Jonathan Hogue · MIT License")
                Text("Public beta. Screen Sync and sleep/KVM recovery still need full hardware validation. This build is not Apple-notarized.").font(.caption).foregroundStyle(.secondary)
                Button("Read MIT license…") { showLicense = true }
                Link("Source code, releases, and help", destination: URL(string: "https://github.com/hoguej77/ALB01Control-macOS")!)
                Text("Independent macOS software. Not made or endorsed by ASUS. Protocol implementation is original; research references are RIGStats and ALB01 Unlocker (MIT). OpenRGB was a protocol reference only.")
                Link("ASUS product and support", destination: URL(string: "https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/")!)
                Link("RIGStats reference", destination: URL(string: "https://github.com/dvalfrid/rigstats")!)
                Link("ALB01 Unlocker reference", destination: URL(string: "https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker")!)
                Button("Quit ALB01Control") { model.quit() }.disabled(model.busy)
            }
        }.formStyle(.grouped)
    }
}

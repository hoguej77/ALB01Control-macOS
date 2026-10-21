import SwiftUI
import AppKit
import ALB01Protocol

@main
struct ALB01ControlApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var model = ControlViewModel.shared
    var body: some Scene {
        Window("ALB01Control", id: "controls") {
            ControlPanel().environmentObject(model)
                .task { delegate.shutdown = { await model.prepareForQuit() }; model.start() }
        }
        .defaultSize(width: 1200, height: 920)
        .commands { StudioCommands(model: model) }
        .windowResizability(.contentMinSize)
        MenuBarExtra {
            MenuContents().environmentObject(model)
        } label: {
            LightBarMark(connected: model.connected, compact: true)
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
    @AppStorage("appearance.v1") private var appearance = "dark"
    private var tab: String { model.selectedPage }
    @State private var confirmErase = false
    @State private var showLicense = false

    private var pageTitle: String {
        switch tab { case "sync": return "Screen Sync"; case "diagnostics": return "Device diagnostics"; case "help": return "Settings & about"; default: return "Lighting studio" }
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(StudioTheme.line).frame(width: 1)
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("LIGHTING CONTROL").font(.system(size: 12, weight: .bold)).tracking(2).foregroundStyle(StudioTheme.muted)
                        Text(pageTitle).font(.system(size: 28, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    HStack(spacing: 7) {
                        Circle().fill(model.connected ? StudioTheme.mint : .orange).frame(width: 6, height: 6)
                        Text(model.connected ? "ALB01 connected" : "Disconnected").font(.system(size: 12, weight: .medium))
                    }.padding(.horizontal, 12).padding(.vertical, 8).background(StudioTheme.surface, in: Capsule())
                    Button { model.reconnect() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(StudioButtonStyle()).disabled(model.busy).help("Reconnect light bar").accessibilityLabel("Reconnect light bar")
                }.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 16) {
                        if let error = model.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        switch tab {
                        case "sync": screenSync
                        case "diagnostics": diagnostics
                        case "help": help
                        default: lights
                        }
                    }.padding(.horizontal, 26).padding(.bottom, 22)
                }
                HStack(spacing: 8) {
                    if model.busy { ProgressView().controlSize(.mini) }
                    Text(model.status).lineLimit(1).textSelection(.enabled)
                    Spacer(minLength: 8)
                    Text("v\(model.version) · PREVIEW").foregroundStyle(StudioTheme.muted)
                }.font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    .padding(.horizontal, 26).frame(height: 31).background(StudioTheme.sidebar)
            }
        }
        .background(StudioTheme.background)
        .foregroundStyle(StudioTheme.text)
        .tint(StudioTheme.cyan)
        .preferredColorScheme(appearance == "system" ? nil : (appearance == "light" ? .light : .dark))
        .font(.system(size: 13))
        .frame(minWidth: 820, minHeight: 650)
        .confirmationDialog("Erase saved preferences and activity?", isPresented: $confirmErase) {
            Button("Erase app data", role: .destructive) { model.eraseSettings() }
        } message: { Text("This clears local app settings and session activity. It sends no command to the lamp, and leaves macOS permissions and launch-at-login unchanged.") }
        .sheet(isPresented: $showLicense) {
            VStack(alignment: .leading, spacing: 16) {
                Text("MIT License").font(.title2.bold())
                ScrollView { Text(licenseText).textSelection(.enabled) }
                Button("Done") { showLicense = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 540, height: 440)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 13) {
                LightBarMark(connected: model.connected).frame(height: 28)
                Text("ALB01").font(.system(size: 25, weight: .bold, design: .rounded)).tracking(2)
                Text("CONTROL FOR macOS").font(.system(size: 12, weight: .semibold)).tracking(1.8).foregroundStyle(StudioTheme.muted)
            }.padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 32)
            nav("Lighting studio", icon: "slider.horizontal.3", id: "lights")
            nav("Screen Sync", icon: "display", id: "sync")
            nav("Diagnostics", icon: "waveform.path.ecg", id: "diagnostics")
            nav("Settings & about", icon: "gearshape", id: "help")
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Text("YOUR DEVICE").font(.system(size: 12, weight: .bold)).tracking(1.6).foregroundStyle(StudioTheme.muted)
                Text("ROG Aura Light Bar").font(.system(size: 12, weight: .semibold))
                Text(model.connected ? "\(model.ledCount ?? 0) rear LEDs · USB connected" : "Connect a USB data cable")
                    .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                Rectangle().fill(StudioTheme.line).frame(height: 1).padding(.vertical, 8)
                Text("Created by").font(.system(size: 12)).foregroundStyle(StudioTheme.muted)
                Text("Jonathan Hogue").font(.system(size: 12, weight: .semibold))
                Link("GitHub ↗", destination: URL(string: "https://github.com/hoguej77/ALB01Control-macOS")!)
                    .font(.system(size: 12)).foregroundStyle(StudioTheme.cyan)
            }.padding(22)
        }.frame(width: 210).background(StudioTheme.sidebar)
    }
    private func nav(_ title: String, icon: String, id: String) -> some View {
        Button { model.selectedPage = id } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 18)
                Text(title).font(.system(size: 12, weight: tab == id ? .semibold : .medium)).fixedSize(horizontal: true, vertical: false)
                Spacer()
                if tab == id { Capsule().fill(StudioTheme.cyan).frame(width: 3, height: 16) }
            }.foregroundStyle(tab == id ? StudioTheme.text : StudioTheme.secondary)
                .padding(.horizontal, 12).frame(height: 43)
                .background(tab == id ? StudioTheme.cyan.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(tab == id ? .isSelected : []).padding(.horizontal, 10).padding(.bottom, 5)
    }

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Copyright © 2026 Jonathan Hogue. MIT License. The full license is available in the source repository."
        }
        return text
    }

    private var lights: some View {
        VStack(spacing: 16) {
            LightBarHero(frontOn: model.frontOn, brightness: model.settings.brightness, kelvin: model.settings.kelvin,
                         connected: model.connected, ledCount: model.ledCount, effect: model.settings.rearEffect,
                         rearColor: model.settings.rearColor, syncing: model.syncing, rearKnown: model.rearStateKnown)
            ResponsiveColumns {
                deskCard
                auraCard
            }
            ControlCard("Scenes", subtitle: "Preview a scene’s settings before applying it to both lights.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(LightingPreset.builtIns) { preset in
                        Button { model.selectedPresetID = preset.id } label: {
                            PresetTile(preset: model.presetOverrides[preset.id] ?? preset, selected: model.selectedPresetID == preset.id)
                        }.buttonStyle(.plain).disabled(model.busy).help(preset.detail)
                    }
                }
                Text(model.presetSummary).font(.system(size: 12)).foregroundStyle(StudioTheme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("\(model.selectedPreset.name) · \(model.selectedPreset.frontOn ? "\(Int(model.selectedPreset.brightness))% desk light" : "Desk light off")")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    Spacer()
                    Button("Save current") { model.saveCurrentPreset() }.buttonStyle(StudioButtonStyle())
                        .disabled(model.busy || model.syncing || model.calibrating)
                        .help("Save current app settings to the selected scene without changing the lights")
                    Button("Reset") { model.resetSelectedPreset() }.buttonStyle(StudioButtonStyle()).disabled(model.busy)
                    Button("Apply scene") { model.applySelectedPreset() }.buttonStyle(StudioButtonStyle(prominent: true)).disabled(!model.controlsAvailable)
                }
            }
        }
    }

    private var deskCard: some View {
        ControlCard("Desk light", subtitle: "Front illumination", minimumHeight: 362) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(model.frontOn ? "\(Int(model.settings.brightness.rounded()))" : "OFF").font(.system(size: 38, weight: .regular, design: .rounded)).monospacedDigit()
                if model.frontOn { Text("%").font(.system(size: 15)).foregroundStyle(StudioTheme.secondary) }
                Spacer()
                Toggle("Desk light power", isOn: Binding(get: { model.frontOn }, set: { model.setPower($0) }))
                    .labelsHidden().toggleStyle(.switch).disabled(!model.controlsAvailable)
            }
            ControlSlider(title: "Brightness", value: "\(Int(model.settings.brightness.rounded()))%") {
                Slider(value: $model.settings.brightness, in: 1...100, onEditingChanged: lampEditing).accessibilityLabel("Desk brightness")
            }.disabled(!model.controlsAvailable || !model.frontOn)
            ControlSlider(title: "Color temperature", value: "\(Int(model.settings.kelvin.rounded())) K") {
                Slider(value: $model.settings.kelvin, in: 2700...6500, onEditingChanged: lampEditing).accessibilityLabel("Desk color temperature")
                    .background(LinearGradient(colors: [.orange.opacity(0.25), .white.opacity(0.1), .cyan.opacity(0.25)], startPoint: .leading, endPoint: .trailing).frame(height: 4), alignment: .center)
            }.disabled(!model.controlsAvailable || !model.frontOn)
            HStack {
                Text("WARM 2700 K").foregroundStyle(StudioTheme.secondary)
                Spacer()
                Text("COOL 6500 K").foregroundStyle(StudioTheme.cyan)
            }.font(.system(size: 12, weight: .semibold)).tracking(0.6)
            HStack(spacing: 16) {
                ExactLampValue(title: "Brightness", unit: "%", range: 1...100, value: $model.settings.brightness,
                               editing: { model.editing = $0 }, commit: { model.applyLamp() })
                ExactLampValue(title: "Temperature", unit: "K", range: 2700...6500, value: $model.settings.kelvin,
                               editing: { model.editing = $0 }, commit: { model.applyLamp() })
            }.disabled(!model.controlsAvailable || !model.frontOn)
            HStack(spacing: 5) {
                Circle().fill(model.measuredLamp == nil ? StudioTheme.muted : StudioTheme.mint).frame(width: 4, height: 4)
                Text(model.measuredLamp == nil ? "Awaiting readback" : "Device readback · \(model.lastReadText)").lineLimit(1)
                Spacer(minLength: 0)
                Button { model.refreshReadback() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(StudioButtonStyle()).accessibilityLabel("Refresh device readback").help("Refresh device readback").disabled(!model.controlsAvailable)
            }.font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
        }
    }

    private var auraCard: some View {
        ControlCard("Ambient light", subtitle: model.syncing ? "Following your Mac display" : "Rear illumination for your workspace", minimumHeight: 362) {
            HStack(spacing: 6) {
                effectButton("Off", .off)
                effectButton("Solid", .staticColor)
                effectButton("Breathe", .breathing)
                effectButton("Rainbow", .spectrum)
            }.padding(.vertical, 8)
            HStack {
                ColorPicker("Light color", selection: Binding(get: { rgb(model.settings.rearColor) }, set: { color in
                    guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                    func channel(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
                    model.settings.rearColor = .init(channel(c.redComponent), channel(c.greenComponent), channel(c.blueComponent))
                    model.scheduleRear()
                }), supportsOpacity: false).font(.system(size: 12))
                Spacer()
                Text(String(format: "#%02X%02X%02X", model.settings.rearColor.red, model.settings.rearColor.green, model.settings.rearColor.blue))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(StudioTheme.secondary)
            }.disabled(!colorAvailable)
            HStack(spacing: 3) {
                ForEach(LightingPreset.standardColors, id: \.name) { swatch in
                    Button { model.settings.rearColor = swatch.color; model.scheduleRear() } label: {
                        Circle().fill(rgb(swatch.color)).frame(width: 21, height: 21)
                            .overlay(Circle().stroke(StudioTheme.text.opacity(model.settings.rearColor == swatch.color ? 1 : 0.35), lineWidth: model.settings.rearColor == swatch.color ? 2 : 1).padding(-3))
                    }.buttonStyle(.plain).frame(minWidth: 28, minHeight: 28).help(swatch.name).accessibilityLabel(swatch.name)
                        .accessibilityValue(model.settings.rearColor == swatch.color ? "Selected" : "")
                }
            }.padding(.vertical, 7).disabled(!colorAvailable)
            Button("Match desk warmth") { model.matchAmbientToDesk() }
                .buttonStyle(StudioButtonStyle())
                .help("Set a soft 20% solid backlight that complements the desk light’s warmth")
            ControlSlider(title: "Intensity", value: "\(Int(model.settings.rearBrightness))%") {
                Slider(value: $model.settings.rearBrightness, in: 0...100, onEditingChanged: { editing in model.editing = editing; if !editing { model.applyRear() } }).accessibilityLabel("Rear intensity")
            }.disabled(!colorAvailable)
            HStack {
                Text(model.syncing || model.calibrating ? "Stop sync to change ambient lighting" : model.rearStatus).font(.system(size: 12)).foregroundStyle(StudioTheme.secondary).lineLimit(2)
                Spacer()
                Button("Apply") { model.applyRear() }.buttonStyle(StudioButtonStyle()).help("Apply ambient light settings")
            }
        }.disabled(!model.controlsAvailable || model.syncing || model.calibrating)
    }
    private var colorAvailable: Bool { model.settings.rearEffect == .staticColor || model.settings.rearEffect == .breathing }
    private func rgb(_ c: ALB01Protocol.RGB) -> Color { Color(red: Double(c.red)/255, green: Double(c.green)/255, blue: Double(c.blue)/255) }
    private func effectButton(_ label: String, _ effect: ALB01Protocol.AuraEffect) -> some View {
        Button { model.settings.rearEffect = effect; model.scheduleRear() } label: {
            Text(label).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).frame(height: 29)
                .foregroundStyle(model.settings.rearEffect == effect ? StudioTheme.cyan : StudioTheme.secondary)
                .background(model.settings.rearEffect == effect ? StudioTheme.cyan.opacity(0.12) : StudioTheme.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(model.settings.rearEffect == effect ? StudioTheme.cyan.opacity(0.5) : StudioTheme.line, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(model.settings.rearEffect == effect ? .isSelected : [])
    }
    private func lampEditing(_ editing: Bool) {
        model.editing = editing
        if !editing { model.applyLamp() }
    }

    private var screenSync: some View {
        VStack(spacing: 16) {
            ControlCard("Bring your screen into the room", subtitle: "Your front desk light stays independent.") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.syncState).font(.system(size: 23, weight: .regular, design: .rounded))
                        Text(model.syncing ? "Rear LEDs are following your selected display." : "Choose a display and color layout below.")
                            .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    }
                    Spacer()
                    Button(model.syncing || model.calibrating ? "Stop Screen Sync" : "Start Screen Sync") {
                        model.syncing || model.calibrating ? model.stopSync() : model.startSync()
                    }.buttonStyle(StudioButtonStyle(prominent: true)).disabled(!model.directAvailable)
                }.padding(.vertical, 5)
            }
            ResponsiveColumns {
                captureSetup
                ledOutput
            }
            ControlCard("Screen access", subtitle: "Processed on your Mac. No images or audio are saved or uploaded.") {
                HStack {
                    Label(model.permissionGranted ? "Screen Recording available" : "Screen access not confirmed",
                          systemImage: model.permissionGranted ? "checkmark.shield" : "lock")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    Spacer()
                    Button("Request access") { model.requestCapturePermission() }.buttonStyle(StudioButtonStyle()).disabled(model.busy)
                    Button("Refresh displays") { model.refreshDisplays() }.buttonStyle(StudioButtonStyle()).disabled(model.busy)
                }
                Link("Open macOS Screen Recording settings ↗", destination: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    .font(.system(size: 12))
                if !model.permissionGranted {
                    Text("If macOS already shows access enabled, try Start Screen Sync to check capture directly.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                }
            }
        }
    }

    private var captureSetup: some View {
        ControlCard("Capture setup", subtitle: "Stop sync to change these settings.", minimumHeight: 350) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Display").font(.system(size: 12))
                        Picker("Display", selection: $model.settings.displayID) {
                            Text("Choose a display").tag(UInt32?.none)
                            ForEach(model.displays) { display in Text(model.displayName(display)).tag(UInt32?.some(display.id)) }
                        }.labelsHidden()
                    }
                    Picker("Color layout", selection: $model.settings.uniform) {
                        Text("\(model.ledCount ?? 0) LED zones").tag(false)
                        Text("Uniform").tag(true)
                    }.pickerStyle(.segmented).controlSize(.small)
                    Toggle("Reverse LED order", isOn: $model.settings.reverse).font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                    ControlSlider(title: "Intensity", value: "\(Int(model.settings.intensity))%") {
                        Slider(value: $model.settings.intensity, in: 0...100).accessibilityLabel("Screen Sync intensity")
                    }
                    ControlSlider(title: "Smoothing", value: "\(Int(model.settings.smoothing * 100))%") {
                        Slider(value: $model.settings.smoothing, in: 0...0.9).accessibilityLabel("Screen Sync smoothing")
                    }
                    Picker("Capture rate", selection: $model.settings.fps) { Text("30 fps").tag(30); Text("60 fps").tag(60) }.controlSize(.small)
                    Text("More smoothing softens color changes. A still screen may deliver fewer frames.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                }.disabled(model.busy || model.syncing || model.calibrating)
    }

    private var ledOutput: some View {
        ControlCard("LED output", subtitle: "Sampled colors in physical LED order.", minimumHeight: 350) {
                    HStack(spacing: 6) {
                        if model.preview.isEmpty {
                            ForEach(0..<min(max(model.ledCount ?? 0, 1), 20), id: \.self) { index in
                                RoundedRectangle(cornerRadius: 7).fill(StudioTheme.background).frame(height: 68)
                                    .overlay(Text("\(index + 1)").font(.system(size: 12, design: .monospaced)).foregroundStyle(StudioTheme.muted))
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(StudioTheme.line, lineWidth: 1))
                            }
                        } else {
                            ForEach(Array(model.preview.enumerated()), id: \.offset) { index, c in
                                RoundedRectangle(cornerRadius: 7).fill(rgb(c)).frame(height: 68)
                                    .overlay(Text("\(index + 1)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white).shadow(color: .black, radius: 2))
                            }
                        }
                    }.padding(.vertical, 10)
                    HStack {
                        Text("USB frames").foregroundStyle(StudioTheme.secondary)
                        Spacer()
                        Text("\(model.frames)").monospacedDigit()
                    }.font(.system(size: 12))
                    if let date = model.lastFrameAt {
                        Text("Last frame \(date.formatted(date: .omitted, time: .standard))").font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    }
                    Divider().overlay(StudioTheme.line).padding(.vertical, 4)
                    Button(model.calibrating ? "End calibration" : "Test LED order") {
                        model.calibrating ? model.stopSync() : model.calibrate()
                    }.buttonStyle(StudioButtonStyle()).disabled(!model.directAvailable || model.syncing)
                    Text("Calibration sends red, green, then blue. Reverse the order if the bar’s left and right differ.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    Text("On stop: restore this session’s last ambient setting, or turn the rear off if it is unknown.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.muted)
                }
    }

    private var diagnostics: some View {
        ScrollView {
            ControlCard("Diagnostics", subtitle: "Reports contain device status and local errors, never screen images.") {
                HStack { Text("Device and app activity").font(.subheadline.weight(.medium)); Spacer(); Button("Copy report") { model.copyDiagnostics() }.buttonStyle(StudioButtonStyle()) }
                ScrollView { Text(model.diagnosticReport).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(12) }
                    .frame(minHeight: 290).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                Text("Review before posting a report on GitHub.").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 2)
        }
    }
    private var help: some View {
        ScrollView {
            VStack(spacing: 14) {
                ControlCard("Appearance", subtitle: "Choose how ALB01Control fits your workspace.") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }.pickerStyle(.segmented)
                    Text("Keyboard: ⌘1 Lighting · ⌘2 Screen Sync · ⌘3 Diagnostics · ⌘, Settings")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                }
                ControlCard("Siri & Shortcuts · Experimental", subtitle: "Five native actions; Apple-signed build required on this Mac.") {
                    Text("The local ad-hoc preview exposes actions in Shortcuts, but macOS rejects execution without an Apple Team ID. Voice control is not ready in this build.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    Text("Open Shortcuts, create a shortcut, then search for ALB01Control in the action library. Add a lighting action and save it with a short name.")
                    Text("Available actions: desk power, brightness, warmth, lighting scenes, and switch both lights off.")
                        .foregroundStyle(StudioTheme.secondary)
                    Text("Example: save a shortcut named Desk Light On with Set Desk Light Power → On. Then ask Siri to run Desk Light On.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                    Link("Open Shortcuts ↗", destination: URL(string: "shortcuts://")!)
                    Text("In a supported signed build, actions use the same hardware checks as the controls. Siri availability also depends on your Mac’s settings.")
                        .font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
                }
                ControlCard("Quick start", subtitle: "A deliberately safe hardware workflow.") {
                Text("Connect the bar using a USB data cable. The app reads its configuration first. Your first change verifies the current lamp setting with a no-change write/readback, then applies your request.")
                Text("Front controls illuminate the desk. Ambient light colors the wall. They can run together. Screen Sync takes over the rear LEDs until stopped.")
                }
                ControlCard("Troubleshooting") {
                Text("Disconnected: bypass the KVM or hub, reconnect the data cable, and click Reconnect. The app retries read-only discovery every 3 seconds. ASUS specifies 5 V / 1 A USB power.")
                Text("Screen Sync: click Request access, approve ALB01Control in macOS, and reopen if requested. Refresh the display list. Start reports Running only after the first complete frame is delivered. Protected content can appear black.")
                Text("A USB write accepted by macOS does not verify the visible rear color. Only the front lamp has verified readback. Hardware rear-effect readback and firmware update are not implemented.")
                }
                ControlCard("Preferences and data", subtitle: "All settings are stored locally on this Mac.") {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).disabled(model.busy)
                Text("Settings stay in this Mac’s UserDefaults. Activity is kept in memory; operational messages may also appear in macOS Console. No telemetry or screen recordings are stored.").font(.caption)
                Button("Erase saved app data…", role: .destructive) { confirmErase = true }.disabled(model.busy || model.syncing || model.calibrating)
                }
                ControlCard("About ALB01Control · v\(model.version)", subtitle: "Created and maintained by Jonathan Hogue") {
                Text("© 2026 Jonathan Hogue · Original app code licensed under MIT")
                    .font(.subheadline.weight(.semibold))
                Text("Public beta. Screen Sync and sleep/KVM recovery still need full hardware validation. This build is not Apple-notarized.").font(.caption).foregroundStyle(.secondary)
                Button("Read MIT license…") { showLicense = true }.buttonStyle(StudioButtonStyle())
                Link("Source code, releases, and help", destination: URL(string: "https://github.com/hoguej77/ALB01Control-macOS")!)
                Text("Independent macOS software. Not made or endorsed by ASUS. Protocol implementation is original; research references are RIGStats and ALB01 Unlocker (MIT). OpenRGB was a protocol reference only.")
                Link("ASUS product and support", destination: URL(string: "https://rog.asus.com/monitors/accessories/rog-aura-monitor-light-bar-alb01/")!)
                Link("RIGStats reference", destination: URL(string: "https://github.com/dvalfrid/rigstats")!)
                Link("ALB01 Unlocker reference", destination: URL(string: "https://github.com/UladzimirB-dev/Monitor-Lightbar-alb01-Unlocker")!)
                Button("Quit ALB01Control") { model.quit() }.disabled(model.busy)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

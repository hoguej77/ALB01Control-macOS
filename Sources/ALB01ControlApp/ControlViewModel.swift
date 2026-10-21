import SwiftUI
import AppKit
import ServiceManagement
import OSLog
import ALB01Protocol
import ALB01HID

struct SavedSettings: Codable {
    var brightness = 60.0
    var kelvin = 4600.0
    var rearEffect: ALB01Protocol.AuraEffect = .staticColor
    var rearColor = ALB01Protocol.RGB(64, 140, 255)
    var rearBrightness = 100.0
    mutating func validate() {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
        }
        brightness = clamp(brightness, 1...100, 60)
        kelvin = clamp(kelvin, 2700...6500, 4600)
        rearBrightness = clamp(rearBrightness, 0...100, 100)
    }
}

@MainActor
final class ControlViewModel: ObservableObject {
    static let shared = ControlViewModel()
    @Published var settings = SavedSettings()
    @Published var selectedPresetID = "reading"
    @Published var selectedPage = "lights"
    @Published private(set) var presetOverrides: [String: LightingPreset] = [:]
    @Published private(set) var status = "Connecting to your light bar…"
    @Published private(set) var errorMessage: String?
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var frontOn = false
    @Published private(set) var measuredLamp: ALB01Protocol.LampChannels?
    @Published private(set) var readAt: Date?
    @Published private(set) var ledCount: Int?
    @Published private(set) var diagnostics = "Waiting for device discovery."
    @Published private(set) var activity: [String] = []
    @Published private(set) var rearStatus = "Current hardware mode unknown. Choose an effect to take control."
    @Published private(set) var loginEnabled = SMAppService.mainApp.status == .enabled
    var editing = false

    private let hid = ALB01HIDDevice()
    private var authorized = false
    private var started = false
    private var monitorTask: Task<Void, Never>?
    private var rearDebounce: Task<Void, Never>?
    private var appliedRear: (ALB01Protocol.AuraEffect, ALB01Protocol.RGB)?
    private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: "local.alb01.control", category: "controller")
    private let settingsKey = "settings.v1"
    private let presetsKey = "presets.v1"
    private let defaults: UserDefaults
    private var suspended = false

    var version: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))"
    }
    var controlsAvailable: Bool { connected && !busy }
    var rearStateKnown: Bool { appliedRear != nil }
    var lastReadText: String {
        guard let lamp = measuredLamp, let readAt else { return "No readback yet" }
        let detail = lamp.isOff ? "Off" : "\(Int(lamp.estimatedBrightnessPercent.rounded()))% · \(Int(lamp.estimatedKelvin.rounded())) K"
        return "\(detail) · \(readAt.formatted(date: .omitted, time: .standard))"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(SavedSettings.self, from: data) {
            settings = saved
            settings.validate()
        }
        if let data = defaults.data(forKey: presetsKey),
           let saved = try? JSONDecoder().decode([String: LightingPreset].self, from: data) {
            for base in LightingPreset.builtIns {
                guard let stored = saved[base.id], stored.id == base.id else { continue }
                var preset = LightingPreset(id: base.id, name: base.name, detail: base.detail,
                    frontOn: stored.frontOn, brightness: stored.brightness, kelvin: stored.kelvin,
                    rearEffect: stored.rearEffect, rearColor: stored.rearColor, rearBrightness: stored.rearBrightness)
                preset.validate()
                presetOverrides[base.id] = preset
            }
        }
    }

    var selectedPreset: LightingPreset {
        let fallback = LightingPreset.builtIns.first(where: { $0.id == selectedPresetID }) ?? LightingPreset.builtIns[0]
        return presetOverrides[fallback.id] ?? fallback
    }
    var presetSummary: String {
        let p = selectedPreset
        let front = p.frontOn ? "\(Int(p.brightness.rounded()))% · \(Int(p.kelvin.rounded())) K" : "Off"
        let description = presetOverrides[p.id] == nil ? p.detail : "Saved custom scene."
        return "Desk: \(front) · Rear: \(p.rearEffect.rawValue). \(description)"
    }
    func saveCurrentPreset() {
        guard !busy else { return }
        var preset = selectedPreset
        preset.frontOn = frontOn
        preset.brightness = settings.brightness
        preset.kelvin = settings.kelvin
        preset.rearEffect = settings.rearEffect
        preset.rearColor = settings.rearColor
        preset.rearBrightness = settings.rearBrightness
        preset.validate()
        presetOverrides[preset.id] = preset
        savePresets()
        record("Saved current app settings to \(preset.name). No light-setting command sent.")
    }
    func resetSelectedPreset() {
        guard !busy else { return }
        presetOverrides[selectedPreset.id] = nil
        savePresets()
        record("Reset \(selectedPreset.name) to macOS starter values. Click Apply preset to change the lights.")
    }
    private func savePresets() {
        if let data = try? JSONEncoder().encode(presetOverrides) { defaults.set(data, forKey: presetsKey) }
    }
    func applySelectedPreset() {
        guard controlsAvailable else { return }
        let preset = selectedPreset
        rearDebounce?.cancel()
        run { try await self.applyScene(preset) }
    }

    private func applyScene(_ preset: LightingPreset) async throws {
        rearDebounce?.cancel()
        try await self.authorize()

        // Preserve the preset's on-level even when it requests front Off.
        self.settings.brightness = preset.brightness
        self.settings.kelvin = preset.kelvin
        let channels = ALB01Protocol.lampChannels(on: preset.frontOn, brightnessPercent: preset.brightness, kelvin: preset.kelvin)
        self.acceptReadback(try await self.hid.setLamp(channels))
        self.settings.rearEffect = preset.rearEffect
        self.settings.rearColor = preset.rearColor
        self.settings.rearBrightness = preset.rearBrightness
        self.save()
        let color = preset.rearColor.scaled(brightnessPercent: preset.rearBrightness)
        do {
            try await self.hid.setRearEffect(preset.rearEffect, color: color)
        } catch {
            self.rearStatus = "Preset only partly applied: front readback confirmed; rear command failed."
            throw error
        }
        self.appliedRear = (preset.rearEffect, color)
        self.rearStatus = "\(preset.name): rear command accepted by USB; visible output is not measured."
        self.record("\(preset.name) applied · front readback confirmed · rear command accepted")
    }

    func start() {
        guard !started else { return }
        started = true
        reconnect()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { return }
                guard !self.busy, !self.editing, !self.suspended else { continue }
                if self.connected {
                    // Read only the light bar's physical-button changes, not screen content.
                    self.run(quiet: true) { try await self.readLamp() }
                } else { self.reconnect() }
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.suspended = true

                self.connected = false; self.authorized = false
                await self.hid.invalidateConnection()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.suspended = false; self?.reconnect() }
        })
    }

    func run(quiet: Bool = false, _ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        if !quiet { errorMessage = nil }
        Task {
            defer { busy = false }
            do { try await operation() }
            catch {
                await self.handleOperationError(error)
            }
        }
    }

    private func handleOperationError(_ error: Error) async {
        if error is ALB01HIDError {
            connected = false; authorized = false
            await hid.invalidateConnection()

        }
        record(error.localizedDescription, error: true)
    }

    /// App Intents await this same controller and serialized report path as the UI.
    /// This method never creates a second HID owner or reports success before readback.
    func executeShortcut(_ action: LightingAutomationAction) async throws -> String {
        try action.validate()
        if !started { start() }
        for _ in 0..<60 {
            try Task.checkCancellation()
            if controlsAvailable { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard controlsAvailable else { throw LightingAutomationError.unavailable }
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try Task.checkCancellation()
            try await authorize()
            try Task.checkCancellation()
            let response: String
            switch action {
            case .scene(let id):
                guard let base = LightingPreset.builtIns.first(where: { $0.id == id }) else { throw LightingAutomationError.unknownScene }
                selectedPresetID = id
                try await applyScene(presetOverrides[id] ?? base)
                response = "\(selectedPreset.name) applied. Desk readback confirmed; backlight command sent."
            case .allOff:
                rearDebounce?.cancel()

                acceptReadback(try await hid.setLamp(.init(cool: 0, warm: 0)))
                try await hid.setRearEffect(.off, color: .init(0, 0, 0))
                settings.rearEffect = .off
                appliedRear = (.off, .init(0, 0, 0))
                rearStatus = "Backlight off command sent."
                save()
                response = "Desk light off, confirmed by readback. Backlight off command sent."
            case .power(let on):
                let value = ALB01Protocol.lampChannels(on: on, brightnessPercent: settings.brightness, kelvin: settings.kelvin)
                acceptReadback(try await hid.setLamp(value))
                response = on ? "Desk light on, confirmed by readback." : "Desk light off, confirmed by readback."
            case .brightness(let percent):
                let value = ALB01Protocol.lampChannels(on: true, brightnessPercent: Double(percent), kelvin: settings.kelvin)
                acceptReadback(try await hid.setLamp(value))
                response = "Desk brightness is \(Int(settings.brightness.rounded())) percent, confirmed by readback."
            case .temperature(let kelvin):
                let value = ALB01Protocol.lampChannels(on: true, brightnessPercent: settings.brightness, kelvin: Double(kelvin))
                acceptReadback(try await hid.setLamp(value))
                response = "Desk temperature is \(Int(settings.kelvin.rounded())) Kelvin, confirmed by readback."
            }
            record(response)
            return response
        } catch {
            await handleOperationError(error)
            throw error
        }
    }

    func matchAmbientToDesk() {
        guard controlsAvailable else { return }
        settings.rearEffect = .staticColor
        settings.rearColor = AmbientPalette.matchingDesk(kelvin: settings.kelvin)
        settings.rearBrightness = 20
        applyRear()
    }

    func reconnect() {
        run {

            let probe = try await self.hid.readOnlyProbe()
            self.connected = true; self.authorized = false
            self.ledCount = probe.ledCount
            self.acceptReadback(probe.lampChannels)
            self.diagnostics = "ALB01Control \(self.version)\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nDevice: \(probe.collection.productName)\nVID:PID 0B05:1AC8 · Usage FF72/00A1\nReport bytes: \(probe.collection.inputReportSize)/\(probe.collection.outputReportSize)\nLED count: \(probe.ledCount)\nConfig: \(ALB01Protocol.hex(probe.configReply))"
            self.record("Connected · \(probe.ledCount) rear LEDs · front readback verified")
        }
    }

    private func authorize() async throws {
        guard connected else { throw ALB01HIDError.deviceNotFound }
        if !authorized {
            _ = try await hid.verifyCurrentLampWriteBack()
            authorized = true
        }
    }

    func acceptReadback(_ value: ALB01Protocol.LampChannels) {
        let changed = value != measuredLamp
        measuredLamp = value; readAt = Date(); frontOn = !value.isOff
        // Off has no useful temperature: preserve the last lit settings.
        if changed && !value.isOff {
            settings.brightness = value.estimatedBrightnessPercent
            settings.kelvin = value.estimatedKelvin
            save()
        }
    }

    private func readLamp() async throws { acceptReadback(try await hid.readLampState()) }
    func refreshReadback() { run { try await self.readLamp(); self.record("Front-lamp state refreshed") } }

    func setPower(_ on: Bool) {
        guard controlsAvailable else { return }
        applyLamp(on: on)
    }
    func applyLamp(on: Bool? = nil) {
        let desired = ALB01Protocol.lampChannels(on: on ?? frontOn, brightnessPercent: settings.brightness, kelvin: settings.kelvin)
        save()
        run {
            try await self.authorize()
            let result = try await self.hid.setLamp(desired)
            self.acceptReadback(result)
            self.record(result.isOff ? "Desk light off · confirmed by readback" : "Desk light updated · confirmed by readback")
        }
    }

    func scheduleRear() {
        save()
        rearDebounce?.cancel()
        rearDebounce = Task {
            try? await Task.sleep(for: .milliseconds(200))
            while self.busy && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            guard !Task.isCancelled else { return }
            self.applyRear()
        }
    }
    func applyRear() {
        let desired = (settings.rearEffect, settings.rearColor.scaled(brightnessPercent: settings.rearBrightness))
        save()
        run {
            try await self.authorize()
            try await self.hid.setRearEffect(desired.0, color: desired.1)
            self.appliedRear = desired
            self.rearStatus = "\(desired.0.rawValue) command accepted by USB. Rear readback is not verified."
            self.record("Rear Aura command sent")
        }
    }

    func save() {
        settings.validate()
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }
    func eraseSettings() {
        guard !busy else { return }
        // A pending color-picker debounce must not apply erased settings later.
        rearDebounce?.cancel()
        rearDebounce = nil
        defaults.removeObject(forKey: settingsKey)
        defaults.removeObject(forKey: presetsKey)
        defaults.removeObject(forKey: "appearance.v1")
        presetOverrides = [:]
        selectedPresetID = "reading"
        // Remove the limited keys written by earlier prototype versions too.
        ["frontBrightness", "frontTemperature", "rearBrightness", "syncIntensity", "syncSmoothing", "syncFPS", "reverseLEDOrder", "uniformScreenSync"].forEach { defaults.removeObject(forKey: $0) }
        settings = SavedSettings(); activity = []
        record("Saved preferences and activity cleared. No light-setting command sent.")
    }
    func setLogin(_ enabled: Bool) {
        run {
            if enabled { try SMAppService.mainApp.register() }
            else { try await SMAppService.mainApp.unregister() }
            self.loginEnabled = SMAppService.mainApp.status == .enabled
            self.record(self.loginEnabled ? "Launch at login enabled" : "Launch at login disabled or awaiting approval in System Settings")
        }
    }
    func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticReport, forType: .string)
    }
    var diagnosticReport: String {
        "\(diagnostics)\nFront readback: \(lastReadText)\n\n\(activity.joined(separator: "\n"))"
    }
    func prepareForQuit() async {
        monitorTask?.cancel(); rearDebounce?.cancel()
        while busy { try? await Task.sleep(for: .milliseconds(50)) }
        busy = true
    }
    func quit() { NSApp.terminate(nil) }
    private func record(_ message: String, error: Bool = false) {
        status = message
        if error { errorMessage = message }
        logger.info("\(message, privacy: .public)")
        if !activity.first.orEmpty.hasSuffix(message) {
            activity.insert("\(Date().formatted(date: .omitted, time: .standard))  \(message)", at: 0)
            activity = Array(activity.prefix(60))
        }
    }
    private func messageError(_ message: String) -> NSError { NSError(domain: "ALB01Control", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }

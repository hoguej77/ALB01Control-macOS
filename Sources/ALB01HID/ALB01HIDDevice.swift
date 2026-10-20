@preconcurrency import Foundation
@preconcurrency import IOKit.hid
import ALB01Protocol
import IOKit

public struct ALB01HIDCollection: Equatable, Sendable {
    public let vendorID: Int
    public let productID: Int
    public let usagePage: Int
    public let usage: Int
    public let inputReportSize: Int
    public let outputReportSize: Int
    public let featureReportSize: Int
    public let locationID: Int
    public let productName: String

    public var isAuraCollection: Bool {
        vendorID == ALB01Protocol.vendorID && productID == ALB01Protocol.productID &&
            usagePage == ALB01Protocol.usagePage && usage == ALB01Protocol.usage
    }
}

public struct ALB01ProbeResult: Equatable, Sendable {
    public let collection: ALB01HIDCollection
    public let configReply: [UInt8]
    public let ledCount: Int
    public let lampChannels: ALB01Protocol.LampChannels

    public var supportsDirectFrames: Bool { (1...ALB01Protocol.maxDirectLEDs).contains(ledCount) }
}

public enum ALB01HIDError: LocalizedError, Equatable, Sendable {
    case deviceNotFound
    case unexpectedReportSizes(input: Int, output: Int)
    case iokit(operation: String, code: Int32, message: String)
    case timedOut(String)
    case writeNotAuthorized
    case connectionChanged
    case ambiguousDevices
    case readBackMismatch(expected: ALB01Protocol.LampChannels, actual: ALB01Protocol.LampChannels)

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "No ALB01 Aura HID collection (0B05:1AC8, FF72/00A1) is connected."
        case .unexpectedReportSizes(let input, let output):
            return "ALB01 report sizes are input \(input), output \(output); expected 65/65."
        case .iokit(let operation, let code, let message):
            return "\(operation) failed: IOReturn \(code) (\(message))."
        case .timedOut(let reply):
            return "Timed out waiting for \(reply)."
        case .writeNotAuthorized:
            return "Writes are locked until this connection passes the read-only config and lamp probes."
        case .connectionChanged:
            return "The USB connection changed. Reconnect and verify the light bar before changing settings."
        case .ambiguousDevices:
            return "More than one ALB01 is attached. Connect only the light bar you want to control."
        case .readBackMismatch(let expected, let actual):
            return "Lamp readback \(actual.cool)/\(actual.warm) did not match \(expected.cool)/\(expected.warm)."
        }
    }
}

private final class ReportCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [[UInt8]] = []

    func append(_ report: [UInt8]) {
        lock.lock()
        reports.append(report)
        lock.unlock()
    }

    func take(where predicate: ([UInt8]) -> Bool) -> [UInt8]? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = reports.firstIndex(where: predicate) else { return nil }
        return reports.remove(at: index)
    }
}

private func alB01InputCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ type: IOHIDReportType,
    _ reportID: UInt32,
    _ report: UnsafeMutablePointer<UInt8>,
    _ length: CFIndex
) {
    guard result == kIOReturnSuccess, let context, length > 0 else { return }
    let collector = Unmanaged<ReportCollector>.fromOpaque(context).takeUnretainedValue()
    collector.append(Array(UnsafeBufferPointer(start: report, count: Int(length))))
}

/// A persistent output-only HID session used by Screen Sync. Keeping this
/// handle open avoids manager/device open-close churn on every 30/60-fps frame.
public final class ALB01DirectFrameWriter: @unchecked Sendable {
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let lock = NSLock()
    private var closed = false
    private let ledCount: Int

    fileprivate init(manager: IOHIDManager, device: IOHIDDevice, ledCount: Int) {
        self.manager = manager
        self.device = device
        self.ledCount = ledCount
    }

    deinit { close() }

    public func sendFrame(_ colors: [ALB01Protocol.RGB]) throws {
        guard colors.count == ledCount else { throw ALB01Protocol.ProtocolError.invalidLEDCount(colors.count) }
        try send(try ALB01Protocol.directFrame(colors))
    }

    public func close() {
        lock.withLock {
            guard !closed else { return }
            closed = true
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    fileprivate func activateDirectMode() throws {
        try send(ALB01Protocol.directModeInitialization())
    }

    private func send(_ report: [UInt8]) throws {
        try ALB01Protocol.validateReport(report)
        try lock.withLock {
            guard !closed else { throw ALB01HIDError.deviceNotFound }
            let result = report.withUnsafeBufferPointer {
                IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(ALB01Protocol.reportID), $0.baseAddress!, $0.count)
            }
            guard result == kIOReturnSuccess else { throw makeIOKitError("IOHIDDeviceSetReport", result) }
        }
    }
}

private func makeIOKitError(_ operation: String, _ result: IOReturn) -> ALB01HIDError {
    let message = mach_error_string(result).map { String(cString: $0) } ?? "unknown IOKit error"
    return .iokit(operation: operation, code: result, message: message)
}

/// Serializes all IOKit work away from SwiftUI. It deliberately opens the HID
/// collection without seize options and re-enumerates every transaction, so a
/// sleep/wake or KVM reconnect becomes a clean "not connected" state rather
/// than a stale handle or a blind retry.
public actor ALB01HIDDevice {
    private var readAuthorized = false
    private var writeAuthorized = false
    private var verifiedEntryID: UInt64?
    private var verifiedLEDCount = 0

    public func invalidateConnection() {
        readAuthorized = false
        writeAuthorized = false
        verifiedEntryID = nil
        verifiedLEDCount = 0
    }

    public init() {}

    public func discover() throws -> [ALB01HIDCollection] {
        let manager = makeManager()
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else { throw iokitError("IOHIDManagerOpen", openResult) }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.map(describe).sorted { $0.locationID < $1.locationID }
    }

    /// Sends only EC B0, EC 31 01, and EC B1 01. Successful completion is the
    /// one prerequisite for all state-changing APIs in this type.
    public func readOnlyProbe(timeout: TimeInterval = 1.0) throws -> ALB01ProbeResult {
        invalidateConnection()
        let result: ALB01ProbeResult = try withOpenDevice { device, collection, collector in
            try send(device, ALB01Protocol.configRequest())
            let config = try waitFor(collector, matching: { report in
                report.count == ALB01Protocol.reportLength && report[0] == 0xEC && report[1] == 0x30
            }, named: "EC30 config reply", timeout: timeout)
            let ledCount = try ALB01Protocol.parseLEDCount(from: config)

            try send(device, ALB01Protocol.lampGetRequest())
            try send(device, ALB01Protocol.lampReadRequest())
            let lampReply = try waitFor(collector, matching: { report in
                report.count == ALB01Protocol.reportLength && report[0] == 0xEC && report[1] == 0x31 && report[2] == 0x01
            }, named: "EC3101 lamp reply", timeout: timeout)
            verifiedEntryID = try entryID(device)
            verifiedLEDCount = ledCount
            return ALB01ProbeResult(
                collection: collection,
                configReply: config,
                ledCount: ledCount,
                lampChannels: try ALB01Protocol.parseLampReply(lampReply)
            )
        }
        guard result.ledCount > 0 else { throw ALB01Protocol.ProtocolError.invalidLEDCount(result.ledCount) }
        readAuthorized = true
        return result
    }

    /// Reads only the front-lamp state without changing the authorization
    /// gates. This powers the UI's manual live-readback refresh.
    public func readLampState(timeout: TimeInterval = 1.0) throws -> ALB01Protocol.LampChannels {
        try withOpenDevice { device, _, collector in
            try readLamp(device, collector: collector, timeout: timeout)
        }
    }

    /// The intentionally first write: read the physical lamp, set the exact
    /// same cool/warm channels, then confirm the same reply. It has no visible
    /// change when the firmware accepts the documented packet.
    public func verifyCurrentLampWriteBack(timeout: TimeInterval = 1.0) throws -> ALB01Protocol.LampChannels {
        guard readAuthorized else { throw ALB01HIDError.writeNotAuthorized }
        let readBack = try withOpenDevice { device, _, collector in
            let current = try readLamp(device, collector: collector, timeout: timeout)
            try send(device, ALB01Protocol.lampSet(current))
            let readBack = try readLamp(device, collector: collector, timeout: timeout)
            guard readBack == current else { throw ALB01HIDError.readBackMismatch(expected: current, actual: readBack) }
            return readBack
        }
        writeAuthorized = true
        return readBack
    }

    public func setLamp(_ channels: ALB01Protocol.LampChannels, timeout: TimeInterval = 1.0) throws -> ALB01Protocol.LampChannels {
        try requireWriteAuthorization()
        return try withOpenDevice { device, _, collector in
            try send(device, ALB01Protocol.lampSet(channels))
            let readBack = try readLamp(device, collector: collector, timeout: timeout)
            guard readBack == channels else { throw ALB01HIDError.readBackMismatch(expected: channels, actual: readBack) }
            return readBack
        }
    }

    public func setRearEffect(_ effect: ALB01Protocol.AuraEffect, color: ALB01Protocol.RGB) throws {
        try requireWriteAuthorization()
        try withOpenDevice { device, _, _ in try send(device, ALB01Protocol.rearEffect(effect, color: color)) }
    }

    /// Enters direct mode once. Call `sendDirectFrame` for each latest screen frame.
    public func enterDirectMode() throws {
        try requireWriteAuthorization()
        try withOpenDevice { device, _, _ in try send(device, ALB01Protocol.directModeInitialization()) }
    }

    public func sendDirectFrame(_ colors: [ALB01Protocol.RGB]) throws {
        try requireWriteAuthorization()
        let report = try ALB01Protocol.directFrame(colors)
        try withOpenDevice { device, _, _ in try send(device, report) }
    }

    /// Opens one persistent output session, enters direct mode once, and hands
    /// it to Screen Sync for low-latency latest-frame-wins delivery.
    public func beginDirectFrameSession() throws -> ALB01DirectFrameWriter {
        try requireWriteAuthorization()
        var completed = false
        defer { if !completed { invalidateConnection() } }
        let manager = makeManager()
        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else { throw iokitError("IOHIDManagerOpen", managerResult) }
        let device: IOHIDDevice
        do {
            device = try uniqueDevice(manager)
            try validateIdentity(device)
        } catch {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw error
        }
        let collection = describe(device)
        guard collection.isAuraCollection,
              collection.inputReportSize == ALB01Protocol.reportLength,
              collection.outputReportSize == ALB01Protocol.reportLength else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw ALB01HIDError.unexpectedReportSizes(input: collection.inputReportSize, output: collection.outputReportSize)
        }
        let deviceResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard deviceResult == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw iokitError("IOHIDDeviceOpen", deviceResult)
        }
        let writer = ALB01DirectFrameWriter(manager: manager, device: device, ledCount: verifiedLEDCount)
        do {
            try writer.activateDirectMode()
            completed = true
            return writer
        } catch {
            writer.close()
            throw error
        }
    }

    private func requireWriteAuthorization() throws {
        guard writeAuthorized else { throw ALB01HIDError.writeNotAuthorized }
    }

    private func makeManager() -> IOHIDManager {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey as String: ALB01Protocol.vendorID,
            kIOHIDProductIDKey as String: ALB01Protocol.productID,
            kIOHIDPrimaryUsagePageKey as String: ALB01Protocol.usagePage,
            kIOHIDPrimaryUsageKey as String: ALB01Protocol.usage,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        return manager
    }

    private func describe(_ device: IOHIDDevice) -> ALB01HIDCollection {
        ALB01HIDCollection(
            vendorID: number(device, kIOHIDVendorIDKey),
            productID: number(device, kIOHIDProductIDKey),
            usagePage: number(device, kIOHIDPrimaryUsagePageKey),
            usage: number(device, kIOHIDPrimaryUsageKey),
            inputReportSize: number(device, kIOHIDMaxInputReportSizeKey),
            outputReportSize: number(device, kIOHIDMaxOutputReportSizeKey),
            featureReportSize: number(device, kIOHIDMaxFeatureReportSizeKey),
            locationID: number(device, kIOHIDLocationIDKey),
            productName: (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "ALB01"
        )
    }

    private func number(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }

    private func withOpenDevice<Result>(_ operation: (IOHIDDevice, ALB01HIDCollection, ReportCollector) throws -> Result) throws -> Result {
        var completed = false
        defer { if !completed { invalidateConnection() } }
        let manager = makeManager()
        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else { throw iokitError("IOHIDManagerOpen", managerResult) }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        let device = try uniqueDevice(manager)
        try validateIdentity(device)
        let collection = describe(device)
        guard collection.isAuraCollection else { throw ALB01HIDError.deviceNotFound }
        guard collection.inputReportSize == ALB01Protocol.reportLength,
              collection.outputReportSize == ALB01Protocol.reportLength else {
            throw ALB01HIDError.unexpectedReportSizes(input: collection.inputReportSize, output: collection.outputReportSize)
        }

        let collector = ReportCollector()
        var inputBuffer = [UInt8](repeating: 0, count: ALB01Protocol.reportLength)
        let result = try inputBuffer.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer.baseAddress!,
                buffer.count,
                alB01InputCallback,
                Unmanaged.passUnretained(collector).toOpaque()
            )
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            defer {
                IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            }
            let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard openResult == kIOReturnSuccess else { throw iokitError("IOHIDDeviceOpen", openResult) }
            defer {
                IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            return try operation(device, collection, collector)
        }
        completed = true
        return result
    }

    private func uniqueDevice(_ manager: IOHIDManager) throws -> IOHIDDevice {
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        guard devices.count <= 1 else { throw ALB01HIDError.ambiguousDevices }
        guard let device = devices.first else { throw ALB01HIDError.deviceNotFound }
        return device
    }

    private func entryID(_ device: IOHIDDevice) throws -> UInt64 {
        var id: UInt64 = 0
        let result = IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
        guard result == kIOReturnSuccess else { throw iokitError("USB connection identity", result) }
        return id
    }

    private func validateIdentity(_ device: IOHIDDevice) throws {
        if let verifiedEntryID, try entryID(device) != verifiedEntryID {
            throw ALB01HIDError.connectionChanged
        }
    }

    private func readLamp(_ device: IOHIDDevice, collector: ReportCollector, timeout: TimeInterval) throws -> ALB01Protocol.LampChannels {
        try send(device, ALB01Protocol.lampGetRequest())
        try send(device, ALB01Protocol.lampReadRequest())
        let reply = try waitFor(collector, matching: { report in
            report.count == ALB01Protocol.reportLength && report[0] == 0xEC && report[1] == 0x31 && report[2] == 0x01
        }, named: "EC3101 lamp reply", timeout: timeout)
        return try ALB01Protocol.parseLampReply(reply)
    }

    private func send(_ device: IOHIDDevice, _ report: [UInt8]) throws {
        try ALB01Protocol.validateReport(report)
        let result = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(ALB01Protocol.reportID), $0.baseAddress!, $0.count)
        }
        guard result == kIOReturnSuccess else { throw iokitError("IOHIDDeviceSetReport", result) }
    }

    private func waitFor(_ collector: ReportCollector, matching predicate: ([UInt8]) -> Bool, named reply: String, timeout: TimeInterval) throws -> [UInt8] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let report = collector.take(where: predicate) { return report }
            CFRunLoopRunInMode(.defaultMode, 0.02, true)
        }
        throw ALB01HIDError.timedOut(reply)
    }

    private func iokitError(_ operation: String, _ result: IOReturn) -> ALB01HIDError {
        makeIOKitError(operation, result)
    }
}

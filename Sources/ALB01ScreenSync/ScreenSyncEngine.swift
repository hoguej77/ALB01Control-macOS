@preconcurrency import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import CoreVideo
import ALB01Protocol
import ALB01HID

public struct CaptureDisplay: Identifiable, Equatable, Sendable {
    public let id: CGDirectDisplayID
    public let width: Int
    public let height: Int
}

public struct ScreenSyncSettings: Equatable, Sendable {
    public var ledCount: Int
    public var reverseLEDOrder: Bool
    public var intensityPercent: Double
    public var smoothing: Double
    public var fps: Int
    public var uniform: Bool
    public init(ledCount: Int, reverseLEDOrder: Bool = false, intensityPercent: Double = 100,
                smoothing: Double = 0.20, fps: Int = 30, uniform: Bool = false) {
        self.ledCount = ledCount; self.reverseLEDOrder = reverseLEDOrder
        self.intensityPercent = intensityPercent; self.smoothing = smoothing
        self.fps = fps; self.uniform = uniform
    }
}

public struct ScreenSyncProgress: Sendable {
    public let frames: Int
    public let colors: [ALB01Protocol.RGB]
}

public enum ScreenSyncError: LocalizedError, Sendable {
    case noDisplay(CGDirectDisplayID), unsupportedLEDCount(Int), permissionRequired, noFrames
    public var errorDescription: String? {
        switch self {
        case .noDisplay: return "The selected display is unavailable. Refresh the display list."
        case .unsupportedLEDCount(let n): return "Screen Sync supports 1–20 LEDs; this device reported \(n)."
        case .permissionRequired: return "Allow Screen Recording for ALB01Control, then quit and reopen it if macOS asks."
        case .noFrames: return "Capture started but no complete frame reached the light bar within 4 seconds. Check Screen Recording access and the selected display."
        }
    }
}

/// Main-actor lifecycle; capture/sampling and USB delivery have separate queues.
/// A fresh worker/mailbox per session isolates late callbacks from a prior run.
@MainActor
public final class ScreenSyncEngine {
    private let hid: ALB01HIDDevice
    private var stream: SCStream?
    private var worker: CaptureWorker?
    private var generation = UUID()
    public var onFailure: ((String) -> Void)?
    public var onProgress: ((ScreenSyncProgress) -> Void)?
    public init(hid: ALB01HIDDevice) { self.hid = hid }

    /// Enumerate display geometry without requesting access to screen pixels.
    public static func displays() throws -> [CaptureDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { throw ScreenSyncError.noDisplay(0) }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { throw ScreenSyncError.noDisplay(0) }
        return ids.prefix(Int(count)).map {
            CaptureDisplay(id: $0, width: CGDisplayPixelsWide($0), height: CGDisplayPixelsHigh($0))
        }
    }

    public func start(displayID: CGDirectDisplayID, settings: ScreenSyncSettings) async throws {
        guard (1...20).contains(settings.ledCount) else { throw ScreenSyncError.unsupportedLEDCount(settings.ledCount) }
        // Preflight is advisory: a development rebuild can disagree with the
        // enabled System Settings entry. ScreenCaptureKit enforces authorization.
        await stop()
        let token = UUID()
        generation = token
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard generation == token else { throw CancellationError() }
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw ScreenSyncError.noDisplay(displayID) }
        let config = SCStreamConfiguration()
        config.width = 320
        config.height = max(1, Int((320.0 * Double(display.height) / Double(max(1, display.width))).rounded()))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.minimumFrameInterval = CMTime(value: 1, timescale: settings.fps == 60 ? 60 : 30)
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false
        let writer = try await hid.beginDirectFrameSession()
        guard generation == token else { writer.close(); throw CancellationError() }
        let worker = CaptureWorker(writer: writer, settings: settings,
            progress: { [weak self] value in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.onProgress?(value)
                }
            }, failure: { [weak self] message in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.onFailure?(message)
                }
            })
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: worker)
        self.worker = worker
        self.stream = stream
        do {
            try stream.addStreamOutput(worker, type: .screen, sampleHandlerQueue: worker.sampleQueue)
            try await stream.startCapture()
            // Do not report "Running" until at least one frame was sent.
            for _ in 0..<40 {
                guard generation == token else { throw CancellationError() }
                if worker.deliveredFrames > 0 { return }
                if let failure = worker.failureMessage { throw NSError(domain: "ScreenSync", code: 1, userInfo: [NSLocalizedDescriptionKey: failure]) }
                try await Task.sleep(for: .milliseconds(100))
            }
            throw ScreenSyncError.noFrames
        } catch {
            if generation == token { await stop() }
            throw error
        }
    }

    public func stop() async {
        generation = UUID()
        let oldStream = stream
        let oldWorker = worker
        stream = nil; worker = nil
        // Drain/close the USB session before another Aura mode can be restored.
        await oldWorker?.close()
        if let oldStream { try? await oldStream.stopCapture() }
    }
}

private final class CaptureWorker: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let sampleQueue = DispatchQueue(label: "local.alb01.sample", qos: .userInitiated)
    private let outputQueue = DispatchQueue(label: "local.alb01.usb-frames", qos: .userInitiated)
    private let writer: ALB01DirectFrameWriter
    private let settings: ScreenSyncSettings
    private let mailbox = LatestFrameMailbox<[ALB01Protocol.RGB]>()
    private let lock = NSLock()
    private var closed = false
    private var frameCount = 0
    private var failure: String?
    private var lastUpdate = ContinuousClock.now
    private var previous: [ALB01Protocol.RGB] = [] // only touched on sampleQueue
    private let progress: @Sendable (ScreenSyncProgress) -> Void
    private let failed: @Sendable (String) -> Void
    var deliveredFrames: Int { lock.withLock { frameCount } }
    var failureMessage: String? { lock.withLock { failure } }

    init(writer: ALB01DirectFrameWriter, settings: ScreenSyncSettings,
         progress: @escaping @Sendable (ScreenSyncProgress) -> Void,
         failure: @escaping @Sendable (String) -> Void) {
        self.writer = writer; self.settings = settings; self.progress = progress; self.failed = failure
    }

    func close() async {
        lock.withLock { closed = true }
        mailbox.close()
        await withCheckedContinuation { continuation in
            outputQueue.async { self.writer.close(); continuation.resume() }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { fail(error.localizedDescription) }

    private func fail(_ message: String) {
        let report = lock.withLock {
            guard !closed, failure == nil else { return false }
            failure = message
            return true
        }
        if report { mailbox.close(); failed(message) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, !lock.withLock({ closed }), CMSampleBufferIsValid(buffer),
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let pixels = CMSampleBufferGetImageBuffer(buffer),
              CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(pixels, .readOnly) == kCVReturnSuccess else { return }
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixels) else { return }
        let rowBytes = CVPixelBufferGetBytesPerRow(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        let bytes = UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: rowBytes * height)
        guard let colors = ScreenColors.sample(bytes, width: CVPixelBufferGetWidth(pixels), height: height,
                                               rowBytes: rowBytes, ledCount: settings.ledCount, uniform: settings.uniform) else { return }
        previous = ScreenColors.blend(colors, previous: previous, retention: settings.smoothing, intensity: 100, reverse: false)
        let frame = ScreenColors.blend(previous, previous: [], retention: 0, intensity: settings.intensityPercent, reverse: settings.reverseLEDOrder)
        guard mailbox.offer(frame) else { return }
        outputQueue.async { [self] in
            while let next = mailbox.take() {
                guard !lock.withLock({ closed }) else { return }
                do {
                    try writer.sendFrame(next)
                    let update: Int? = lock.withLock {
                        frameCount += 1
                        if frameCount == 1 || lastUpdate.duration(to: .now) >= .milliseconds(250) {
                            lastUpdate = .now
                            return frameCount
                        }
                        return nil
                    }
                    if let update { progress(.init(frames: update, colors: next)) }
                } catch { fail(error.localizedDescription); return }
            }
        }
    }
}

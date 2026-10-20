import Foundation

/// Pure BGRA sampler. Validates stride and byte count before reading pixels.
public enum ScreenColors {
    public static func sample(_ bytes: UnsafeBufferPointer<UInt8>, width: Int, height: Int,
                              rowBytes: Int, ledCount: Int, uniform: Bool) -> [ALB01Protocol.RGB]? {
        guard width > 0, height > 0, (1...20).contains(ledCount), width >= ledCount,
              width <= Int.max / 4, rowBytes >= width * 4,
              height <= Int.max / rowBytes, bytes.count >= rowBytes * height else { return nil }
        let zones = uniform ? 1 : ledCount
        var result: [ALB01Protocol.RGB] = []
        for zone in 0..<zones {
            let left = zone * width / zones
            let right = (zone + 1) * width / zones
            var r = 0, g = 0, b = 0, count = 0
            for y in stride(from: 0, to: height, by: 3) {
                for x in stride(from: left, to: right, by: 3) {
                    let offset = y * rowBytes + x * 4
                    b += Int(bytes[offset]); g += Int(bytes[offset + 1]); r += Int(bytes[offset + 2])
                    count += 1
                }
            }
            guard count > 0 else { return nil }
            result.append(.init(UInt8(r / count), UInt8(g / count), UInt8(b / count)))
        }
        return uniform ? Array(repeating: result[0], count: ledCount) : result
    }

    public static func blend(_ current: [ALB01Protocol.RGB], previous: [ALB01Protocol.RGB],
                             retention: Double, intensity: Double, reverse: Bool) -> [ALB01Protocol.RGB] {
        let retain = retention.isFinite ? min(max(retention, 0), 0.95) : 0
        let prior = previous.count == current.count ? previous : current
        let colors = zip(prior, current).map { old, new in
            ALB01Protocol.RGB(
                UInt8((Double(old.red) * retain + Double(new.red) * (1 - retain)).rounded()),
                UInt8((Double(old.green) * retain + Double(new.green) * (1 - retain)).rounded()),
                UInt8((Double(old.blue) * retain + Double(new.blue) * (1 - retain)).rounded())
            ).scaled(brightnessPercent: intensity)
        }
        return reverse ? Array(colors.reversed()) : colors
    }
}

/// A one-slot handoff. A producer replaces pending work; one consumer drains it.
/// Closing rejects future frames. Each capture session owns its own mailbox.
public final class LatestFrameMailbox<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Element?
    private var draining = false
    private var closed = false
    public init() {}

    public func offer(_ value: Element) -> Bool {
        lock.withLock {
            guard !closed else { return false }
            pending = value
            guard !draining else { return false }
            draining = true
            return true
        }
    }

    public func take() -> Element? {
        lock.withLock {
            guard !closed, let value = pending else { draining = false; return nil }
            pending = nil
            return value
        }
    }

    public func close() {
        lock.withLock { closed = true; pending = nil }
    }
}

import Foundation
import ALB01Protocol
import ALB01HID

@main
struct ALB01Diagnostics {
    static func main() async {
        let arguments = Set(CommandLine.arguments.dropFirst())
        let runProbe = !arguments.contains("--discover-only")
        let verifyWriteBack = arguments.contains("--verify-writeback")
        let lampOffOnTest = arguments.contains("--lamp-off-on-test")
        let lampMappingTest = arguments.contains("--lamp-mapping-test")
        let rearAcceptanceSequence = arguments.contains("--rear-acceptance-sequence")
        let directFrameTest = arguments.contains("--direct-frame-test")

        if arguments.contains("--help") {
            print("Usage: alb01-diagnostics [--discover-only] [--verify-writeback] [--lamp-off-on-test] [--lamp-mapping-test] [--rear-acceptance-sequence] [--direct-frame-test]")
            print("Default: enumerate and run read-only EC B0 / EC 31 / EC B1 probes.")
            print("--verify-writeback: after a successful read-only probe, write the exact current lamp channels and verify readback.")
            print("--lamp-off-on-test: requires --verify-writeback; tests an Off command/readback, then restores the exact original lamp channels.")
            print("--lamp-mapping-test: requires --verify-writeback; tests 50%/4600 K (44/45) and restores the exact original lamp channels.")
            print("--rear-acceptance-sequence: requires --verify-writeback; sends static, breathing, spectrum, then off to the rear Aura LEDs.")
            print("--direct-frame-test: requires --verify-writeback; enters direct mode, sends one per-LED calibration frame, then restores rear off.")
            return
        }

        let device = ALB01HIDDevice()
        do {
            let collections = try await device.discover()
            guard !collections.isEmpty else {
                print("ALB01 Aura collection not found.")
                exit(2)
            }
            for collection in collections {
                print("\(collection.productName)")
                print(String(format: "  VID:PID             %04X:%04X", collection.vendorID, collection.productID))
                print(String(format: "  usage page / usage  %04X / %04X", collection.usagePage, collection.usage))
                print("  report sizes        input \(collection.inputReportSize), output \(collection.outputReportSize), feature \(collection.featureReportSize)")
                print(String(format: "  location ID         0x%08X", collection.locationID))
            }
            guard runProbe else { return }

            print("\nRunning documented read-only probes …")
            let probe = try await device.readOnlyProbe()
            print("  config reply:       \(ALB01Protocol.hex(probe.configReply))")
            print("  LED count:          \(probe.ledCount)\(probe.supportsDirectFrames ? "" : " (screen sync refused: >20)")")
            print("  lamp cool / warm:   \(probe.lampChannels.cool) / \(probe.lampChannels.warm)")
            print(String(format: "  lamp estimate:      %.0f K at %.0f%%", probe.lampChannels.estimatedKelvin, probe.lampChannels.estimatedBrightnessPercent))
            print("  read-only status:   passed")

            if verifyWriteBack {
                print("\nWriting identical lamp channels and verifying readback …")
                let readBack = try await device.verifyCurrentLampWriteBack()
                print("  no-change write:    passed (\(readBack.cool)/\(readBack.warm))")
            }

            if lampOffOnTest {
                guard verifyWriteBack else {
                    throw NSError(domain: "ALB01", code: 5, userInfo: [NSLocalizedDescriptionKey: "--lamp-off-on-test requires --verify-writeback in the same run."])
                }
                let original = probe.lampChannels
                print("\nTesting front-lamp Off command and restoring \(original.cool)/\(original.warm) …")
                do {
                    let off = try await device.setLamp(.init(cool: 0, warm: 0))
                    guard off.isOff else {
                        throw NSError(domain: "ALB01", code: 6, userInfo: [NSLocalizedDescriptionKey: "Off command read back as \(off.cool)/\(off.warm), not 0/0."])
                    }
                    let restored = try await device.setLamp(original)
                    guard restored == original else {
                        throw NSError(domain: "ALB01", code: 7, userInfo: [NSLocalizedDescriptionKey: "Restore read back as \(restored.cool)/\(restored.warm), expected \(original.cool)/\(original.warm)."])
                    }
                    print("  off readback:       0/0")
                    print("  restore readback:   \(restored.cool)/\(restored.warm)")
                } catch {
                    _ = try? await device.setLamp(original)
                    throw error
                }
            }

            if lampMappingTest {
                guard verifyWriteBack else {
                    throw NSError(domain: "ALB01", code: 8, userInfo: [NSLocalizedDescriptionKey: "--lamp-mapping-test requires --verify-writeback in the same run."])
                }
                let original = probe.lampChannels
                let expected = ALB01Protocol.lampChannels(on: true, brightnessPercent: 50, kelvin: 4600)
                print("\nTesting 50% / 4600 K front-lamp command and restoring \(original.cool)/\(original.warm) …")
                do {
                    let readBack = try await device.setLamp(expected)
                    guard readBack == expected else {
                        throw NSError(domain: "ALB01", code: 9, userInfo: [NSLocalizedDescriptionKey: "Mapping read back as \(readBack.cool)/\(readBack.warm), expected \(expected.cool)/\(expected.warm)."])
                    }
                    let restored = try await device.setLamp(original)
                    guard restored == original else {
                        throw NSError(domain: "ALB01", code: 10, userInfo: [NSLocalizedDescriptionKey: "Restore read back as \(restored.cool)/\(restored.warm), expected \(original.cool)/\(original.warm)."])
                    }
                    print("  mapping readback:   \(readBack.cool)/\(readBack.warm)")
                    print("  restore readback:   \(restored.cool)/\(restored.warm)")
                } catch {
                    _ = try? await device.setLamp(original)
                    throw error
                }
            }

            if rearAcceptanceSequence {
                guard verifyWriteBack else {
                    throw NSError(domain: "ALB01", code: 3, userInfo: [NSLocalizedDescriptionKey: "--rear-acceptance-sequence requires --verify-writeback in the same run."])
                }
                print("\nTesting documented rear Aura packets …")
                try await device.setRearEffect(.staticColor, color: .init(0xFF, 0x00, 0x33))
                try await Task.sleep(for: .milliseconds(250))
                try await device.setRearEffect(.breathing, color: .init(0x00, 0xAA, 0xFF))
                try await Task.sleep(for: .milliseconds(250))
                try await device.setRearEffect(.spectrum, color: .init(0, 0, 0))
                try await Task.sleep(for: .milliseconds(250))
                try await device.setRearEffect(.off, color: .init(0, 0, 0))
                print("  static/breathing/spectrum/off reports accepted; rear Aura LEDs left off.")
            }

            if directFrameTest {
                guard verifyWriteBack else {
                    throw NSError(domain: "ALB01", code: 4, userInfo: [NSLocalizedDescriptionKey: "--direct-frame-test requires --verify-writeback in the same run."])
                }
                let calibration = [ALB01Protocol.RGB(255, 0, 0), .init(0, 255, 0), .init(0, 0, 255), .init(255, 255, 255)]
                let frame = (0..<probe.ledCount).map { calibration[$0 % calibration.count] }
                print("\nTesting direct-mode initialization and \(frame.count)-LED frame …")
                let writer = try await device.beginDirectFrameSession()
                do {
                    try writer.sendFrame(frame)
                    writer.close()
                    try await device.setRearEffect(.off, color: .init(0, 0, 0))
                } catch {
                    writer.close()
                    throw error
                }
                print("  EC35 direct init + EC40 frame accepted; rear Aura LEDs restored off.")
            }
            exit(0)
        } catch {
            fputs("ALB01 diagnostics failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

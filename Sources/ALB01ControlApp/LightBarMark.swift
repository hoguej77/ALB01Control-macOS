import SwiftUI

/// A compact, native vector mark that reads as a monitor light bar rather than a bulb.
/// It intentionally uses no vendor artwork or external asset.
struct LightBarMark: View {
    let connected: Bool
    var compact = false

    private var width: CGFloat { compact ? 22 : 62 }
    private var height: CGFloat { compact ? 14 : 30 }
    private var glowColor: Color { connected ? .cyan : .secondary }

    var body: some View {
        ZStack {
            Capsule()
                .fill(.linearGradient(
                    colors: [Color.black.opacity(0.92), Color.gray.opacity(0.82), Color.black.opacity(0.92)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: compact ? 0.5 : 1))

            Capsule()
                .fill(glowColor.gradient)
                .opacity(connected ? 0.94 : 0.38)
                .frame(height: compact ? 2.2 : 5)
                .padding(.horizontal, compact ? 4 : 10)
                .blur(radius: compact ? 0.4 : 1)
                .offset(y: compact ? -0.5 : -1)

            HStack {
                Circle().fill(.white.opacity(0.68)).frame(width: compact ? 1.5 : 3, height: compact ? 1.5 : 3)
                Spacer()
                Circle().fill(.white.opacity(0.68)).frame(width: compact ? 1.5 : 3, height: compact ? 1.5 : 3)
            }
            .padding(.horizontal, compact ? 3 : 8)

            RoundedRectangle(cornerRadius: compact ? 1 : 2)
                .fill(Color.primary.opacity(0.42))
                .frame(width: compact ? 7 : 19, height: compact ? 1.5 : 3)
                .offset(y: compact ? 6 : 13)
        }
        .frame(width: width, height: height)
        .accessibilityLabel(connected ? "Monitor light bar connected" : "Monitor light bar disconnected")
    }
}

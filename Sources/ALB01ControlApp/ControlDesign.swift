import SwiftUI
import AppKit
import ALB01Protocol

enum StudioTheme {
    // Original interface tokens inspired by the ALB01's black hardware and ROG's
    // restrained red energy. They are not copied ASUS design assets or typefaces.
    static let background = adaptive(light: 0xF4F3F1, dark: 0x08090C)
    static let sidebar = adaptive(light: 0xE8E6E4, dark: 0x0D0E12)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x15171D)
    static let raised = adaptive(light: 0xF0EEEC, dark: 0x1B1E25)
    static let line = adaptive(light: 0xC7C0BD, dark: 0x30343D)
    static let text = adaptive(light: 0x151313, dark: 0xF5F1EE)
    static let secondary = adaptive(light: 0x5E5652, dark: 0xB7B0AD)
    static let muted = adaptive(light: 0x756D68, dark: 0x8E8988)
    static let rogRed = adaptive(light: 0xB4001E, dark: 0xFF1744)
    static let ember = adaptive(light: 0xD63A1F, dark: 0xFF5D3D)
    static let coolWhite = adaptive(light: 0x005C84, dark: 0x7EDBFF)
    /// Compatibility name for controls that use the primary accent. New views
    /// should use `rogRed` so the intent is explicit.
    static let cyan = rogRed
    static let mint = adaptive(light: 0x176E4C, dark: 0x5CDBA8)
    static let accentFill = rogRed
    static let onAccent = Color.white

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func label(_ size: CGFloat = 11, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let highContrast = appearance.bestMatch(from: [.accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua, .aqua, .darkAqua])
            let darkMode = highContrast == .darkAqua || highContrast == .accessibilityHighContrastDarkAqua
            let value = darkMode ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

/// A quiet technical chamfer gives the app a hardware-inspired hierarchy without
/// imitating ASUS UI artwork or relying on a gaming font.
struct ROGPanelShape: Shape {
    var cut: CGFloat = 8
    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) / 2)
        return Path { path in
            path.move(to: CGPoint(x: c, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
            path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
            path.addLine(to: CGPoint(x: c, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
            path.closeSubpath()
        }
    }
}

struct StudioButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(StudioTheme.label(12, weight: .semibold))
            .padding(.horizontal, 12).frame(height: 34)
            .foregroundStyle(prominent ? StudioTheme.onAccent : StudioTheme.text)
            .background(prominent ? StudioTheme.accentFill : StudioTheme.raised, in: ROGPanelShape(cut: 5))
            .overlay(ROGPanelShape(cut: 5).stroke(prominent ? StudioTheme.rogRed.opacity(0.55) : StudioTheme.line, lineWidth: 1))
            .overlay(ROGPanelShape(cut: 7).stroke(focused ? StudioTheme.rogRed : .clear, lineWidth: 2).padding(-3))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct ControlCard<Content: View>: View {
    let title: String
    let subtitle: String?
    var minimumHeight: CGFloat?
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder let content: () -> Content
    init(_ title: String, subtitle: String? = nil, minimumHeight: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.minimumHeight = minimumHeight; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(StudioTheme.display(16, weight: .semibold))
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(StudioTheme.secondary) }
            }
            content()
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(StudioTheme.surface, in: ROGPanelShape(cut: 10))
        .overlay(ROGPanelShape(cut: 10).stroke(StudioTheme.line, lineWidth: contrast == .increased ? 2 : 0.7))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(StudioTheme.rogRed).frame(width: 28, height: 2).padding(.leading, 18)
        }
    }
}

struct ControlSlider<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let control: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(StudioTheme.rogRed)
            }
            control().controlSize(.regular)
        }
    }
}

/// Choose columns from the available width, preserving control identity on resize.
/// Measuring ideal child widths (ViewThatFits) lets long status labels force a
/// single column even when two usable columns fit.
struct ResponsiveColumns<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let layout = availableWidth >= 740
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
        layout { content() }
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, width in availableWidth = width }
                }
            }
    }
}

struct PresetTile: View {
    let preset: LightingPreset
    let selected: Bool
    private var icon: String {
        switch preset.id {
        case "reading": "book.closed"
        case "game": "sun.max"
        case "night": "moon.stars"
        case "theater": "film"
        case "music": "sun.haze"
        default: "slider.horizontal.3"
        }
    }
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 18, weight: .regular))
            Text(preset.name.replacingOccurrences(of: "User Mode ", with: "User ")).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
        }
        .foregroundStyle(selected ? StudioTheme.text : StudioTheme.secondary)
        .frame(maxWidth: .infinity).frame(height: 80)
        .background(selected ? StudioTheme.rogRed.opacity(0.12) : StudioTheme.raised, in: ROGPanelShape(cut: 6))
        .overlay(ROGPanelShape(cut: 6).stroke(selected ? StudioTheme.rogRed : StudioTheme.line, lineWidth: 1))
        .contentShape(ROGPanelShape(cut: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.name) scene")
        .accessibilityValue(selected ? "Selected for preview; choose Apply scene to activate" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

import SwiftUI
import AppKit
import ALB01Protocol

enum StudioTheme {
    static let background = adaptive(light: 0xF2F4F7, dark: 0x0E1116)
    static let sidebar = adaptive(light: 0xE8EDF2, dark: 0x131720)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x191F29)
    static let line = adaptive(light: 0xB5BFCC, dark: 0x4B586B)
    static let text = Color(nsColor: .labelColor)
    static let secondary = adaptive(light: 0x48556A, dark: 0xB2BDCE)
    static let muted = adaptive(light: 0x546177, dark: 0x9EACC1)
    static let cyan = adaptive(light: 0x006B7C, dark: 0x4AD9EB)
    static let mint = adaptive(light: 0x176E4C, dark: 0x5CDBA8)
    static let accentFill = adaptive(light: 0x006B7C, dark: 0x4AD9EB)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x0E1116)

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

struct StudioButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12).frame(height: 34)
            .foregroundStyle(prominent ? StudioTheme.onAccent : StudioTheme.text)
            .background(prominent ? StudioTheme.accentFill : StudioTheme.background, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(prominent ? .clear : StudioTheme.line, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(focused ? StudioTheme.cyan : .clear, lineWidth: 2).padding(-3))
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
                Text(title).font(.system(size: 16, weight: .semibold))
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(StudioTheme.secondary) }
            }
            content()
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudioTheme.line, lineWidth: contrast == .increased ? 2 : 0.7))
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
                Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(StudioTheme.cyan)
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
        .foregroundStyle(selected ? StudioTheme.cyan : StudioTheme.secondary)
        .frame(maxWidth: .infinity).frame(height: 80)
        .background(selected ? StudioTheme.cyan.opacity(0.08) : StudioTheme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? StudioTheme.cyan.opacity(0.7) : StudioTheme.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.name) scene")
        .accessibilityValue(selected ? "Selected for preview; choose Apply scene to activate" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

import SwiftUI
import ALB01Protocol

/// A schematic preview of requested lighting; optical output is not measured.
struct LightBarHero: View {
    let frontOn: Bool
    let brightness: Double
    let kelvin: Double
    let connected: Bool
    let ledCount: Int?
    let effect: ALB01Protocol.AuraEffect
    let rearColor: ALB01Protocol.RGB
    let rearKnown: Bool
    private var aura: Color { Color(red: Double(rearColor.red)/255, green: Double(rearColor.green)/255, blue: Double(rearColor.blue)/255) }
    private var warmth: Color { kelvin < 4000 ? .orange : Color(red: 0.75, green: 0.88, blue: 1) }
    private var effectName: String {
        if !connected || !rearKnown { return "Unconfirmed" }
        switch effect { case .off: return "Off"; case .staticColor: return "Static"; case .breathing: return "Breathing"; case .spectrum: return "Spectrum" }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ROG AURA MONITOR LIGHT BAR").font(StudioTheme.label(10, weight: .bold)).tracking(1.7).foregroundStyle(StudioTheme.rogRed)
                Text("Asymmetrical desk light").font(StudioTheme.display(21, weight: .semibold))
                Text("ALB01  /  USB HID  /  LOCAL CONTROL").font(.system(size: 10, design: .monospaced)).foregroundStyle(StudioTheme.secondary)
                HStack(spacing: 8) {
                    metric("DESK", !connected ? "—" : frontOn ? "\(Int(brightness))%" : "Off")
                    metric("AMBIENT", effectName)
                    metric("LEDS", ledCount.map(String.init) ?? "—")
                }.padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { geometry in
                let w = min(geometry.size.width - 30, 300)
                ZStack {
                    if connected && rearKnown && effect != .off {
                        Ellipse().fill((effect == .spectrum ? StudioTheme.rogRed : aura).opacity(0.32)).frame(width: w + 12, height: 90).offset(y: -4)
                    }
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.025, green: 0.027, blue: 0.035))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LinearGradient(colors: [.white.opacity(0.19), .white.opacity(0.025)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                        .frame(width: w, height: 104).offset(y: 12)
                    if frontOn {
                        LightCone().fill(LinearGradient(colors: [warmth.opacity(0.2), warmth.opacity(0.015)], startPoint: .top, endPoint: .bottom))
                            .frame(width: w - 22, height: 88).offset(y: 18)
                    }
                    VStack(spacing: 0) {
                        Capsule().fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.07), Color(white: 0.18)], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().stroke(.white.opacity(0.26), lineWidth: 0.7)).frame(width: w + 10, height: 13)
                            .overlay(alignment: .bottom) { Capsule().fill(frontOn ? warmth : .white.opacity(0.1)).frame(width: w - 16, height: 2).shadow(color: frontOn ? warmth.opacity(0.9) : .clear, radius: 5) }
                        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.22)).frame(width: 28, height: 6)
                    }.offset(y: -39)
                    Capsule().fill(Color(white: 0.16)).frame(width: 56, height: 3).offset(y: 69)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(width: 255, height: 145).accessibilityHidden(true)
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
        .background(LinearGradient(colors: [StudioTheme.surface, StudioTheme.background], startPoint: .leading, endPoint: .trailing), in: ROGPanelShape(cut: 12))
        .overlay(ROGPanelShape(cut: 12).stroke(StudioTheme.line, lineWidth: 1))
        .overlay(alignment: .topLeading) { Rectangle().fill(StudioTheme.rogRed).frame(width: 42, height: 2).padding(.leading, 22) }
        .overlay(alignment: .topTrailing) { Text("LIVE LIGHT MAP").font(StudioTheme.label(10, weight: .bold)).tracking(1).foregroundStyle(StudioTheme.muted).padding(12) }
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(StudioTheme.muted)
            Text(value).font(.system(size: 11, weight: .medium))
        }.padding(.trailing, 16)
    }
}
private struct LightCone: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.width * 0.12, y: 0)); p.addLine(to: CGPoint(x: rect.width * 0.88, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: rect.height)); p.addLine(to: CGPoint(x: 0, y: rect.height)); p.closeSubpath()
        }
    }
}

import SwiftUI
import AppKit

struct StudioCommands: Commands {
    @ObservedObject var model: ControlViewModel
    @Environment(\.openWindow) private var openWindow

    private func show(_ page: String) {
        model.selectedPage = page
        openWindow(id: "controls")
        NSApp.activate(ignoringOtherApps: true)
    }
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About ALB01Control") { show("help") }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { show("help") }.keyboardShortcut(",")
        }
        CommandMenu("Navigate") {
            Button("Lighting Studio") { show("lights") }.keyboardShortcut("1")
            Button("Screen Sync") { show("sync") }.keyboardShortcut("2")
            Button("Diagnostics") { show("diagnostics") }.keyboardShortcut("3")
            Button("Settings & About") { show("help") }.keyboardShortcut("4")
            Divider()
            Button("Refresh Device Readback") { model.refreshReadback() }
                .keyboardShortcut("r").disabled(!model.controlsAvailable)
        }
    }
}

import SwiftUI

enum LampValueInput {
    static func isUnchanged(_ text: String, current: Double) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == String(Int(current.rounded()))
    }
    static func parse(_ text: String, range: ClosedRange<Int>) -> Double? {
        guard let number = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              range.contains(number) else { return nil }
        return Double(number)
    }
}

struct ExactLampValue: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var value: Double
    let editing: (Bool) -> Void
    let commit: () -> Void
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer(minLength: 4)
                TextField(title, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 68)
                    .focused($focused)
                    .accessibilityLabel("\(title) exact value")
                    .accessibilityHint("Whole number from \(range.lowerBound) to \(range.upperBound). Press Return to apply.")
                    .onSubmit { focused = false }
                Text(unit).font(.system(size: 12)).foregroundStyle(StudioTheme.secondary)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(.orange)
            }
        }
        .onAppear { draft = String(Int(value.rounded())) }
        .onChange(of: value) { _, number in
            if !focused { draft = String(Int(number.rounded())) }
        }
        .onChange(of: focused) { _, hasFocus in
            editing(hasFocus)
            guard !hasFocus else { return }
            // Merely focusing a rounded hardware value must never send a write.
            if LampValueInput.isUnchanged(draft, current: value) { error = nil; return }
            guard let number = LampValueInput.parse(draft, range: range) else {
                error = "Enter \(range.lowerBound)–\(range.upperBound)."
                return
            }
            error = nil
            if number != value { value = number; commit() }
        }
        .onDisappear { if focused { editing(false) } }
    }
}

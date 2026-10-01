import SwiftUI

extension View {
    /// Presents a save failure while `message` is non-nil, clearing it on dismiss.
    func saveErrorAlert(_ message: Binding<String?>) -> some View {
        alert("未能保存", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

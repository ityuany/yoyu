import SwiftUI
import SwiftData

extension ModelContext {
    /// Saves pending changes, rolling back on failure.
    /// - Returns: `nil` on success, otherwise a message to show the user.
    func saveOrRollback() -> String? {
        do {
            try save()
            return nil
        } catch {
            rollback()
            return error.localizedDescription
        }
    }
}

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

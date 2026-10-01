import SwiftUI
import SwiftData
import UIKit

struct YearMonthWheel: UIViewRepresentable {
    @Binding var selection: Date
    var maximumDate: Date? = nil

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .yearAndMonth
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = ProfileRules.calendar
        picker.locale = Locale(identifier: "zh_CN")
        picker.minimumDate = ProfileRules.calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))
        picker.maximumDate = maximumDate ?? ProfileRules.calendar.date(from: DateComponents(year: 2100, month: 12, day: 1))
        picker.date = selection
        picker.addTarget(context.coordinator, action: #selector(Coordinator.monthChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        let calendar = ProfileRules.calendar
        let shown = calendar.dateComponents([.year, .month], from: picker.date)
        let selected = calendar.dateComponents([.year, .month], from: selection)
        if shown.year != selected.year || shown.month != selected.month {
            picker.setDate(selection, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) { self.selection = selection }

        @objc func monthChanged(_ picker: UIDatePicker) {
            let calendar = ProfileRules.calendar
            let components = calendar.dateComponents([.year, .month], from: picker.date)
            if let month = calendar.date(from: components) { selection.wrappedValue = month }
        }
    }
}

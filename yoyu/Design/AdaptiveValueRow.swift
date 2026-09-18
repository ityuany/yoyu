import SwiftUI

/// A label/value pair stays on one baseline when it fits, then stacks without shrinking text.
struct AdaptiveValueRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title).fixedSize()
                Spacer(minLength: 0)
                Text(value).foregroundStyle(valueColor).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                Text(value).foregroundStyle(valueColor).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

import SwiftUI

struct MortgageCertificateCard: View {
    let account: LiabilityAccount
    let date: Date
    let open: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @ScaledMetric(relativeTo: .subheadline) private var detailFontSize = 14.0

    private var ink: Color { dark ? Color(red: 0.91, green: 0.89, blue: 0.85) : Color(red: 0.20, green: 0.19, blue: 0.18) }
    private var accent: Color { dark ? Color(red: 0.67, green: 0.40, blue: 0.41) : Color(red: 0.43, green: 0.22, blue: 0.24) }
    private var paper: Color { dark ? Color(red: 0.14, green: 0.14, blue: 0.14) : Color(red: 0.97, green: 0.96, blue: 0.94) }
    private var dark: Bool { colorScheme == .dark }
    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 7, bottomTrailingRadius: 32, topTrailingRadius: 32)
    }
    private var snapshot: LiabilitySnapshot? { account.snapshot }
    private var nextPayment: String {
        guard let snapshot, LiabilityRules.error(snapshot, kind: .mortgage) == nil else { return "待核对" }
        let payments = LiabilityRules.payments(snapshot, kind: .mortgage, on: date)
        guard let next = payments.first else { return "已结清" }
        return ProfileRules.money(LiabilityRules.sum(payments.filter { $0.date == next.date }.map(\.total)))
    }

    private var estimatedInterest: String {
        guard let snapshot, LiabilityRules.error(snapshot, kind: .mortgage) == nil else { return "待核对" }
        let payments = LiabilityRules.payments(snapshot, kind: .mortgage, on: date)
        return ProfileRules.money(LiabilityRules.sum(payments.map(\.interest)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "house")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accent)
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.horizontal, 27)
            .padding(.bottom, 16)

            Rectangle().fill(ink.opacity(0.10)).frame(height: 0.5)
                .padding(.leading, 27)
                .padding(.trailing, 24)

            VStack(alignment: .leading, spacing: 16) {
                Text(snapshot.flatMap { LiabilityRules.balance($0, kind: .mortgage, on: date) }.map { ProfileRules.money($0) } ?? "待核对")
                    .font(.title.weight(.regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("剩余本金")
                    .accessibilityValue(snapshot.flatMap { LiabilityRules.balance($0, kind: .mortgage, on: date) }.map { ProfileRules.money($0) } ?? "待核对")
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(snapshot?.mortgages ?? []) { part in
                        GridRow {
                            Text(part.name == "公积金贷款" ? "公积金剩余" : "商业贷剩余")
                            Text(ProfileRules.money(part.principal)).monospacedDigit().foregroundStyle(ink.opacity(0.88))
                        }
                        .foregroundStyle(ink.opacity(0.58))
                        .accessibilityElement(children: .combine)
                    }
                    GridRow {
                        Text("预计总利息")
                        Text(estimatedInterest).monospacedDigit().foregroundStyle(ink.opacity(0.88))
                    }
                    .foregroundStyle(ink.opacity(0.58))
                    .accessibilityElement(children: .combine)
                    GridRow {
                        Text("下期预计还款")
                        Text(nextPayment).monospacedDigit().foregroundStyle(ink.opacity(0.88))
                    }
                    .foregroundStyle(ink.opacity(0.58))
                    .accessibilityElement(children: .combine)
                }
                .font(.system(size: detailFontSize))
                Button(action: open) {
                    Text("打开档案")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(accent.opacity(dark ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("查看\(account.name)的贷款详情")
            }
            .padding(.vertical, 20)
            .padding(.leading, 27)
            .padding(.trailing, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .foregroundStyle(ink)
        .background(paper)
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(ink.opacity(dark ? 0.10 : 0.07), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(dark ? 0.12 : 0.035), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

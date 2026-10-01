import Foundation

enum BonusRules {
    static func payments(_ values: [BonusPayment], for job: Employment) -> [BonusPayment] {
        Dictionary(grouping: values.filter { $0.employmentID == job.id }, by: \.id).values
            .compactMap { $0.max { $0.modifiedAt < $1.modifiedAt } }
            .sorted { ($0.year ?? Int.min, $0.month, $0.modifiedAt) > ($1.year ?? Int.min, $1.month, $1.modifiedAt) }
    }

    static func confirmed(_ values: [BonusPayment], for job: Employment) -> [BonusPayment] {
        payments(values, for: job).filter { $0.year != nil && $0.amountCents != nil }
    }

    static func total(_ values: [BonusPayment], for job: Employment) -> Int64? {
        let amounts = confirmed(values, for: job).compactMap(\.amountCents)
        guard !amounts.isEmpty else { return nil }
        return amounts.reduce(0, +)
    }

}

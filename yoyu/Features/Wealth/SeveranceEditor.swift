import SwiftUI
import SwiftData

private struct SeveranceDraft {
    var plan: SeverancePlan
    var base: String
    var notice: String
    var tenure: String

    init(_ settings: SeveranceSettings) {
        plan = settings.plan == .customAmount ? .nPlusOne : settings.plan
        base = ProfileRules.input(settings.baseSalaryCents)
        notice = ProfileRules.input(settings.noticeSalaryCents)
        tenure = ProfileRules.input(settings.tenureHundredths)
    }

    var settings: SeveranceSettings {
        var settings = SeveranceSettings()
        settings.plan = plan
        settings.baseSalaryCents = ProfileRules.scaledValue(base)
        settings.noticeSalaryCents = ProfileRules.scaledValue(notice)
        settings.tenureHundredths = ProfileRules.scaledValue(tenure, maximum: 10_000)
        return settings
    }

    var error: String? {
        let fields = [("月薪基数", base)] + (plan == .nPlusOne ? [("额外一个月工资", notice)] : [])
        for (name, value) in fields where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if ProfileRules.scaledValue(value) == nil { return "\(name)请输入非负金额，最多两位小数且不超过 1000 亿元。" }
        }
        if !tenure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ProfileRules.scaledValue(tenure, maximum: 10_000) == nil {
            return "补偿年限请输入 0 至 100，最多两位小数。"
        }
        return nil
    }
}

struct SeveranceEditor: View {
    let job: Employment
    let salaryCents: Int64?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CareerClock.self) private var clock
    @State private var draft: SeveranceDraft
    @State private var errorMessage: String?

    init(job: Employment, settings: SeveranceSettings, salaryCents: Int64?) {
        self.job = job
        self.salaryCents = salaryCents
        _draft = State(initialValue: SeveranceDraft(settings))
    }

    private var estimate: SeveranceRules.Estimate? {
        guard draft.error == nil else { return nil }
        return SeveranceRules.estimate(settings: draft.settings, job: job, salaryCents: salaryCents, on: clock.now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("补偿方式", selection: $draft.plan) {
                        ForEach(SeverancePlan.selectable) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    numberField("月薪基数", text: $draft.base, placeholder: automatic(salaryCents), unit: "元")
                    numberField("补偿年限 N", text: $draft.tenure, placeholder: automatic(SeveranceRules.tenureHundredths(start: job.start, on: clock.now)), unit: "年")
                    if draft.plan == .nPlusOne {
                        numberField("额外 1 个月工资", text: $draft.notice, placeholder: automatic(salaryCents), unit: "元")
                    }
                } header: {
                    Text("计算基数")
                } footer: {
                    Text(draft.plan == .twoN
                         ? "2N = N × 月薪基数 × 2。自动值：工资暂按当前税前月薪，N 按本企业工龄。"
                         : "自动值：工资暂按当前税前月薪，N 按本企业工龄。月薪基数与额外一个月工资可分别采用实际平均工资和上月工资。")
                }
                Section {
                    Button("恢复按工龄与当前月薪估算", systemImage: "arrow.counterclockwise") {
                        draft.base = ""
                        draft.notice = ""
                        draft.tenure = ""
                    }
                }

                Section {
                    AdaptiveValueRow(title: "预计补偿（税前）", value: estimate.map { ProfileRules.money($0.amountCents) } ?? "待补全")
                        .font(.body.weight(.semibold))
                } footer: {
                    Text("\(job.displayName) · 假设今天被裁员。补偿方案随本次任职保存。")
                }
                if let error = draft.error {
                    Section { Text(error).foregroundStyle(.red) }
                } else if estimate == nil {
                    Section { Text("工龄或工资资料待补全，或结果超过金额上限。请完善计算基数。") .foregroundStyle(.secondary) }
                }
            }.neutralPageBackground()
            .navigationTitle("补偿方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(estimate == nil) }
            }
            .saveErrorAlert($errorMessage)
        }
    }

    private func automatic(_ cents: Int64?) -> String {
        cents.map { "自动 \(ProfileRules.input($0))" } ?? "待填写"
    }

    private func numberField(_ title: String, text: Binding<String>, placeholder: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline)
            HStack {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(title)
                    .monospacedDigit()
                Text(unit).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        guard estimate != nil else { return }
        do {
            job.severanceData = try JSONEncoder().encode(draft.settings)
            job.modifiedAt = Date()
            if let message = context.saveOrRollback() { errorMessage = message } else { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

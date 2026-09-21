import SwiftUI
import SwiftData

struct SeveranceEditor: View {
    let job: Employment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var cap: String
    @State private var errorMessage: String?

    init(job: Employment, settings: SeveranceSettings) {
        self.job = job
        _cap = State(initialValue: ProfileRules.input(settings.tripleAverageSalaryCents))
    }

    private var validationError: String? {
        guard !cap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = ProfileRules.scaledValue(cap), value > 0 else {
            return "请输入大于 0 的金额，最多两位小数且不超过 1000 亿元。"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3倍社平").font(.subheadline)
                        HStack {
                            TextField("填写当地上年度3倍社平", text: $cap)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("3倍社平")
                                .monospacedDigit()
                            Text("元/月").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("填写已经乘以 3 的月金额。平均月工资高于此标准时，月薪基数按此封顶，补偿年限最多按 12 年。留空表示暂未应用封顶。")
                }
                Section {
                    Text("测算日期、工龄、平均月工资和上月工资均根据职业履历自动计算，不含股票。请在职业履历中补充或更新任职与薪资记录。")
                        .foregroundStyle(.secondary)
                }
                if let validationError {
                    Section { Text(validationError).foregroundStyle(.red) }
                }
            }
            .neutralPageBackground()
            .navigationTitle("补偿设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(validationError != nil)
                }
            }
            .saveErrorAlert($errorMessage)
        }
    }

    private func save() {
        guard validationError == nil else { return }
        var settings = SeveranceSettings()
        settings.tripleAverageSalaryCents = ProfileRules.scaledValue(cap)
        do {
            job.severanceData = try JSONEncoder().encode(settings)
            job.modifiedAt = Date()
            if let message = context.saveOrRollback() { errorMessage = message } else { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

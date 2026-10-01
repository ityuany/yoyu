import SwiftUI
import SwiftData

struct BonusPaymentEditor: View {
    let job: Employment
    let payment: BonusPayment?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var month: Int
    @State private var amount: String
    @State private var dateDraft: Date
    @State private var choosingDate = false
    @State private var confirmingDeletion = false
    @State private var error: String?

    init(job: Employment, payment: BonusPayment?) {
        self.job = job
        self.payment = payment
        let year = payment?.year ?? ProfileRules.calendar.component(.year, from: Date())
        _year = State(initialValue: year)
        let month = payment?.month ?? ProfileRules.calendar.component(.month, from: Date())
        _month = State(initialValue: month)
        _dateDraft = State(initialValue: ProfileRules.date(year, month, 1))
        _amount = State(initialValue: ProfileRules.input(payment?.amountCents))
    }

    var body: some View {
        NavigationStack {
            Form {
                if payment != nil && payment?.year == nil {
                    Section {
                        Text("这笔金额来自旧薪资记录。请核对发放年份；若与另一笔重复，可在下方删除。")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("实际发放时间") {
                    Button {
                        dateDraft = ProfileRules.date(year, month, 1)
                        choosingDate = true
                    } label: {
                        LabeledContent("发放年月", value: "\(year) 年 \(month) 月")
                    }
                }
                Section("税前年终奖收入") {
                    LabeledContent {
                        HStack {
                            TextField("待填写", text: $amount)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("税前年终奖金额")
                            Text("元").foregroundStyle(.secondary)
                        }
                    } label: { Text("实际收到（税前）") }
                }
                if let validation {
                    Section { Text(validation).foregroundStyle(.red) }
                }
                if payment != nil {
                    Section {
                        Button("删除年终奖记录", role: .destructive) {
                            confirmingDeletion = true
                        }
                    }
                }
            }
            .neutralPageBackground()
            .navigationTitle(payment == nil ? "新增年终奖" : "编辑年终奖")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(validation != nil)
                }
            }
            .sheet(isPresented: $choosingDate) {
                NavigationStack {
                    YearMonthWheel(selection: $dateDraft)
                    .frame(height: 200)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle("选择发放年月")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { choosingDate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                year = ProfileRules.calendar.component(.year, from: dateDraft)
                                month = ProfileRules.calendar.component(.month, from: dateDraft)
                                choosingDate = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog("删除这笔年终奖收入？", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button("删除记录", role: .destructive) { delete() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("删除后累计年终收入会重新计算，此操作无法撤销。")
            }
            .saveErrorAlert($error)
        }
    }

    private var validation: String? {
        guard let cents = ProfileRules.scaledValue(amount), cents >= 0 else {
            return "请输入有效的税前年终奖金额。"
        }
        let current = ProfileRules.calendar.dateComponents([.year, .month], from: Date())
        if year > (current.year ?? year) || year == current.year && month > (current.month ?? month) {
            return "实际发放时间不能晚于当前月份。"
        }
        return nil
    }

    private func save() {
        guard validation == nil else { return }
        let value = payment ?? BonusPayment()
        if payment == nil { context.insert(value) }
        value.employmentID = job.id
        value.year = year
        value.month = month
        value.amountCents = ProfileRules.scaledValue(amount)
        value.modifiedAt = Date()
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }

    private func delete() {
        guard let payment else { return }
        context.delete(payment)
        if let message = context.saveOrRollback() { error = message } else { dismiss() }
    }
}

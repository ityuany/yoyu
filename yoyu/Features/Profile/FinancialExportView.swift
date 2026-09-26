import SwiftUI
import SwiftData
import UIKit

struct FinancialExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var markdown = ""
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if let error {
                    ContentUnavailableView {
                        Label("无法生成财务摘要", systemImage: "exclamationmark.triangle")
                    } description: { Text(error) } actions: { Button("重试", action: generate) }
                } else if markdown.isEmpty {
                    ProgressView("正在整理财务信息…")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("仅在本机整理已录入的数据，复制或分享后可交给 AI 分析。")
                            .font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button {
                                UIPasteboard.general.string = markdown
                                copied = true
                            } label: {
                                Label("复制 Markdown", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("financialExport.copy")
                            ShareLink(item: markdown) { Label("分享", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered)
                        }
                        Text(copied ? "已复制，可粘贴给 AI" : " ")
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("financialExport.copyStatus")
                        ScrollView {
                            Text(verbatim: markdown)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("financialExport.content")
                        }
                    }.padding()
                }
            }
            .navigationTitle("财务 Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { generate() }
        }
    }

    private func generate() {
        do {
            // Fetch once so preview, copy and share all describe the same snapshot.
            markdown = FinancialMarkdown.make(
                profiles: try context.fetch(FetchDescriptor<UserProfile>()),
                jobs: try context.fetch(FetchDescriptor<Employment>()),
                stages: try context.fetch(FetchDescriptor<SalaryStage>()),
                contributions: try context.fetch(FetchDescriptor<ContributionStage>()),
                socialInsuranceMonths: try context.fetch(FetchDescriptor<SocialInsuranceMonth>()),
                holdings: try context.fetch(FetchDescriptor<StockHolding>()),
                liabilities: try context.fetch(FetchDescriptor<LiabilityAccount>()),
                expenses: try context.fetch(FetchDescriptor<RecurringExpense>()), now: Date())
            error = nil
        } catch { self.error = "读取本机记录失败，请重试。\(error.localizedDescription)" }
    }
}

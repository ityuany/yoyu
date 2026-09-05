import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Environment(SyncMonitor.self) private var sync
    @State private var editor: ProfileSection? = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--edit"), arguments.indices.contains(index + 1) {
            return ProfileSection(rawValue: arguments[index + 1])
        }
        #endif
        return nil
    }()
    private func profile(for section: ProfileSection) -> UserProfile? {
        profiles.max { $0.updatedAt(for: section) < $1.updatedAt(for: section) }
    }
    private var basicProfile: UserProfile? { profile(for: .basic) }
    private var employmentProfile: UserProfile? { profile(for: .employment) }
    private var wealthProfile: UserProfile? { profile(for: .wealth) }
    private var workProfile: UserProfile? { profile(for: .work) }
    @State private var path: [String] = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--holidays") { return ["holidays"] }
        #endif
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button { editor = .basic } label: {
                        menuRow("基本信息", subtitle: basicSummary, icon: "person.crop.circle", color: .blue)
                    }
                    if let profile = basicProfile, profile.retirement != "待完善" {
                        LabeledContent("预计退休", value: profile.retirement)
                            .foregroundStyle(.secondary)
                    }
                } header: { Text("个人") }

                Section {
                    Button { editor = .employment } label: {
                        menuRow("薪资待遇", subtitle: salarySummary, icon: "building.2", color: .indigo)
                    }
                    Button { editor = .work } label: {
                        menuRow("工作安排", subtitle: workSummary, icon: "clock", color: .orange)
                    }
                } header: { Text("企业信息") }

                Section {
                    Button { editor = .wealth } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("当前财富", systemImage: "wallet.bifold")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            Text(ProfileRules.money(wealthProfile?.totalWealth))
                                .font(.largeTitle.weight(.semibold)).monospacedDigit()
                                .minimumScaleFactor(0.65)
                            Text(wealthSummary).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    LabeledContent("现金", value: ProfileRules.money(wealthProfile?.cashCents))
                    LabeledContent {
                        Text(ProfileRules.money(wealthProfile?.stockValueCents))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("股票")
                            if let shares = wealthProfile?.stockSharesHundredths, let price = wealthProfile?.stockPriceCents {
                                Text("\(ProfileRules.input(shares)) 股 × \(ProfileRules.money(price))/股")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    LabeledContent("理财", value: ProfileRules.money(wealthProfile?.investmentCents))
                    if let rate = wealthProfile?.investmentAnnualReturnBasisPoints {
                        LabeledContent("年化收益率", value: "\(ProfileRules.input(rate))%")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } header: { Text("资产") }

                Section {
                    NavigationLink(value: "holidays") {
                        Label("调休安排", systemImage: "calendar.badge.clock")
                    }
                } footer: { Text("查看当年国务院办公厅公布的节假日及补班安排。") }

                Section("数据管理") {
                    NavigationLink {
                        SyncStatusView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("iCloud 同步", systemImage: "icloud")
                            Text(sync.accountMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: String.self) { _ in HolidayScheduleView() }
            .sheet(item: $editor) { section in
                ProfileEditor(section: section, profile: profile(for: section))
            }
            .task { await sync.checkAccount() }
        }
    }

    private var basicSummary: String {
        guard let profile = basicProfile else { return "完善出生年月与性别" }
        var items: [String] = []
        if let year = profile.birthYear, let month = profile.birthMonth { items.append("\(year) 年 \(month) 月") }
        if !profile.gender.isEmpty { items.append(profile.gender) }
        return items.isEmpty ? "完善出生年月与性别" : items.joined(separator: " · ")
    }
    private var salarySummary: String {
        guard let salary = employmentProfile?.salaryCents else { return "设置入职时间、月薪与年终奖" }
        return "税前月薪 \(ProfileRules.money(salary))"
    }
    private var workSummary: String {
        let start = workProfile?.startMinutes ?? 540
        let end = workProfile?.endMinutes ?? 1080
        return "\(ProfileRules.timeLabel(start))—\(ProfileRules.timeLabel(end)) · \((workProfile?.followsHolidays ?? true) ? "跟随国家调休" : "自定义工作日")"
    }
    private var wealthSummary: String {
        let count = [wealthProfile?.cashCents, wealthProfile?.stockValueCents, wealthProfile?.investmentCents].compactMap { $0 }.count
        return count == 3 ? "现金、股票与理财的当前总额" : "已填写 \(count)/3 项 · 总额仅汇总已填写金额"
    }
    private func menuRow(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2).foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

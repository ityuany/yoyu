import SwiftUI

/// Keep today’s earnings at the visual center; supporting details sit at the edges.
struct TodayDashboard: View {
    let jobs: [Employment]
    let stages: [SalaryStage]
    let now: Date
    var isPreview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCalculation = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let job = CareerRules.current(jobs, on: now) {
                    if let value = TodayIncome.snapshot(job: job, stages: stages, now: now) {
                        focusedDashboard(value, job: job, height: geometry.size.height)
                    } else {
                        setup(title: "再补充一点，就能看见今日收入", message: "完善入职日期、月薪和上下班时间，悠悠就能帮你估算每天的积累。", destination: .employment(job.id))
                    }
                } else {
                    setup(title: "让每一份努力，都看得见", message: "添加当前企业，填写薪资与工作安排，看看每一天的努力如何慢慢积累。若有多段在职经历，请先完善离职日期。", destination: .history)
                }
            }
            .contentMargins(.horizontal, DashboardStyle.pageInset, for: .scrollContent)
            .background(DashboardStyle.background)
        }
    }

    private func focusedDashboard(_ value: TodayIncome.Snapshot, job: Employment, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                dateLabel(value.day, isShift: value.status != .rest)
                Spacer()
                NavigationLink(value: CareerDestination.employment(job.id)) {
                    Label("工作安排", systemImage: "calendar")
                        .font(.caption)
                        .frame(minHeight: 44)
                }
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 48)

            incomeFocus(value, job: job)

            Spacer(minLength: 64)

            HStack(alignment: .top, spacing: 24) {
                metric("\(monthLabel(value.day))已赚", value: value.monthCents.map { ProfileRules.money($0) } ?? "待补全")
                metric("\(monthLabel(value.day))已完成", value: "\(value.completedWorkdays) 个工作日")
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 24)
            .overlay(alignment: .top) { Divider().opacity(0.5) }

            calculationNotes(value)
            previewNotice
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(minHeight: max(0, height))
    }

    private func incomeFocus(_ value: TodayIncome.Snapshot, job: Employment) -> some View {
        let title = value.status == .beforeWork ? "今日预计收入"
            : value.status == .rest ? "今日已赚"
            : ProfileRules.calendar.isDate(value.day, inSameDayAs: now) ? "今日已赚" : "本班已赚"
        let amount = value.status == .beforeWork ? value.dailyCents : value.earnedCents
        return VStack(spacing: 18) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(ProfileRules.money(amount))
                .font(.system(size: 58, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: amount)
                .accessibilityLabel("\(title) \(ProfileRules.money(amount))，税前估算")
            HStack(spacing: 6) {
                if value.status == .working {
                    Circle().fill(DashboardStyle.accent).frame(width: 5, height: 5)
                }
                Text(statusLabel(value.status))
                Text("· 税前估算")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                if value.status == .working || value.status == .beforeWork {
                    ProgressView(value: value.progress)
                        .tint(DashboardStyle.accent.opacity(0.55))
                        .accessibilityLabel("今日工作进度")
                    Text(value.status == .beforeWork
                         ? "距上班 \(duration(value.start.timeIntervalSince(now)))"
                         : "今日预计 \(ProfileRules.money(value.dailyCents)) · 距下班 \(duration(value.end.timeIntervalSince(now)))")
                        .monospacedDigit()
                } else if value.status == .rest {
                    Text("今天休息，给自己留一点时间。")
                } else {
                    Text("辛苦了，今天的工作告一段落。")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
            .frame(maxWidth: 320)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func dateLabel(_ date: Date, isShift: Bool) -> some View {
        let calendar = ProfileRules.calendar
        let parts = calendar.dateComponents([.month, .day], from: date)
        let fullDate = date.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: Locale(identifier: "zh_CN"), calendar: calendar, timeZone: calendar.timeZone))
        return Text("\(parts.month!)月\(parts.day!)日 · \(Weekday(date).name)")
            .font(.caption)
            .accessibilityLabel("\(isShift ? "班次日期" : "日期")，\(fullDate)")
    }

    private func monthLabel(_ date: Date) -> String {
        let calendar = ProfileRules.calendar
        let parts = calendar.dateComponents([.year, .month], from: date)
        let current = calendar.dateComponents([.year, .month], from: now)
        guard parts != current else { return "本月" }
        return parts.year == current.year ? "\(parts.month!)月" : "\(parts.year!)年\(parts.month!)月"
    }

    @ViewBuilder
    private var previewNotice: some View {
        #if DEBUG
        if isPreview {
            Label("预览时间 · 仅供查看", systemImage: "clock")
                .font(.caption).foregroundStyle(.orange)
        }
        #endif
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calculationNotes(_ value: TodayIncome.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showsCalculation) {
                Text("按本月应工作日分摊各日生效的税前月薪，再按上下班之间的时长均匀累计，不单独扣除午休。仅为收入估算，不代表实际到账，暂不含奖金。")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                Text("收入如何计算")
                    .frame(minHeight: 44)
            }
            if value.missingHolidayYear {
                Text("该年节假日资料尚未收录，应工作日暂按每周工作安排估算。")
            }
            if ProfileRules.calendar.startOfDay(for: value.day) != ProfileRules.calendar.startOfDay(for: now) {
                Text("当前显示上一日开始的跨夜班次，收入归入班次开始日。")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .tint(DashboardStyle.accent)
    }

    private func setup(title: String, message: String, destination: CareerDestination) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sun.max").font(.largeTitle).foregroundStyle(DashboardStyle.accent)
            Text(title).font(.title2.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            NavigationLink("完善企业信息", value: destination)
                .buttonStyle(.borderedProminent).controlSize(.large)
            previewNotice
        }
        .dashboardCard()
    }

    private func statusLabel(_ status: TodayIncome.Status) -> String {
        switch status {
        case .beforeWork: "等待上班"
        case .working: "正在累计"
        case .finished: "已下班"
        case .rest: "休息日"
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let seconds = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

}

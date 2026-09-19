import SwiftUI

/// Work centers on accumulation; days off make room for a quieter scene.
struct TodayDashboard: View {
    let jobs: [Employment]
    let stages: [SalaryStage]
    let now: Date
    var isPreview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

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
        let mood = TodayMood(day: value.day, isRest: value.status == .rest, followsHolidays: job.followsHolidays)
        let palette = TodayPalette(mood: mood, dark: colorScheme == .dark)
        return VStack(spacing: 16) {
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

            VStack(alignment: .leading, spacing: 0) {
                Text("\(mood.label) · \(statusLabel(value.status))")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(palette.ink.opacity(0.07), in: Capsule())

                TodayScene(mood: mood, finished: value.status == .finished, ink: palette.ink)
                    .frame(height: value.status == .rest ? 148 : 96)
                    .padding(.horizontal, -24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                if value.status == .rest {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(mood.restTitle)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                        Text(mood.subtitle)
                            .font(.subheadline).opacity(0.8)
                        Rectangle().fill(palette.ink.opacity(0.12)).frame(height: 1)
                            .padding(.top, 20)
                        Text("今日休息，不累计收入")
                            .font(.caption).opacity(0.8)
                            .padding(.top, 4)
                    }
                } else {
                    incomeFocus(value, mood: mood, ink: palette.ink)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(palette.ink)
            .background(palette.fill, in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.10 : 0.8), lineWidth: 1)
                    .allowsHitTesting(false)
            }

            HStack(alignment: .top, spacing: 12) {
                metric("\(monthLabel(value.day))已赚", value: value.monthCents.map { ProfileRules.money($0) } ?? "待补全", hue: 0.12)
                metric("\(monthLabel(value.day))已完成", value: "\(value.completedWorkdays) 个工作日", hue: 0.70)
            }
            calculationNotes(value)
            previewNotice
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(minHeight: max(0, height), alignment: .top)
    }

    private func incomeFocus(_ value: TodayIncome.Snapshot, mood: TodayMood, ink: Color) -> some View {
        let title = value.status == .beforeWork ? "今日预计收入"
            : ProfileRules.calendar.isDate(value.day, inSameDayAs: now) ? "今日已赚" : "本班已赚"
        let amount = value.status == .beforeWork ? value.dailyCents : value.earnedCents
        return VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline)
            Text(ProfileRules.money(amount))
                .font(.system(size: 50, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: amount)
                .accessibilityLabel("\(title) \(ProfileRules.money(amount))，税前估算")
            Text("税前估算 · \(value.status == .finished ? "今天的积累已完成" : mood.subtitle)")
                .font(.caption).opacity(0.8)

            if value.status == .working || value.status == .beforeWork {
                ProgressView(value: value.progress)
                    .tint(ink.opacity(0.65))
                    .accessibilityLabel("今日工作进度")
                    .padding(.top, 14)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        progressAmount(value)
                        Spacer(minLength: 12)
                        shiftCountdown(value)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        progressAmount(value)
                        shiftCountdown(value)
                    }
                }
                .font(.caption).opacity(0.85)
            } else {
                Text("辛苦了，把接下来的时间留给自己。")
                    .font(.caption).opacity(0.8).padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressAmount(_ value: TodayIncome.Snapshot) -> some View {
        Text(value.status == .beforeWork ? "等待上班" : "预计 \(ProfileRules.money(value.dailyCents))")
            .monospacedDigit()
    }

    private func shiftCountdown(_ value: TodayIncome.Snapshot) -> some View {
        Text(value.status == .beforeWork
             ? "距上班 \(duration(value.start.timeIntervalSince(now)))"
             : "距下班 \(duration(value.end.timeIntervalSince(now)))")
            .monospacedDigit()
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

    private func metric(_ title: String, value: String, hue: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(hue: hue, saturation: colorScheme == .dark ? 0.22 : 0.07, brightness: colorScheme == .dark ? 0.19 : 0.95),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private func calculationNotes(_ value: TodayIncome.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
        case .rest: "休息中"
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let seconds = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

}

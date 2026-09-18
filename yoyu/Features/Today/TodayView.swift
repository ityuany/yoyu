import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    #if DEBUG
    private let launchTime = Date()
    private let previewTime: Date? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--today-at"), args.indices.contains(index + 1) else { return nil }
        return ISO8601DateFormatter().date(from: args[index + 1])
    }()
    #endif

    var body: some View {
        NavigationStack {
            TimelineView(.animation(minimumInterval: 1, paused: scenePhase != .active || !isVisible)) { timeline in
                let now = displayTime(timeline.date)
                #if DEBUG
                TodayDashboard(jobs: jobs, stages: stages, now: now, isPreview: previewTime != nil)
                #else
                TodayDashboard(jobs: jobs, stages: stages, now: now)
                #endif
            }
            .dashboardTabRoot(title: "今日")
            .navigationDestination(for: CareerDestination.self) { CareerView(destination: $0) }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private func displayTime(_ date: Date) -> Date {
        #if DEBUG
        if let previewTime { return previewTime.addingTimeInterval(date.timeIntervalSince(launchTime)) }
        #endif
        return date
    }
}

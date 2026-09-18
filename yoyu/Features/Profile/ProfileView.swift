import SwiftUI
import SwiftData

enum ProfileRoute: Hashable {
    case detail(ProfileSection)
    case holidays
    case sync
}

struct ProfileView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query private var jobs: [Employment]
    @Query private var stages: [SalaryStage]
    @Environment(\.modelContext) private var context
    @State private var migrationError: String?
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
    @State private var path: NavigationPath = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--detail"), arguments.indices.contains(index + 1),
           let section = ProfileSection(rawValue: arguments[index + 1]) { return NavigationPath([ProfileRoute.detail(section)]) }
        if arguments.contains("--career-review") { return NavigationPath([CareerDestination.history, CareerDestination.review]) }
        if arguments.contains("--career-history") { return NavigationPath([CareerDestination.history]) }
        if arguments.contains("--sync") { return NavigationPath([ProfileRoute.sync]) }
        if arguments.contains("--holidays") { return NavigationPath([ProfileRoute.holidays]) }
        #endif
        return NavigationPath()
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ProfileMenuView(summary: basicSummary, syncStatus: sync.summary)
            .dashboardTabRoot(title: "我的")
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .detail(let section):
                    if section == .employment || section == .work {
                        CareerView(destination: section == .work ? .work : .salary)
                    } else { ProfileDetailView(section: section) }
                case .holidays: HolidayScheduleView()
                case .sync: SyncStatusView()
                }
            }
            .navigationDestination(for: CareerDestination.self) { CareerView(destination: $0) }
            .sheet(item: $editor) { section in
                if section == .employment || section == .work {
                    NavigationStack {
                        CareerView(destination: section == .work ? .work : .salary)
                            .navigationDestination(for: CareerDestination.self) { CareerView(destination: $0) }
                    }
                } else { ProfileEditor(section: section, profile: profile(for: section)) }
            }
            .task { await sync.checkAccount() }
            .task(id: profiles.map { "\($0.createdAt)-\($0.employmentUpdatedAt?.description ?? "")-\($0.careerMigrated)" }.joined()) {
                do { try CareerRules.migrate(context: context, profiles: profiles, jobs: jobs, stages: stages) }
                catch { migrationError = "原始资料已保留，企业履历衔接失败：\(error.localizedDescription)" }
            }
            .saveErrorAlert($migrationError)
        }
    }

    private var basicSummary: String {
        guard let profile = basicProfile else { return "完善出生年月与性别" }
        var items: [String] = []
        if let year = profile.birthYear, let month = profile.birthMonth { items.append("\(year) 年 \(month) 月") }
        if !profile.gender.isEmpty { items.append(profile.gender) }
        return items.isEmpty ? "完善出生年月与性别" : items.joined(separator: " · ")
    }
}

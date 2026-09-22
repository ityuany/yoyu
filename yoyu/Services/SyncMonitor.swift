import SwiftUI
import SwiftData
import CloudKit
import CoreData

@Observable
final class SyncMonitor {
    let preference = SyncPreference()
    var cloudEnabled = false
    var accountID: String?
    var accountNeedsApproval = false
    var summary: String {
        if preference.enabled != cloudEnabled {
            return preference.enabled ? "等待启用 · 当前仅本地存储" : "关闭待生效 · 当前仍启用同步"
        }
        return cloudEnabled ? accountMessage : "同步已关闭 · 仅本地存储"
    }
    var accountMessage = "正在检查 iCloud"
    var activityMessage = "等待同步事件"
    var guidance = "数据会先保存到本机，iCloud 可用时由系统自动同步。"
    var accountGuidance: String?
    var lastIssue: SyncIssue?
    var lastTransfer: Date?
    var checking = false
    private var activeEvents: Set<UUID> = []
    private var observer: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?
    static let containerID = "iCloud.com.ityuany.yoyu"

    init() {
        accountObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.checkAccount() }
        }
        observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor [weak self] in self?.receive(event) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let accountObserver { NotificationCenter.default.removeObserver(accountObserver) }
    }

    private func receive(_ event: NSPersistentCloudKitContainer.Event) {
        guard cloudEnabled else { return }
        if event.endDate == nil {
            activeEvents.insert(event.identifier)
            activityMessage = "正在同步"
        } else {
            activeEvents.remove(event.identifier)
            if let error = event.error {
                activityMessage = "同步遇到问题"
                lastIssue = SyncIssue(error: error, phase: phaseName(event.type), date: event.endDate ?? event.startDate)
                guidance = "本机数据仍然保留，具体原因请查看下方“最近一次同步问题”。"
            } else if event.succeeded {
                if event.type == .import || event.type == .export { lastTransfer = event.endDate }
                activityMessage = activeEvents.isEmpty ? (lastTransfer == nil ? "等待数据同步" : "最近一次传输完成") : "正在同步"
                guidance = "系统会自动同步后续更改；最近一次传输完成不代表所有设备已更新。"
            } else {
                activityMessage = "同步未完成"
                lastIssue = SyncIssue(error: nil, phase: phaseName(event.type), date: event.endDate ?? event.startDate)
            }
        }
    }

    private func phaseName(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: "初始化同步"
        case .import: "下载云端数据"
        case .export: "上传本机数据"
        @unknown default: "未知同步环节"
        }
    }

    func checkAccount() async {
        guard !checking else { return }
        checking = true
        accountID = nil
        accountNeedsApproval = false
        defer { checking = false }
        do {
            switch try await CKContainer(identifier: Self.containerID).accountStatus() {
            case .available:
                accountMessage = "iCloud 已连接"
                let identity = try await CKContainer(identifier: Self.containerID).userRecordID().recordName
                accountID = identity
                accountNeedsApproval = preference.approvedAccount != identity
                accountGuidance = accountNeedsApproval
                    ? (cloudEnabled ? "检测到账户变化。当前会话的自动同步无法在此即时停止，请完全关闭应用后重新打开；下次启动会先使用本地数据，等待你确认账户。" : "启用前需要确认使用当前 iCloud 账户。本机已有数据可能包含之前账户的内容。")
                    : nil
            case .noAccount:
                accountMessage = "未登录 iCloud"
                accountGuidance = "请在系统设置中登录 Apple 账户并开启 iCloud。本机已保存的数据可继续使用。"
            case .restricted:
                accountMessage = "iCloud 访问受限"
                accountGuidance = "请检查系统账户限制或联系设备管理员。本机数据可继续使用。"
            case .temporarilyUnavailable, .couldNotDetermine:
                accountMessage = "暂时无法连接 iCloud"
                accountGuidance = "请检查网络并稍后重新检查。本机数据可继续使用。"
            @unknown default:
                accountMessage = "无法确定 iCloud 状态"
            }
        } catch {
            accountMessage = "无法连接 iCloud"
            accountGuidance = "请检查网络和系统中的 iCloud 设置。\n\(error.localizedDescription)"
        }
    }
}

struct SyncIssue {
    let phase: String
    let date: Date
    let details: String

    init(error: Error?, phase: String, date: Date) {
        self.phase = phase
        self.date = date
        if let error {
            var visited = Set<ObjectIdentifier>()
            self.details = Self.describe(error as NSError, depth: 0, visited: &visited)
        } else {
            self.details = "系统报告同步未完成，但没有提供具体错误。请等待后续同步事件。"
        }
    }

    var report: String {
        "失败环节：\(phase)\n时间：\(date.formatted(date: .numeric, time: .standard))\n\(details)"
    }

    private static func describe(_ error: NSError, depth: Int, visited: inout Set<ObjectIdentifier>) -> String {
        guard depth < 8, visited.insert(ObjectIdentifier(error)).inserted else { return "（重复或过深的错误信息已省略）" }
        var lines = ["\(error.domain) · 错误码 \(error.code)", error.localizedDescription]
        if let reason = error.localizedFailureReason { lines.append("原因：" + reason) }
        if let suggestion = error.localizedRecoverySuggestion { lines.append("建议：" + suggestion) }
        if let retry = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            lines.append("系统建议 \(retry) 秒后重试；实际传输由系统调度。")
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("底层错误：\n" + describe(underlying, depth: depth + 1, visited: &visited))
        }
        if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for item in detailed.prefix(10) {
                lines.append("详细错误：\n" + describe(item, depth: depth + 1, visited: &visited))
            }
            if detailed.count > 10 { lines.append("其余详细错误已省略。") }
        }
        // Only include errors, not record identifiers or business data from userInfo.
        if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError] {
            for item in partial.values.prefix(10) {
                lines.append("部分项目错误：\n" + describe(item, depth: depth + 1, visited: &visited))
            }
            if partial.count > 10 { lines.append("其余项目错误已省略。") }
        }
        return lines.joined(separator: "\n")
    }
}

@MainActor @Observable
final class AppStorageController {
    let sync = SyncMonitor()
    var container: ModelContainer?
    var errorMessage: String?
    var starting = false

    func start() async {
        guard !starting, container == nil else { return }
        starting = true
        // Account services can stall offline. Do not hold local data hostage to them.
        let timeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            self?.continueLocally()
        }
        defer { timeout.cancel() }
        if sync.preference.enabled { await sync.checkAccount() }
        guard container == nil, errorMessage == nil else { return }
        openStore(cloud: sync.preference.enabled && sync.accountID != nil && !sync.accountNeedsApproval)
    }

    func continueLocally() {
        guard container == nil else { return }
        openStore(cloud: false)
    }

    private func openStore(cloud: Bool) {
        do {
            let schema = Schema([UserProfile.self, WorkdayOverride.self, Employment.self, SalaryStage.self, StockHolding.self, LiabilityAccount.self, RecurringExpense.self, ForecastScenarioRecord.self])
            // Keep the existing default store location in both modes. Never copy or delete it.
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: cloud ? .private(SyncMonitor.containerID) : .none)
            container = try ModelContainer(for: schema, configurations: [configuration])
            sync.cloudEnabled = cloud
            if !cloud { sync.activityMessage = "当前仅本地存储" }
        } catch {
            errorMessage = "本机数据未被删除。请重新启动应用后重试。\n\(error.localizedDescription)"
        }
    }
}

struct SyncStatusView: View {
    @Environment(SyncMonitor.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
    @State private var requestedValue: Bool?
    @State private var requestedAccount: String?
    @State private var confirming = false

    var body: some View {
        List {
            Section {
                Toggle("使用 iCloud 同步", isOn: Binding(
                    get: { sync.preference.enabled },
                    set: { requestedValue = $0; requestedAccount = sync.accountID; confirming = true }
                ))
                Text(sync.summary).foregroundStyle(.secondary)
                if sync.preference.enabled && !sync.cloudEnabled {
                    if sync.accountNeedsApproval, sync.accountID != nil {
                        Button("确认使用当前 iCloud 账户") {
                            requestedAccount = sync.accountID
                            requestedValue = true
                            confirming = true
                        }
                    } else if sync.accountID != nil {
                        Text("请完全关闭应用后重新打开，以启用同步。")
                    } else {
                        Text("等待 iCloud 账户可用。账户恢复后，请重新打开应用以启用同步。")
                    }
                } else if !sync.preference.enabled && sync.cloudEnabled {
                    Text("请完全关闭应用后重新打开。生效前，当前会话仍可能上传和下载数据。")
                        .foregroundStyle(.orange)
                }
            } header: { Text("此设备") } footer: {
                Text("开关更改在下次启动生效。关闭不会删除本机或 iCloud 已有数据，也不会改变其他设备的设置。")
            }
            Section {
                Label(sync.accountMessage, systemImage: "icloud")
                LabeledContent("同步活动", value: sync.activityMessage)
                if let date = sync.lastTransfer {
                    LabeledContent("本次运行最近传输", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            } header: { Text("iCloud 同步") } footer: {
                Text([sync.accountGuidance, sync.cloudEnabled ? sync.guidance : "本机数据可正常使用。开启同步后，本机和云端数据将参与合并。"].compactMap { $0 }.joined(separator: "\n"))
            }
            if let issue = sync.lastIssue {
                Section {
                    LabeledContent("失败环节", value: issue.phase)
                    LabeledContent("发生时间", value: issue.date.formatted(date: .abbreviated, time: .standard))
                    Text(issue.details)
                        .font(.footnote)
                        .textSelection(.enabled)
                    Button("复制诊断信息", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = issue.report
                    }
                } header: { Text("最近一次同步问题") } footer: {
                    Text("保留本次运行中最近一次失败的详情，方便排查；后续传输成功也不会立即清除这条记录。账户已连接不代表数据传输已成功。")
                }
            }
            Section {
                Button {
                    Task { await sync.checkAccount() }
                } label: {
                    HStack {
                        Text("重新检查账户状态")
                        Spacer()
                        if sync.checking { ProgressView() }
                    }
                }
                .disabled(sync.checking)
            } footer: {
                Text("重新检查只更新账户状态，不会启动数据同步。使用不同的 Apple 账户前，请先关闭同步并重新启动应用。")
            }
        }
        .neutralPageBackground()
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
        .alert(requestedValue == false ? "关闭此设备的 iCloud 同步？" : "使用当前 iCloud 账户同步？", isPresented: $confirming) {
            Button("取消", role: .cancel) { requestedValue = nil }
            Button(requestedValue == false ? "关闭同步" : "确认开启") {
                if let value = requestedValue {
                    sync.preference.setEnabled(value)
                    if value, let identity = requestedAccount, identity == sync.accountID {
                        sync.preference.approve(account: identity)
                        sync.accountNeedsApproval = false
                    }
                }
                requestedValue = nil
            }
        } message: {
            Text(requestedValue == false
                 ? "本机和云端已有数据会保留。下次启动生效；在此之前仍可能继续同步。"
                 : "本机已有数据将与当前账户的 iCloud 数据合并，并可能上传到该账户。请确认这是你希望使用的账户。未登录时会保留开启意愿，登录后仍需确认账户。下次启动生效。")
        }
        #if os(iOS)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .task { await sync.checkAccount() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await sync.checkAccount() } }
        }
    }
}

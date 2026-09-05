import SwiftUI
import SwiftData
import CloudKit
import CoreData

@Observable
final class SyncMonitor {
    var accountMessage = "正在检查 iCloud"
    var activityMessage = "等待同步事件"
    var guidance = "数据会先保存到本机，iCloud 可用时由系统自动同步。"
    var lastTransfer: Date?
    var checking = false
    private var activeEvents: Set<UUID> = []
    private var observer: NSObjectProtocol?
    static let containerID = "iCloud.devplaceholder.Y3VZXX26.yoyu"

    init() {
        observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor [weak self] in self?.receive(event) }
        }
    }

    private func receive(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            activeEvents.insert(event.identifier)
            activityMessage = "正在同步"
        } else {
            activeEvents.remove(event.identifier)
            if let error = event.error {
                activityMessage = "同步遇到问题"
                guidance = "本机数据仍然保留。请检查网络、iCloud 登录及剩余空间后重试。\n\(error.localizedDescription)"
            } else if event.succeeded {
                if event.type == .import || event.type == .export { lastTransfer = event.endDate }
                activityMessage = activeEvents.isEmpty ? (lastTransfer == nil ? "等待数据同步" : "最近一次传输完成") : "正在同步"
                guidance = "系统会自动同步后续更改；最近一次传输完成不代表所有设备已更新。"
            }
        }
    }

    func checkAccount() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        do {
            switch try await CKContainer(identifier: Self.containerID).accountStatus() {
            case .available:
                accountMessage = "iCloud 已连接"
            case .noAccount:
                accountMessage = "未登录 iCloud"
                guidance = "请在系统设置中登录 Apple 账户并开启 iCloud。本机已保存的数据可继续使用。"
            case .restricted:
                accountMessage = "iCloud 访问受限"
                guidance = "请检查系统账户限制或联系设备管理员。本机数据可继续使用。"
            case .temporarilyUnavailable, .couldNotDetermine:
                accountMessage = "暂时无法连接 iCloud"
                guidance = "请检查网络并稍后重新检查。本机数据可继续使用。"
            @unknown default:
                accountMessage = "无法确定 iCloud 状态"
            }
        } catch {
            accountMessage = "无法连接 iCloud"
            guidance = "请检查网络和系统中的 iCloud 设置。\n\(error.localizedDescription)"
        }
    }
}

final class AppStorageController {
    let sync = SyncMonitor()
    var container: ModelContainer?
    var errorMessage: String?

    init() {
        do {
            let schema = Schema([UserProfile.self, WorkdayOverride.self])
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(SyncMonitor.containerID))
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            errorMessage = "本机数据未被删除。请重新启动应用后重试。\n\(error.localizedDescription)"
        }
    }
}

struct SyncStatusView: View {
    @Environment(SyncMonitor.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Label(sync.accountMessage, systemImage: "icloud")
                LabeledContent("同步活动", value: sync.activityMessage)
                if let date = sync.lastTransfer {
                    LabeledContent("本次运行最近传输", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            } header: { Text("iCloud 同步") } footer: { Text(sync.guidance) }
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
                Text("资料保存在本机，并通过你的 iCloud 私有数据库跨设备同步。重新检查只检查账户连接，数据传输由系统自动调度。")
            }
        }
        .navigationTitle("iCloud 同步")
        #if os(iOS)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .task { await sync.checkAccount() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await sync.checkAccount() } }
        }
    }
}

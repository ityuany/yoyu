import Foundation
import Observation
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

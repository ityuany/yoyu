import Foundation
import Observation
import SwiftData
import CloudKit
import CoreData

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
            let schema = AppModelSchema.schema
            // Keep the existing default store location in both modes. Never copy or delete it.
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: cloud ? .private(SyncMonitor.containerID) : .none)
            container = try ModelContainer(for: schema, configurations: [configuration])
            if let container {
                do { try CareerRules.normalizeEmploymentMonths(context: ModelContext(container)) }
                catch { sync.activityMessage = "任职月份整理未完成：\(error.localizedDescription)" }
                do { try CareerRules.normalizeSalaryStageMonths(context: ModelContext(container)) }
                catch { sync.activityMessage = "薪资月份整理未完成：\(error.localizedDescription)" }
                do { try BonusRules.importLegacyStagePayments(context: ModelContext(container)) }
                catch { sync.activityMessage = "年终奖记录整理未完成：\(error.localizedDescription)" }
                do { try SocialInsuranceLimitDefaults.importIfNeeded(context: ModelContext(container)) }
                catch { sync.activityMessage = "社保上下限默认资料导入未完成：\(error.localizedDescription)" }
                do { try HousingFundLimitDefaults.importIfNeeded(context: ModelContext(container)) }
                catch { sync.activityMessage = "公积金基数范围默认资料导入未完成：\(error.localizedDescription)" }
            }
            var migrationIssue: String?
            if let container {
                do { try StructuredDataMigration.run(context: ModelContext(container)) }
                catch { migrationIssue = "业务数据结构整理未完成：\(error.localizedDescription)" }
            }
            sync.cloudEnabled = cloud
            if let migrationIssue { sync.activityMessage = migrationIssue }
            else if !cloud && !sync.activityMessage.hasPrefix("养老保险基数整理未完成") { sync.activityMessage = "当前仅本地存储" }
        } catch {
            errorMessage = "本机数据未被删除。请重新启动应用后重试。\n\(error.localizedDescription)"
        }
    }

}

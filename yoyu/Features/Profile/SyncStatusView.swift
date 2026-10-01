import SwiftUI
import SwiftData
import CloudKit
import CoreData

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
                Text(sync.summary).foregroundStyle(AppTheme.secondaryText)
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
                        .foregroundStyle(AppTheme.warning)
                }
            } header: { Text("此设备") } footer: {
                Text("开关更改在下次启动生效。关闭不会删除本机或 iCloud 已有数据，也不会改变其他设备的设置。")
            }.listRowBackground(AppTheme.cardBackground)
            Section {
                Label(sync.accountMessage, systemImage: "icloud")
                LabeledContent("同步活动", value: sync.activityMessage)
                if let date = sync.lastTransfer {
                    LabeledContent("本次运行最近传输", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            } header: { Text("iCloud 同步") } footer: {
                Text([sync.accountGuidance, sync.cloudEnabled ? sync.guidance : "本机数据可正常使用。开启同步后，本机和云端数据将参与合并。"].compactMap { $0 }.joined(separator: "\n"))
            }.listRowBackground(AppTheme.cardBackground)
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
                }.listRowBackground(AppTheme.cardBackground)
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
            }.listRowBackground(AppTheme.cardBackground)
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

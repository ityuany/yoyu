import SwiftUI

struct ProfileMenuView: View {
    let summary: String
    let syncStatus: String

    var body: some View {
        List {
            Section {
                NavigationLink(value: ProfileRoute.detail(.basic)) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("个人资料")
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                .accessibilityHint("查看和编辑基本信息")
            }

            Section("工作与安排") {
                NavigationLink(value: CareerDestination.history) {
                    Label("企业履历", systemImage: "building.2")
                }
                NavigationLink(value: ProfileRoute.holidays) {
                    Label("调休安排", systemImage: "calendar.badge.clock")
                }
            }

            Section("数据与同步") {
                NavigationLink {
                    SyncStatusView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("iCloud 同步")
                            Text(syncStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "icloud")
                    }
                }
            }
        }.neutralPageBackground()
        .listStyle(.insetGrouped)
    }
}

#Preview("浅色") {
    NavigationStack {
        ProfileMenuView(summary: "1991 年 5 月 · 男", syncStatus: "已连接 iCloud")
            .dashboardTabRoot(title: "我的")
    }
    .preferredColorScheme(.light)
}

#Preview("深色与未填写资料") {
    NavigationStack {
        ProfileMenuView(summary: "完善出生年月与性别", syncStatus: "暂时无法连接 iCloud，请检查网络连接并确认已在系统设置中登录 iCloud。")
            .dashboardTabRoot(title: "我的")
    }
    .preferredColorScheme(.dark)
}

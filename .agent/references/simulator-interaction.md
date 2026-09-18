# 模拟器交互流程

## 正常使用

1. 确认当前启动的设备及应用，优先复用用户正在使用的模拟器，保留现有数据。
2. 使用当前可用的桌面控制工具读取应用列表。在本机 Xcode 27 环境中，模拟器窗口由 **Device Hub** 承载，应用标识为 `com.apple.dt.Devices`。不要仅凭旧的 Simulator 进程存在就判断它是有效控制入口。
3. 使用 `cua_repl` 连接 Device Hub：

   ```javascript
   var deviceHub = await cua.getApp('com.apple.dt.Devices');
   ```

4. 读取最新界面后直接点击、输入、返回、滚动或切换筛选。优先使用辅助功能元素；元素不可用时，先获取截图，再按截图坐标操作。每次操作后重新读取界面，使用新的元素索引，不沿用过期索引或旧截图坐标。
5. 用实际页面变化验证成功，不能把工具调用成功等同于功能验证通过。例如：返回企业履历 → 点击职业回顾 → 切换近 5 年 → 核对图表和记录数 → 恢复全部年份。
6. 更新代码后可重新构建、安装并启动应用。启动参数和路由定位仅用于快速到达页面，不能替代点击、保存、返回等交互验收。

`simctl` 可用于设备查询、安装、启动、截图等；不要假设它提供通用的 `io tap` 命令。界面操作遵守当前桌面控制工具的要求。

## 已验证的 Device Hub 故障及恢复办法

以下结论来自 **2026-09-17、本机 Xcode 27.0（27A266a）/ macOS 27.0** 的实际排查，不应直接推广到其他版本。

### 识别症状

- 连接 Device Hub 约 5 秒后返回 `timeoutReached`，后台日志反复出现 `AccessibilitySupport.UIElementError`。
- 系统进程列表存在实际 `DeviceHub` 进程，但 `NSRunningApplication.processIdentifier` 返回 **`-1`**；对比查询 Xcode 能得到正常进程号，桌面控制工具也能读取 Xcode 界面。
- 应用包的 `CFBundleExecutable` 为 `DevicesTrampoline`，实际窗口进程为 `DeviceHub`。本次正常启动及重启后均有上述识别异常；直接启动实际程序后恢复。

可用以下命令查询当前进程，不要复制历史进程号：

```sh
ps -axo pid,comm | rg '/(DeviceHub|DevicesTrampoline|Simulator)$'
xcrun simctl list devices booted
```

如需验证进程识别，可在临时 Swift 文件中执行以下只读诊断：

```swift
import AppKit
for app in NSWorkspace.shared.runningApplications
where app.bundleIdentifier == "com.apple.dt.Devices" {
    print("pid=\(app.processIdentifier), executable=\(app.executableURL?.path ?? "nil")")
}
```

### 恢复步骤

1. 先尝试正常连接。只有同类故障复现时才使用此绕行，不要每次都重启。
2. 核对实际安装位置。本次可用程序路径如下；如果 Xcode 已改名、移动或升级，先重新发现路径，不硬套旧路径。
3. 退出 Device Hub。若退出请求后进程仍存在，可在确认目标进程身份后结束该进程，再启动。仅处理 Device Hub 前端，不关闭 CoreSimulator 服务、不抹除设备数据、不结束其他开发任务。
4. **直接运行实际程序，绕过 `DevicesTrampoline`：**

   ```sh
   /Applications/Xcode.app/Contents/Applications/DeviceHub.app/Contents/MacOS/DeviceHub
   ```

   在代理终端工具中，可让命令保持运行并返回会话 ID；不要随后发送中断或终止该会话。本次尝试短命令中的 `nohup … &` 后进程未保留下来，而直接运行并保留终端会话有效。
5. 重新查询进程信息，确认应用接口返回正常进程号，再通过 `cua.getApp('com.apple.dt.Devices')` 连接。
6. 实际点击验证。本次已成功完成企业履历与职业回顾往返，以及“全部 18 条 → 近 5 年 6 条 → 全部 18 条”的筛选切换，全程没有通过重启悠悠或路由跳转代替点击。

这是已验证的启动绕行办法，不代表已修复 Apple 启动器或确定其内部根因。不要修改应用包的 Info.plist、签名或系统安全权限来强行绕过。

## 其他排查经验

- 本次 Xcode 更新后，旧 Simulator 进程仍在运行，但可执行文件已被安装器移入 `PKInstallSandboxTrash`，原安装路径不存在。它出现在应用列表中，却返回 `Invalid app: com.apple.iphonesimulator`。可用 `lsof -p <已核对的进程号>` 和安装日志确认；不要把这种失效路径误诊为悠悠代码问题。
- 本次刷新 Device Hub 的 Launch Services 注册、重启 Device Hub、重启桌面控制后台服务及重建控制会话，均未单独解决问题。不要没有新证据就反复重复这些操作，或仅凭重启无效就放弃排查。
- 连接故障不构成清空模拟器、重装悠悠或扩大系统权限的理由。若当前工具仍不可用，明确报告失败环节和证据，不把截图检查宣称为完整交互验收。
- 界面验收继续遵循本项目约定：系统默认字号，浅色与深色模式。

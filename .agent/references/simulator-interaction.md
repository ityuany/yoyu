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

## 设备复用：操作前的必做检查

1. 在构建、启动设备或打开模拟器前，先执行 `xcrun simctl list devices booted`，结合 Device Hub 当前窗口确认用户正在使用的设备。
2. 已有可用设备时必须复用，记录其 **UDID**。构建的 `-destination 'platform=iOS Simulator,id=<UDID>'`，以及安装、启动、截图、录屏、外观切换等命令，全部显式指定这个 UDID，不使用含糊的 `booted` 或仅凭设备名称选择。
3. 多台设备已启动时，优先使用用户明确指定或当前操作窗口对应的设备；无法确定时才询问，不能另开一台规避选择。
4. 已有目标设备时，不再执行 `simctl boot`，不新建、克隆设备，也不通过通用的 `open -a Simulator` 意外打开另一套前端。优先连接现有 Device Hub 窗口。
5. 仅在没有已启动设备时，选择现有的兼容设备并启动；若当前设备确实不兼容，先说明原因，在用户同意切换后再启动另一台。构建失败、签名失败、界面连接失败都不是换设备的理由。

## 构建签名：安装前的必过关卡

严格按 **确认设备 → 构建 → 确认产物 → 验签 → 安装 → 启动 → 实际界面验证** 的顺序执行。任一步失败就诊断该步骤，不继续安装旧产物或反复尝试启动。

1. 模拟器构建显式使用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`（本地 ad-hoc 签名）。不得为了让构建通过设置 `CODE_SIGNING_ALLOWED=NO`。这些参数仅用于模拟器，不套用到真机或发布签名。
2. 保存完整构建日志，检查命令退出码及 `BUILD SUCCEEDED`；“编译成功”不等于“产物有签名”或“应用可运行”。
3. 使用与构建一致的项目、scheme、configuration、destination 和 DerivedData 参数读取 `-showBuildSettings`，从 `TARGET_BUILD_DIR` 与 `FULL_PRODUCT_NAME` 确定本次 `.app` 路径，从该产物的 Info.plist 读取 bundle ID。不得凭历史路径安装另一份构建。
4. 对即将安装的实际 `.app` 执行以下检查，**两项均成功后才允许安装**：

   ```sh
   codesign --display --verbose=2 "$SIM_APP_PATH"
   codesign --verify --deep --strict --verbose=2 "$SIM_APP_PATH"
   ```

   `SIM_APP_PATH` 必须来自本次构建。若出现 `code object is not signed at all` 或验证失败，不得继续安装、启动，也不得通过关闭系统安全检查绕过。
5. 验签失败时先核对构建设置和日志中的 CodeSign 步骤。若旧增量产物仍无签名，用任务专用、全新的 DerivedData 目录重新构建，并重新定位产物、验签。不反复复用已证实异常的缓存，不删除用户其他任务的构建目录，不卸载应用或清空模拟器数据。
6. 安装成功后再启动，核对启动结果及实际界面；必要时等待首页数据加载。启动失败要检查日志，不能将空白页或仅收到进程号当作界面验收通过。

**2026-09-20 已验证经验：** 本项目曾出现 `BUILD SUCCEEDED` 但 `.app` 没有签名，模拟器启动报 `No such process`。在原增量目录补充签名参数后仍未恢复；改用全新 DerivedData 目录，显式启用模拟器 ad-hoc 签名，验签通过后在原设备安装、启动成功。这是已验证的恢复方法，不代表所有 `No such process` 都由签名导致；先检查证据，不盲目套用。

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

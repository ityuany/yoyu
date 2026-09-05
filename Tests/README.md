# 「我的」验证

在仓库根目录执行：

```sh
swiftc yoyu/Models/ProfileRules.swift Tests/ProfileRulesTests.swift -o /tmp/yoyu-profile-rules-tests
/tmp/yoyu-profile-rules-tests
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift Tests/ProfilePersistenceTests.swift -o /tmp/yoyu-profile-persistence-tests
/tmp/yoyu-profile-persistence-tests
```

规则测试覆盖股票数量乘单价、市值四舍五入与溢出保护、年化收益率正负值、金额精度与范围、退休年龄、周几名称与日期映射、工作周掩码的读写与幂等、2026 年全部 33 个放假日期及 6 个补班日期、个人覆盖优先级和未知年份降级。持久化测试使用独立临时 SwiftData 数据库，覆盖保存后重新打开、旧股票金额兼容、新股票字段及年化收益率保存、工作周写穿存储掩码、空值、回滚与移除个人调整，不访问业务数据库或 iCloud。

`Weekday` 和 `Workweek` 定义在 `ProfileRules.swift`，因此上面两条命令无需追加文件。新增模型层类型时，要么放进已列出的文件，要么同步更新这两条命令。

当前项目部署目标为 iOS 27，本机需使用 Xcode-beta.app 构建；无需修改全局 xcode-select，单次指定 `DEVELOPER_DIR` 即可。上面两条 swiftc 命令只编译 `yoyu/Models/`，视图层改动需要完整构建才能验证：

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project yoyu.xcodeproj -scheme yoyu \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Debug 构建可传 `--profile` 直接打开「我的」，附加 `--holidays` 查看调休详情，或 `--edit 基本信息`（也支持「企业信息」「工作安排」「当前财富」）查看编辑页。Release 不使用这些参数。

## iCloud 验证条件

应用使用 SwiftData + CloudKit 私有数据库，容器为 `iCloud.devplaceholder.Y3VZXX26.yoyu`。已配置 CloudKit entitlement 和后台 remote-notification。项目原有 bundle ID 仍为占位标识且未指定开发团队；真机签名前，需要在 Xcode 选择开发团队，并为该 App ID 配置对应容器和描述文件。若改容器标识，需同时更新 entitlement 和 SyncMonitor.containerID。

模拟器未登录 iCloud，已验证离线启动；跨设备导入、导出和生产环境 schema 尚未验证。发布前需在开发者账户配置容器、部署 CloudKit schema 到生产环境并用两台登录同一 Apple 账户的设备验证同步。

2026 年官方节假日已内置，可离线查看；新年份需随应用数据更新。在未收录年份，界面明确提示并按常规工作日估算，不沿用 2026 年安排。

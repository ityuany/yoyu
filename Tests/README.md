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

Debug 构建可传 `--profile` 直接打开「我的」，附加 `--detail 基本信息` 查看资料详情（也支持「企业信息」「工作安排」「当前财富」），`--holidays` 查看调休详情，或 `--edit 基本信息`（也支持「企业信息」「工作安排」「当前财富」）查看编辑页。Release 不使用这些参数。

## iCloud 验证条件

应用使用 SwiftData + CloudKit 私有数据库，容器为 `iCloud.devplaceholder.Y3VZXX26.yoyu`。已配置 CloudKit entitlement 和后台 remote-notification。项目原有 bundle ID 仍为占位标识且未指定开发团队；真机签名前，需要在 Xcode 选择开发团队，并为该 App ID 配置对应容器和描述文件。若改容器标识，需同时更新 entitlement 和 SyncMonitor.containerID。

模拟器未登录 iCloud，已验证离线启动；跨设备导入、导出和生产环境 schema 尚未验证。发布前需在开发者账户配置容器、部署 CloudKit schema 到生产环境并用两台登录同一 Apple 账户的设备验证同步。

2026 年官方节假日已内置，可离线查看；新年份需随应用数据更新。在未收录年份，界面明确提示并按常规工作日估算，不沿用 2026 年安排。

## 企业履历验证

新增任职与薪资阶段使用独立 SwiftData 模型，仍进入同一 CloudKit 私有容器。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/Career.swift \
  Tests/CareerTests.swift -o /tmp/yoyu-career-tests
/tmp/yoyu-career-tests
```

测试覆盖旧资料导入及幂等、未知生效月份保留、磁盘重新打开、未来调薪生效边界、同月阶段冲突、任职区间重叠、修改任职区间时保护薪资阶段、CloudKit 重复业务 ID 归并，以及普通职工渐进式延迟退休的年月边界。测试使用临时数据库，不访问用户资料或 iCloud。

手动验证：基本信息 → 当前企业 → 查看任职详情；企业履历 → 添加/编辑任职；薪资阶段 → 新增/修改 → 保存或取消。工作安排包含工作日、上下班时间及每段任职独立的“遵循法定节假日及调休”开关，新旧任职默认开启。离职后无当前任职时，快捷入口引导管理企业履历。

旧资料保留在原模型中作为兼容数据，用户界面的任职、薪资、工作安排统一使用新模型；导入标记与新记录在同一次保存中提交。迁移采用稳定业务 ID，跨设备同源导入在读取时归并。出现多段未结束任职时不任意选择当前企业，显示待处理提示。任职只填写年月，入职按月初、离职按月末计算；启动时将既有任职日期直接归整到月份，同一月份不允许录入两家企业。记录已离职即归入历史任职。

法定退休年月按中国大陆普通职工规则计算，女性需选择原法定退休年龄 50 岁或 55 岁类别；不覆盖特殊工种等提前退休情形，也不代表养老金领取资格。规则来源：https://www.npc.gov.cn/npc/c2/c30834/202409/t20240914_439634.html

新模型的真实跨设备同步仍需两台登录同一 Apple 账户的设备验证；本地测试不代表已完成 CloudKit 端到端验证。

任职概览卡片直接展示月薪、按整月任职边界估算的在职天数，以及税前累计工资估算。累计按各阶段月薪和当月自然日折算，不含年终奖；缺少月份、薪资覆盖或同月阶段冲突时显示待补全。薪资阶段从所选月份的 1 日生效，发薪日独立决定现金到账日期。CareerTests 另覆盖闰年整月、统计截止日、跨月舍入与缺失资料。

企业工作安排按同一任职区间统计应工作天数及平均日薪（累计税前工资除以应工作天数，不含年终奖）。节假日复用当前内置的 2026 年安排；其他年份明确提示按周安排估算。测试覆盖默认开启、开关持久化、放假与补班、关闭后的周安排、零工作日和缺失薪资/年份。

## 今日收入

「今日」复用当前任职的薪资阶段、每周工作日及节假日开关，按班次归属日的月薪除以该月应工作日，再按整段上下班时长累计；不扣午休、不含奖金。月中调薪逐日取当日薪资，跨夜班次在零点后延续并归入开班日。收入为按时间派生的估算，无新增持久化流水。月内薪资缺口时本月总额显示待补全；未收录年份显示节假日估算说明。此口径用于今日进度，不是法定工资结算公式，也与履历页按自然日估算总工资的用途不同。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/Career.swift \
  yoyu/Models/TodayIncome.swift Tests/TodayIncomeTests.swift -o /tmp/yoyu-today-tests
/tmp/yoyu-today-tests
```

测试覆盖每秒增长、上下班边界、下班后封顶、休息日、整月总额、月中调薪、缺失生效日期及月内薪资、零工作日、节假日补班、未知年份与跨夜班次。页面可见且应用活跃时每秒刷新，后台不依赖定时累加，返回后直接从当前时间恢复。

今日主题按收入快照的班次日期与实际工作状态选择；周末上班仍显示工作主题，工作日休息显示休息主题，不遵循节假日安排时不标为调休补班。节日名称仅作辅助标识，未知年份不推断节日。

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/TodayMood.swift Tests/TodayMoodTests.swift -o /tmp/yoyu-today-mood-tests
/tmp/yoyu-today-mood-tests
```

Debug 可传 `--today-at 2026-09-11T12:00:00+08:00` 预览工作中状态，页面明确显示预览标记；时间按秒前进，不修改系统时间和业务资料。正常启动不传参数，Release 不使用此参数。

## 股票与归属计划

每只股票使用 StockHolding（SwiftData + 同一 CloudKit 私有容器）保存名称、手动股价及更新时间、币种、人民币折算汇率、基准日持股和归属计划。计划以 Codable Data 保存在所属股票记录内，编辑草稿只在保存时整体写入。基准日后的计划在指定日期（上海时区当天零点）按日期推导已归属数量，读取不会写回或重复增加。当前财富仅汇总已归属价值；未归属参考价值独立显示。支持 CNY/HKD/USD，外币手动汇率最多四位小数。

旧 UserProfile 股票字段保留；通过“补全原有股票与归属信息”显式转换后不再重复汇总。旧数量作为基准已归属持股预填，只有金额的记录要求补充股数和价格，不反推数量。新股票采用稳定迁移 ID，读取归并 CloudKit 同源重复记录。持股变化、实际延期、取消计划均需用户手动修正；不处理买卖流水、限售、税费或自动行情。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/EquityGrant.swift yoyu/Models/StockHolding.swift \
  Tests/StockTests.swift -o /tmp/yoyu-stock-tests
/tmp/yoyu-stock-tests
```

测试覆盖归属日零点边界、重复读取幂等、三项价值、财富仅计已归属、汇率、旧值去重、金额上限、损坏计划、回滚及重新打开数据库。真实 CloudKit 跨设备同步仍需已登录同一账户的设备验证。


## 按企业管理股票授予

企业详情新增股票激励入口，财富页新增操作先选择当前或历史任职。StockHolding 新增 employmentID、grantData 与 disposalData，仍存于 SwiftData + CloudKit 私有库。每份 grantData 存储独立授予批次、总量及各期计划；同企业价格共用。未安排数量计入未归属，取消的期数保留记录但不再计值。减少持仓记录仅扣除已归属持股，不改变授予历史。旧 vestingData 自动作为“原有归属计划”读取，首次编辑批次后写入新格式，保留原始数据。旧股票不按名字猜公司，需要明确关联。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/EquityGrant.swift \
  yoyu/Models/StockHolding.swift Tests/EquityTests.swift -o /tmp/yoyu-equity-tests
/tmp/yoyu-equity-tests
```

覆盖授予与归属上限、未安排数量、到期边界、取消、持仓扣除不改历史、月末周期生成及旧记录兼容。跨设备编辑同一公司的计划采用整份公司记录同步，真实多设备同步仍待验证。

新增授予仅填写公司、批次和归属计划，无需股价。公司总览统一设置股价；priceIsConfigured 区分未设置与明确的零价格，既有记录默认保留已配置状态。未设置时股数可计算，金额和财富汇总保持待补全。EquityTests 覆盖无股价保存、股数、零价格、后续计值与状态持久化。

## 补偿资产

财富页在「资产明细」中展示「补偿」，与现金、股票、理财并列，默认 N+1：N × 补偿月薪基数 + 额外一个月工资。N 根据当前企业入职日期按上海自然日计算，整年后剩余不足半年计 0.5、满半年计 1。工资暂按当前税前月薪，可独立调整补偿基数、N 和额外一个月工资，详情页只读，右上角「编辑」进入统一编辑页选择 N、N+1、2N，不再提供自定义金额入口；编辑实时预览，保存才生效，取消保留原方案。2N 按 N × 补偿月薪基数 × 2 计算，不叠加额外一个月工资，并在乘 2 后统一按分舍入。缺少任职、工龄或工资时不推断为零；历史自定义金额保留读取兼容；改选三种标准方案后使用工龄与工资测算。

补偿直接计入财富页总资产与四类资产占比，详情不再展示资产对比。未知类别遵循现有已知资产汇总口径，未填写项暂不计入并提示；股票价格缺失仍阻止总额显示。StockTests 覆盖补偿计入合计、仅有补偿、零值、缺失值、缺失股价与溢出。补偿方案以 Codable Data 存入 Employment.severanceData，继续使用 SwiftData + CloudKit 私有数据库；编辑取消不写入，保存失败回滚。旧任职记录自动采用默认 N+1，损坏的方案数据提示重新设置。工龄和当前资产随当天日期重新推导，换企业后采用新任职自己的方案。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/Career.swift \
  yoyu/Models/Severance.swift Tests/SeveranceTests.swift -o /tmp/yoyu-severance-tests
/tmp/yoyu-severance-tests
```

验证包含工龄半年与整年边界、N/N+1/2N/自定义金额、独立工资基数、未知资料与零金额、金额范围与合计溢出、临时 SwiftData 数据库重开及回滚。Debug 可传 `--wealth` 打开财富页；界面验收使用默认字号，覆盖浅色与深色。

安装到模拟器运行时使用以下构建方式，保留 CloudKit 所需的模拟器权限信息。上面的 `CODE_SIGNING_ALLOWED=NO` 命令仅用于编译检查；其产物直接安装运行会在 CloudKit 初始化时退出。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project yoyu.xcodeproj -scheme yoyu \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath /tmp/yoyu-severance-build -jobs 2 \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

2026-09-15 在 iPhone 17 Pro / iOS 27.0 模拟器完成默认字号浅色、深色验收：财富页、补偿明细及编辑页显示正常；月薪 40,000 元、N 为 6.5 时，N 方案为 260,000 元、N+1 为 300,000 元；修改工资后取消保留原方案，默认 N+1 可保存。

此功能为可调整的税前情景测算，未自动处理当地工资封顶、最低工资、2008 年前工龄及税费。法定经济补偿的工资口径通常为前 12 个月应得平均工资，代通知金为上月工资；N+1 不是所有裁员的通用法定结论。规则参考：[劳动合同法](https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fl/202011/t20201102_394622_wap.html)、[劳动合同法实施条例](https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcfg/fg/202011/t20201103_394939_wap.html)。真实 CloudKit 跨设备同步仍需已登录同一账户的设备验证。

补偿并入资产明细后的验收：iPhone 17 Pro / iOS 27.0 默认字号下，财富页、补偿详情和编辑页均通过浅色与深色检查。N / N+1 / 2N 分别显示 260,000 / 300,000 / 520,000 元；2N 下总资产 1,429,640 元、补偿占比 36.4%，返回后同步更新。验收后恢复原 N+1 与浅色模式，总资产 1,209,640 元、补偿占比 24.8%。完整模拟器构建、SeveranceTests 和 StockTests 均通过。

交互去重验收：补偿详情移除直接切换控件和底部调整按钮，仅右上角「编辑」进入草稿表单。iPhone 17 Pro / iOS 27.0 默认字号浅色、深色均通过；N 切到 2N 后取消仍保留 260,000 元，保存后为 520,000 元，总资产同步为 1,429,640 元、补偿占比 36.4%。验收完成恢复本次操作前的 N 方案与浅色模式。完整模拟器构建通过。

股票页面布局验收：公司区域紧随人民币参考价值，以同一分组中的普通导航列表展示，每行仅公司名；未来归属时间线排在公司列表后。公司详情保留股数、已归属和未归属价值，并展示总参考价值；未关联股票在详情提供关联任职入口。iPhone 17 Pro / iOS 27.0 默认字号下，列表与公司详情均完成浅色、深色验收，导航往返正常，完整模拟器构建通过。

归属列表默认完整展开：移除前四次限制、“查看全部归属”入口和独立全部计划页，按年份直接展示所有归属日期，单日来源详情保留。iPhone 17 Pro / iOS 27.0 默认字号浅色与深色已核对 2027–2030 年全部 7 次计划，最后一次归属详情可正常打开，完整模拟器构建通过。

## 理财收益测算

入口：财富 → 理财 → 收益测算。预设 3 个月、6 个月、1 年、3 年、5 年、8 年、10 年及自定义，默认 1 年、单利。自定义支持 1–1200 个月或 1–100 年。自动带入当前金额与年化收益率，页面内修改仅用于本次测算，不写回资产配置或增加持久化数据。

单利按初始本金和月份比例计算；复利每满一年复投，剩余月份按年收益率 × 月数 / 12 计算，不在中间年份舍入。结果统一舍入到分。负收益最低归零；金额超限、未填写和输入无效时提示，不显示误导性零值。

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swiftc \
  yoyu/Models/ProfileRules.swift yoyu/Models/InvestmentProjection.swift \
  Tests/InvestmentProjectionTests.swift -o /tmp/yoyu-investment-tests
/tmp/yoyu-investment-tests
```

覆盖短期、整年、跨年零头、单利/复利差异、负收益、亏损本金封底、零本金/零收益率、四舍五入、期限/金额/利率边界及缺失数据。

## 删除企业履历

任职详情底部的「删除任职记录」通过一次系统确认弹窗执行。提示按实际关联数据显示薪资条数、补偿设置及股票记录和授予批次数，并提醒仅离职应填写离职日期。删除该业务 ID 的全部任职副本及薪资阶段，随任职保存的工作安排、补偿设置一并移除；关联股票记录及其内嵌的持股、授予、归属计划和持仓调整一并删除。一次 SwiftData 保存提交，失败回滚，成功返回上一级。旧资料的迁移标记不清除。

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift \
  yoyu/Models/Career.swift yoyu/Models/EquityGrant.swift yoyu/Models/StockHolding.swift \
  yoyu/Models/EmploymentDeletion.swift Tests/EmploymentDeletionTests.swift \
  -o /tmp/yoyu-employment-deletion-tests
/tmp/yoyu-employment-deletion-tests
```

测试使用独立临时数据库，覆盖重复业务 ID 清理、关联薪资删除、其他企业保留、关联股票及重复副本删除、模拟保存失败后的完整回滚、迁移标记保留、重复调用和持久化重开。界面待验收：默认字号浅色和深色模式下的删除入口、取消确认、确认后返回与统计刷新。真实 CloudKit 跨设备删除同步尚未验证。

薪资阶段删除：在已有薪资记录的编辑页底部点击「删除薪资阶段」，二次确认后删除同企业、同业务 ID 的全部副本；不保存编辑草稿，不删除企业或其他阶段。失败回滚，成功关闭编辑页。CareerTests 覆盖重复副本清理、其他企业隔离、删除后回退到前一阶段、删除最后阶段及持久化读取。编译和规则测试已通过，删除弹窗交互及浅深色外观尚待验收。

## 职业回顾

企业履历顶部通过普通导航行进入职业回顾。累计任职采用自然日区间并集，含入离职当天，不重复累计重叠经历。薪资按已生效且金额有效的阶段绘制，缺失金额、同日冲突与任职空档断开；未来调薪不展示。最近月薪明确标为「最近已录入月薪」，不推断未知工资。时间轴支持时间顺序与任职时长排序。全部信息从 SwiftData 现有记录派生，不添加持久化业务数据。

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/UserProfile.swift yoyu/Models/Career.swift \
  yoyu/Models/CareerReview.swift Tests/CareerReviewTests.swift -o /tmp/yoyu-career-review-tests
/tmp/yoyu-career-review-tests
```

测试覆盖任职重叠去重、空档、调薪、重复业务 ID、同日冲突、缺失金额、零工资、未来日期与空数据。Debug 参数 `--profile --career-review` 直接进入回顾；附加 `--review-tenure` 定位任职时间轴。

2026-09-17：完整构建与 CareerReviewTests 通过；iPhone 17 Pro Max / iOS 27 默认字号，使用现有 10 段任职、18 条薪资记录核对了入口、概览、薪资图及任职时间轴的浅色和深色截图。已恢复浅色。模拟器界面控制工具连接失败，点击选点、排序切换及详情跳转尚未完成实际手势验收。

## 股票管理入口与旧资料核对

股票的维护入口统一为「财富 → 股票」。企业履历只展示已归属/未归属股数，并通过共享导航切换到财富中的对应股票详情；没有记录时进入股票列表。旧个人财富详情也跳转到同一入口。

仅存在未处理旧字段时显示一次性核对：已包含的持股由用户核对后停止单独计入，原字段保留；另一份持股须选择尚无股票记录的公司后迁入。部分已录入时先在现有公司补全持仓/计划，再确认核对，不自动叠加。新旧记录同时存在且关系未确认时，股票与财富汇总暂不显示金额。已生成稳定迁移 ID 的记录在同步标记尚未到达时仍不会重复计入。

StockTests 覆盖待核对时阻止汇总、完成核对后只计入公司记录、保留旧值、迁移 ID 的同步先后去重，以及既有回滚与持久化用例。界面检查不替用户确认真实股票资料的归属关系。

本轮在 iPhone 17 Pro Max / iOS 27 默认字号检查了公司摘要与股票空态的浅色、深色显示，并实际点击验证「公司履历 → 前往财富管理股票」切换到财富股票页，切回「我的」保留公司页面。当前模拟器无股票持仓与待迁移旧记录，因此有持仓详情跳转和迁移表单保存尚未进行界面端到端验收；金额重叠逻辑通过 StockTests 验证。未修改用户持仓数据。

## 负债与还款计划

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/Liability.swift \
  yoyu/Services/LiabilityStore.swift Tests/LiabilityTests.swift -o /tmp/yoyu-liability-tests
/tmp/yoyu-liability-tests
```

覆盖组合贷、等额本息／等额本金、零及极小利率、月末日期与尾期舍入、账单包含分期的去重、分期首末期费用、确认还款、金额上限、草稿隔离、旧历史字段兼容和独立数据库重开。测试不访问真实账本或 iCloud。

房贷以最近已确认本金及剩余期数为起点，按当前利率生成标准月度预测；不模拟银行按日计息、未来利率调整或提前还款政策。确认还款只减少本金；编辑直接更新当前信息，不再生成历史快照。信用卡总欠款包含分期未还本金及已入账费用，本期账单覆盖截至其还款日的计划，因此还款合计不再重复叠加对应分期。未来分期费用只计入还款计划。部分还款、提前还款及调息通过余额校准录入银行结果，不自动扣减现金。预计计划不视为已经扣款。

财富 → 负债 → 查看组合贷与分期示例，使用独立内存容器，不写入实际 SwiftData 或 CloudKit 账本。Debug 可用 `--wealth --debt-example` 定位示例，附加 `--debt-plan`、`--debt-card`、`--debt-mortgage` 检查具体页面；这些定位参数不能替代实际点击验收。

新记录使用现有 SwiftData + CloudKit 私有数据库；本地测试不代表完成真实跨设备同步，新增模型的生产 CloudKit schema 仍需按发布流程部署验证。

信用卡固定分期支持分期总额、总期数、当前待还第几期和预计下次还款日，以及年利率（等额本息）或每期手续费率（按原始金额）；每月还款日在账户统一设置。开始日期由下一期待还的期数和日期在内部反推，不要求用户填写。输入第 N 期待还表示前 N−1 期已还，剩余金额包含第 N 期。下一次日期默认取最近的信用卡还款日并可修改。新分期默认按日期推算，严格早于今天的还款日视为预计已还，还款日当天仍待还；月末自动夹取，次月恢复指定日。用户可关闭自动推算，手动维护实际已还期数。旧固定分期继续按手动进度读取，编辑时可开启自动模式。剩余本金和剩余应还（含息）分别计算。页面通过现有 CareerClock 在前台恢复和每分钟更新估算。新账户不录入普通消费和账单余额。原版本账单记录仍按原方式读取和编辑，避免丢失历史数据。测试覆盖免息、年利率、手续费、已还期数、结清、非法输入和持久化往返；模拟器点击控制超时时仅检查浅色／深色截图，不视为完成交互验收。

## 本设备 iCloud 同步开关

```sh
swiftc yoyu/Services/SyncPreference.swift Tests/SyncPreferenceTests.swift -o /tmp/yoyu-sync-preference-tests
/tmp/yoyu-sync-preference-tests
swiftc -parse-as-library Tests/SyncStorageTests.swift -o /tmp/yoyu-sync-storage-tests
/tmp/yoyu-sync-storage-tests
```

覆盖本地偏好持久化、账户确认标识、两种配置的默认数据库路径一致，以及独立临时数据库的离线新增、修改、删除和重新打开。测试不访问用户业务数据库或云端，不能替代真实跨设备同步测试。

开关在下一次进程启动生效。首次没有已确认的账户标识时（包含旧版本升级），先使用原有本地数据库；在「我的 → iCloud 同步」确认当前账户后重新启动，才配置 CloudKit。未登录、账户查询失败或检测到不同账户时，启动时保持本地模式。运行中系统切换账户无法通过 SwiftData 公共接口原子停止自动同步，目前仅提示重启，不宣称完整账户隔离；真实账户切换、重新启用后的双设备合并仍待真机验收。

Debug 启动参数 `--profile --sync` 可定位同步页面，仅用于截图辅助。手动验收应覆盖开关取消/确认、反向切换取消待生效设置、重启后的状态和原数据保留，以及默认字号的浅色/深色模式。

## 日常开支计划

财富首页在负债明细后展示最多三项日常开支，支持添加、查看全部、详情、编辑与删除。首页不再单列每月已知还款；还款计划保留在房贷、信用卡的浏览页面。日常开支独立于负债，不计入当前资产、不扣现金，也不生成消费流水。预测页暂未接入。

每项记录包含用途、每期金额、固定／预估标记、每月／季度／年度周期、起止日期及备注。月内陆续发生按自然日折算，首尾日期均包含；指定日期扣款从开始月份锚定周期，只计生效范围内的扣款日期，短月夹取月末，次月恢复指定日。季度及年度金额在扣款月份整笔计入。所有日期采用上海时区。详情预览从当前月起的 12 个月，包含本月整月。编辑当前计划会修改该计划全部预览，尚不支持同一用途内的分阶段调价。

RecurringExpense 使用 SwiftData + 现有 CloudKit 私有数据库；Codable 草稿保存前不修改记录，保存失败回滚。查看日常开支示例使用独立内存容器；示例中的修改不写入用户业务数据库或云端，离开后重新进入会恢复示例。

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/RecurringExpense.swift \
  yoyu/Services/ExpenseStore.swift Tests/ExpenseTests.swift -o /tmp/yoyu-expense-tests
/tmp/yoyu-expense-tests
```

测试覆盖首尾日、月中起止折算、闰日、月末扣款、季度与年度锚点、无扣款月份、无效输入、草稿隔离、回滚、重复业务 ID 汇总与删除、损坏记录阻止汇总、独立数据库重开。真实 CloudKit 跨设备同步和生产 schema 部署仍需发布前验证。

2026-09-19：iPhone 17 Pro Max / iOS 27 默认字号下，检查了财富入口、示例列表、详情和新增／编辑表单的浅色、深色显示。实际点击验证新增保存（300 元月预算从 9 月 19 日起，当月 120 元）、修改取消保留原金额、修改保存更新详情与合计，以及租金在 11 月结束后 12 月不再计入。示例详情显式沿用独立内存容器，未写入真实业务记录。规则测试与完整模拟器构建通过；删除通过独立数据库测试，删除弹窗尚未手势验收。

### 预计支出统一汇总（修正）

财富首页的第四组改为「预计支出」，直接引用已有房贷／信用卡计划，并与日常开支汇总。查看全部进入按月切换的预计支出页，负债行返回原账户详情，不复制负债或创建另一份还款记录。已有日常开支的独立管理及内存示例继续保留。金额含本金与利息／费用，按当前已知计划计算；已确认并移出计划的历史还款不补记。自动分期以所选月份首日求值，避免同一个月内过扣款日后整月计划金额减少；未知账单提示只含已知部分，损坏记录阻止显示完整合计。

```sh
swiftc yoyu/Models/ProfileRules.swift yoyu/Models/Liability.swift \
  yoyu/Models/RecurringExpense.swift yoyu/Models/ExpectedExpense.swift \
  Tests/ExpectedExpenseTests.swift -o /tmp/yoyu-expected-expense-tests
/tmp/yoyu-expected-expense-tests
```

测试覆盖仅房贷无手动开支、混合汇总、重复账户去重、账单覆盖分期不重复计入、缺失账单、损坏记录及计划结束。模拟器实际点击验证已有房贷自动展示、进入原负债详情及月份切换：当前账户剩余计划从 2026 年 10 月开始，9 月为零、10 月为 6,184.60 元；未修改原账户。完整构建与汇总规则测试通过。

### 扣款日期输入统一

指定日期扣款的每月／每季度／每年计划，统一输入完整的「首次扣款日期」，自动取其日作为扣款日；季度每隔三个月，年度沿用首次月份。表单直接显示重复规则及最多三次扣款预览，结束日期之后的预览不显示，范围内没有扣款时明确提示。月内陆续发生仍使用开始日期。旧记录保留原开始日和扣款日，编辑打开时展示原规则推导的首次扣款日；未改日期直接保存不改变旧计划，只有用户修改日期才重新确定日期与扣款日。

ExpenseTests 新增每月 31 日、季度跨年、年度月份、闰日、旧记录首月扣款已错过及结束日期截断预览测试。构建与规则测试通过；模拟器实际切换每年、每季度、每月，分别核对 9/19 年度、9/19→12/19→3/19 季度及 9/19→10/19→11/19 月度预览。

## 房贷详情 UI 验收

`yoyuUITests/MortgageInterestUITests.swift` 使用 XCTest + XCUIAutomation，点击内存示例账本中的组合贷，检查顶部及两类贷款的预计利息、分项合计、旧文案移除和返回重入，并验证右上角编辑、取消不保存及修改名称后保存。Debug 参数 `--mortgage-ui-test` 直接进入独立示例入口，不打开真实数据容器；Release 不包含此入口。

按 `.agent/references/simulator-interaction.md` 复用当前设备，先 `build-for-testing` 并检查主应用、测试 runner 和 bundle 的签名，再 `test-without-building`。使用同一明确 UDID，并传入 `-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:yoyuUITests/MortgageInterestUITests`。默认字号下依次检查浅色、深色，查看结果附件中的页面截图；测试完成后恢复原外观。

## 临时财务 Markdown 导出

入口：我的 → 临时工具 → 导出财务 Markdown。打开时读取一份本机快照，预览、复制和分享使用同一文本；重新打开刷新。不写入业务记录，不自动发送给 AI。导出现金、理财参数、股票与完整归属/调减计划、收入履历、补偿情景、负债参数、日常开支及未来 12 个完整月的已知支出。未填写与异常数据明确标注，未归属股票与补偿不计入已记录资产，无负债记录时不推断净值。

```sh
swiftc yoyu/Models/{ProfileRules,UserProfile,Career,EquityGrant,StockHolding,Severance,Liability,RecurringExpense,ExpectedExpense,FinancialMarkdown}.swift Tests/FinancialMarkdownTests.swift -o /tmp/yoyu-financial-markdown-tests
/tmp/yoyu-financial-markdown-tests
```

覆盖去重、资产/净值口径、未归属单列、支出预测、空数据、损坏负债、未设股价及名称中的 Markdown 换行。`FinancialExportUITests` 通过 `--financial-export-ui-test` 进入独立内存容器，检查入口、生成内容、复制反馈、关闭及重新打开。

2026-09-22：FinancialMarkdownTests、完整模拟器构建及产物验签通过；复用 iPhone 17 Pro Max / iOS 27，默认字号下浅色和深色各执行 1 项 UI 测试，均通过。已查看两种外观截图，并核对模拟器剪贴板包含完整示例 Markdown。未向外部 AI 或分享目标发送财务数据。测试结束恢复原深色外观及真实“我的”页面。

### 工作中断期间暂停日常开支

日常开支新增「工作中断期间暂停」，默认关闭，与指定结束日期独立。开启后，在预测传入的失业／gap 区间内暂停，区间起止日均包含；未传入区间仍按原计划计算。月内陆续发生按有效天数折算；指定日期扣款按扣款日是否落入区间决定是否跳过，恢复后不补扣、不改变周期，原结束日期仍生效。多个重叠区间不重复扣除，无结束日表示持续中断。负债还款不受影响。

设置保存在现有 SwiftData + CloudKit 私有数据中的计划 JSON，旧 JSON 缺失字段按关闭处理，无需更改数据库结构。详情和财务 Markdown 导出包含此设置。`ExpectedExpenseRules.total` 与 `ExpenseRules` 保留 `workBreaks` 情景参数，不依据缺失的职业履历推断失业。

`ExpenseTests` 覆盖旧 JSON、保存后重开、重叠区间、按天折算、单日暂停、无限期暂停、周期恢复与结束日期；`ExpenseWorkBreakUITests` 使用 `--expense-ui-test` 独立内存示例，检查取消不保存、保存与重新进入，按浅色和深色运行。

### 旧预测模块移除

旧预测页面、原型、专用情景计算与测试已移除，底部不再显示旧预测入口。财富中的预计支出、还款与理财测算，以及支出对工作中断区间的支持继续保留。新版本需求见根目录「预测模块需求讨论.md」。

## 生存时长预测第一版

```sh
swiftc yoyu/Models/{ProfileRules,UserProfile,Career,EquityGrant,StockHolding,Severance,Liability,RecurringExpense,ExpectedExpense,Runway}.swift Tests/RunwayTests.swift -o /tmp/yoyu-runway-tests
/tmp/yoyu-runway-tests
```

覆盖资产使用顺序、资金不足日期、失业前资金不足、失业日补偿、重新就业后赎回、必要资料缺失、还款去重、单利与复利赎回及情景持久化。`RunwayUITests` 使用独立内存示例验证取消、保存、情景切换、图表全屏及收支明细；按项目验收约定在同一已启动设备上分别执行浅色与深色测试。模拟器构建须使用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`，安装前验证实际产物签名。Debug 启动参数 `--runway-demo` 可直接查看示例，`--forecast` 打开个人预测页。

### 预测算法性能与结果一致性

执行 `bash Tests/run-runway-performance.sh`：顺序运行计算回归、5,784 个支出前缀及 40 组完整情景的新旧结果对照，再执行预热后各 5 次的交替计时。测试不访问用户资料。旧引擎冻结在 `Tests/Fixtures/RunwayBaselineEngine.swift`，仅用于测试，不进入 App。测试环境、全部测量值和适用范围见 [性能报告](RunwayPerformanceReport.md)。

预测页面现在将值类型快照交给后台计算，并复用最多 3 份会话内结果。`RunwaySessionTests` 验证稳定索引、资料版本变化、缓存容量、任务取消与后续正常计算；已纳入性能验证脚本。UI 用例核对修改后的结果、切换回来后的结果及图表范围保留。

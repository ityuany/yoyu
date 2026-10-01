# 悠悠

使用 SwiftUI 构建的 iOS 应用。用户业务数据统一采用 SwiftData 本地存储和 CloudKit 私有数据库同步。

## 代码目录

| 目录 | 职责 |
| --- | --- |
| `yoyu/App` | 应用入口、底部菜单、导航、共享时钟和方向约束 |
| `yoyu/Models` | SwiftData 实体，每个实体独立文件；字段附中文说明 |
| `yoyu/Domain` | 业务规则、计算输入与结果、日期与金额规则、导出内容 |
| `yoyu/Persistence` | 数据库启动、保存与回滚、删除、格式转换、旧资料迁移和同步 |
| `yoyu/Features` | 页面、编辑器、功能内组件、编辑草稿和计算状态 |
| `yoyu/Design` | 共用视觉样式、输入控件和错误反馈 |
| `yoyu/Development` | 示例资料页面及 UI 测试宿主，保留各文件原有编译条件 |
| `Tests` | 规则与持久化测试、测试数据和统一执行脚本 |
| `yoyuUITests` | XCTest 界面交互测试 |
| `design` | 页面设计参考 |

`Models/AppModelSchema.swift` 是持久化结构总览。`Models` 按 Profile、Career、Contributions、Stocks、Liabilities、Expenses、Forecast 分组，包含全部数据库字段和关系。目录及文件拆分保持实体类型名称、字段、关系和数据库位置一致。

`Features/Today`、`Wealth`、`Forecast`、`Profile` 对应四个主菜单入口；Career、Stocks、Liabilities、Expenses、Investments 承载独立业务页面，可由多个菜单进入。页面较多的功能使用 `Editors`、`Components`、`State` 子目录，按实际职责归类。

## 验证

```sh
# 全部规则、持久化及旧数据库升级测试。
Tests/run-tests.sh
# 选择相关测试。
Tests/run-tests.sh Career Equity Expense
# 预测结果对照与性能验证。
Tests/run-runway-performance.sh
```

详细测试说明见 [Tests/README.md](Tests/README.md)。应用和 UI 测试通过 `yoyu.xcodeproj` 中的 `yoyu` scheme 构建和运行。项目约束见 [AGENTS.md](AGENTS.md)。

开始任务前，必须阅读并遵循以下引用文件中的约束。

## 沟通礼仪

参见 [沟通礼仪](.agent/references/communication.md)。

## 程序架构约束

参见 [程序架构约束](.agent/references/architecture.md)。

## 导航与底部菜单

后续尽可能遵循“浏览时保留、编辑时覆盖、全屏查看时按需隐藏”的原则。具体要求参见 [导航设计原则](.agent/references/navigation.md)。

## 图表全屏查看

所有图表右上角统一提供放大入口，点击后以全屏层横向查看；保留当前时间范围和筛选，关闭后回到原页面并保留状态。具体要求参见 [图表查看约定](.agent/references/charts.md)。

## 界面验收范围

界面验收仅使用系统默认字号，覆盖 **浅色模式（Light Mode）** 和 **深色模式（Dark Mode）**；不验收放大字号，包括 **Dynamic Type 放大字号** 和 **更大辅助功能字体（Larger Accessibility Text Sizes）**。

具体要求参见 [界面验收约定](.agent/references/ui-validation.md)。

## 模拟器交互与故障排查

操作模拟器时，必须遵循 [模拟器交互流程](.agent/references/simulator-interaction.md)：先识别并复用用户已启动的设备，全程使用同一 UDID；构建成功后必须验证实际安装产物的签名，通过后才能安装和启动。不得因构建或连接失败擅自启动第二台模拟器。该文件还包含 Device Hub 连接与故障恢复步骤。

## 杂项

参见 [杂项](.agent/references/miscellaneous.md)。

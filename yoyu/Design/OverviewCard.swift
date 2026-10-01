import SwiftUI

/// 概览卡片的标题、内容、可选操作三区布局。导航由外层 NavigationLink 负责，
/// 带按钮或图表的卡片可以独立使用，不隐式添加整卡点击行为。
///
/// 分区从上到下依次排列：header 放标题及尾部入口，content 放概览数据，
/// actions 放底部按钮等操作。没有底部操作时，使用不含 actions 的初始化方法。
/// 背景由调用方提供，以便复用普通卡片、渐变或插画样式，并适配浅色与深色模式。
struct OverviewCard<Header: View, Content: View, Actions: View, Background: View>: View {
    private let header: Header
    private let content: Content
    private let actions: Actions?
    private let background: Background
    private let padding: CGFloat
    private let spacing: CGFloat
    private let cornerRadius: CGFloat

    /// 创建包含底部操作区的卡片。
    ///
    /// - Parameters:
    ///   - padding: 三个分区共用的内边距。
    ///   - spacing: 相邻分区之间的间距。
    ///   - cornerRadius: 点击区域的圆角，不负责裁剪背景；调用方应让背景圆角与之保持一致。
    ///   - header: 标题区，建议使用 OverviewCardHeader 统一标题与尾部入口的对齐。
    ///   - content: 内容区；金额格式、换行和业务状态由调用方处理。
    ///   - actions: 底部操作区，与标题区右侧入口分别布局。
    ///   - background: 卡片背景；填充、描边、阴影和视觉圆角均由调用方定义。
    init(
        padding: CGFloat = 20,
        spacing: CGFloat = 12,
        cornerRadius: CGFloat = 22,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder background: () -> Background
    ) {
        self.padding = padding
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.header = header()
        self.content = content()
        self.actions = actions()
        self.background = background()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
            content
            if let actions { actions }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension OverviewCard where Actions == EmptyView {
    /// 无操作区时，不渲染占位视图或额外间距。
    /// 其余参数与包含 actions 的初始化方法一致。
    init(
        padding: CGFloat = 20,
        spacing: CGFloat = 12,
        cornerRadius: CGFloat = 22,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder background: () -> Background
    ) {
        self.padding = padding
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.header = header()
        self.content = content()
        self.actions = nil
        self.background = background()
    }
}

/// 标题区左右两侧始终垂直居中；右侧可用详情箭头或独立按钮。
/// title 可以组合文字、图标和状态标签；居中对齐以整个 title 区域为基准。
struct OverviewCardHeader<Title: View, Trailing: View>: View {
    private let title: Title
    private let trailing: Trailing
    private let icon: String?
    private let iconColor: Color

    /// 自定义标题区尾部内容，例如图表放大按钮。
    /// 尾部按钮的点击范围与无障碍名称由调用方提供。
    /// icon 为可选 SF Symbol 名称；省略时不保留图标占位。
    /// 图标与标题共用 headline 字号，不提供页面级固定尺寸覆盖。
    init(
        icon: String? = nil,
        iconColor: Color = .accentColor,
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)
                }
                title
            }
            .font(.headline)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension OverviewCardHeader where Trailing == OverviewCardDisclosure {
    /// 显示可选的详情箭头；showsDisclosure 只控制外观，不启用导航。
    /// 整卡进入详情时，由外层 NavigationLink 包裹 OverviewCard，并将此参数设为 true。
    init(
        icon: String? = nil,
        iconColor: Color = .accentColor,
        showsDisclosure: Bool = false,
        @ViewBuilder title: () -> Title
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title()
        self.trailing = OverviewCardDisclosure(isVisible: showsDisclosure)
    }
}

/// 箭头仅提示整卡可进入详情，不单独创建点击目标。
/// 无障碍导航语义由外层 NavigationLink 提供，因此隐藏装饰性箭头，避免重复朗读。
struct OverviewCardDisclosure: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
        }
    }
}

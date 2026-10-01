import Foundation

/// 星期枚举与 `Calendar.component(.weekday:)` 保持一致：周日为 1，周六为 7。
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// 业务记录标识，跨设备同步时用于识别同一记录。
    var id: Int { rawValue }

    /// 名称。
    var name: String {
        switch self {
        case .sunday: "周日"
        case .monday: "周一"
        case .tuesday: "周二"
        case .wednesday: "周三"
        case .thursday: "周四"
        case .friday: "周五"
        case .saturday: "周六"
        }
    }

    /// 按中国大陆时区的公历，取得日期所对应的星期。
    init(_ date: Date) {
        self.init(rawValue: ProfileRules.calendar.component(.weekday, from: date))!
    }

    /// 界面展示顺序从周一开始，而非日历原始的周日开始。
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}

/// 常规每周工作安排，使用 Int 的二进制位保存七天的工作状态；位为 1 代表上班，0 代表休息。
struct Workweek: Equatable {
    /// 默认周一至周五上班，对应二进制 `0b0111110`，即十进制 62。
    static let `default` = Workweek(mask: 62)

    /// 工作周的位掩码。
    var mask: Int

    init(mask: Int) {
        self.mask = mask
    }

    /// 判断目标星期对应的二进制位是否为 1。
    func contains(_ weekday: Weekday) -> Bool {
        mask & Self.bit(weekday) != 0
    }

    /// 将指定星期的二进制位设为上班（1）或休息（0）。
    mutating func set(_ weekday: Weekday, isWorkday: Bool) {
        if isWorkday { mask |= Self.bit(weekday) } else { mask &= ~Self.bit(weekday) }
    }

    /// 将星期转换为其对应的二进制位，例如周一是 `1 << 1`。
    private static func bit(_ weekday: Weekday) -> Int { 1 << (weekday.rawValue - 1) }
}

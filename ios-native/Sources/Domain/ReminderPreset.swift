import Foundation

struct ReminderPreset: Identifiable, Hashable {
    enum Kind: Hashable {
        case minutes(Int)
        case tonight
        case tomorrowMorning
        case specificTime(hour: Int, minute: Int)
    }

    let id = UUID()
    let label: String
    let kind: Kind

    func resolve(from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        switch kind {
        case .minutes(let minutes):
            return calendar.date(byAdding: .minute, value: minutes, to: date) ?? date
        case .tonight:
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 20
            components.minute = 0
            let tonight = calendar.date(from: components) ?? date
            if tonight <= date {
                return calendar.date(byAdding: .day, value: 1, to: tonight) ?? tonight
            }
            return tonight
        case .tomorrowMorning:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return date }
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components) ?? tomorrow
        case .specificTime(let hour, let minute):
            // 今日の指定時刻を計算、過ぎていたら翌日
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            let targetTime = calendar.date(from: components) ?? date
            if targetTime <= date {
                return calendar.date(byAdding: .day, value: 1, to: targetTime) ?? targetTime
            }
            return targetTime
        }
    }
}

extension ReminderPreset {
    /// 分数からReminderPresetを作成
    static func fromMinutes(_ minutes: Int) -> ReminderPreset {
        ReminderPreset(label: formatMinutesLabel(minutes), kind: .minutes(minutes))
    }
    
    /// 分数を日本語ラベルに変換
    static func formatMinutesLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分後"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return "\(hours)時間後"
        } else {
            return "\(minutes)分後"
        }
    }
    
    /// デフォルトのプリセット一覧
    static let all: [ReminderPreset] = [
        ReminderPreset(label: "10分後", kind: .minutes(10)),
        ReminderPreset(label: "20分後", kind: .minutes(20)),
        ReminderPreset(label: "30分後", kind: .minutes(30)),
        ReminderPreset(label: "45分後", kind: .minutes(45)),
        ReminderPreset(label: "1時間後", kind: .minutes(60)),
        ReminderPreset(label: "90分後", kind: .minutes(90)),
        ReminderPreset(label: "2時間後", kind: .minutes(120)),
        ReminderPreset(label: "3時間後", kind: .minutes(180)),
        ReminderPreset(label: "4時間後", kind: .minutes(240)),
        ReminderPreset(label: "6時間後", kind: .minutes(360)),
        ReminderPreset(label: "今夜", kind: .tonight),
        ReminderPreset(label: "明日朝", kind: .tomorrowMorning)
    ]
}

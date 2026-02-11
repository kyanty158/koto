import Foundation

/// ユーザーのカスタムリマインダープリセットを管理・永続化するクラス
@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class CustomReminderPresetStore: ObservableObject {
    private static let userDefaultsKey = "koto_custom_reminder_presets"
    private static let specificTimesKey = "koto_custom_specific_times"
    
    /// デフォルトのプリセット分数リスト
    static let defaultMinutePresets: [Int] = [10, 20, 30, 45, 60, 90, 120, 180, 240, 360]
    
    /// 現在のカスタムプリセット（分数リスト）
    @Published private(set) var minutePresets: [Int] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    /// 時刻指定プリセット（HH:mm形式を分に変換して保存、例: 9:00 = 540, 20:00 = 1200）
    @Published private(set) var specificTimes: [Int] {
        didSet {
            saveSpecificTimes()
        }
    }
    
    /// 「今夜」「明日朝」などの特殊プリセットを含めるかどうか
    @Published var includeSpecialPresets: Bool = true {
        didSet {
            UserDefaults.standard.set(includeSpecialPresets, forKey: "koto_include_special_presets")
        }
    }
    
    init() {
        // UserDefaultsから読み込み
        if let savedPresets = UserDefaults.standard.array(forKey: Self.userDefaultsKey) as? [Int], !savedPresets.isEmpty {
            self.minutePresets = savedPresets
        } else {
            self.minutePresets = Self.defaultMinutePresets
        }
        
        if let savedTimes = UserDefaults.standard.array(forKey: Self.specificTimesKey) as? [Int] {
            self.specificTimes = savedTimes
        } else {
            self.specificTimes = []
        }
        
        self.includeSpecialPresets = UserDefaults.standard.object(forKey: "koto_include_special_presets") as? Bool ?? true
    }
    
    /// 現在のプリセットをReminderPreset配列として取得
    var presets: [ReminderPreset] {
        var result: [ReminderPreset] = minutePresets.map { ReminderPreset.fromMinutes($0) }
        
        // 時刻指定プリセットを追加
        for timeMinutes in specificTimes.sorted() {
            let hour = timeMinutes / 60
            let minute = timeMinutes % 60
            let label = String(format: "%02d:%02d に通知", hour, minute)
            result.append(ReminderPreset(label: label, kind: .specificTime(hour: hour, minute: minute)))
        }
        
        if includeSpecialPresets {
            result.append(ReminderPreset(label: "今夜", kind: .tonight))
            result.append(ReminderPreset(label: "明日朝", kind: .tomorrowMorning))
        }
        return result
    }
    
    /// プリセットを追加
    func addPreset(minutes: Int) {
        guard !minutePresets.contains(minutes) else { return }
        minutePresets.append(minutes)
        minutePresets.sort()
    }
    
    /// 時刻指定プリセットを追加
    func addSpecificTime(hour: Int, minute: Int) {
        let timeMinutes = hour * 60 + minute
        guard !specificTimes.contains(timeMinutes) else { return }
        specificTimes.append(timeMinutes)
        specificTimes.sort()
    }
    
    /// プリセットを削除
    func removePreset(minutes: Int) {
        minutePresets.removeAll { $0 == minutes }
    }
    
    /// プリセットを削除（インデックス指定）
    func removePreset(at index: Int) {
        guard minutePresets.indices.contains(index) else { return }
        minutePresets.remove(at: index)
    }
    
    /// 時刻指定プリセットを削除
    func removeSpecificTime(timeMinutes: Int) {
        specificTimes.removeAll { $0 == timeMinutes }
    }
    
    /// プリセットの順序を変更
    func movePreset(from source: IndexSet, to destination: Int) {
        minutePresets.move(fromOffsets: source, toOffset: destination)
    }
    
    /// デフォルトに戻す
    func resetToDefaults() {
        minutePresets = Self.defaultMinutePresets
        specificTimes = []
        includeSpecialPresets = true
    }
    
    /// UserDefaultsに保存
    private func saveToUserDefaults() {
        UserDefaults.standard.set(minutePresets, forKey: Self.userDefaultsKey)
    }
    
    /// 時刻指定を保存
    private func saveSpecificTimes() {
        UserDefaults.standard.set(specificTimes, forKey: Self.specificTimesKey)
    }
}


import Foundation

enum AutoIncrementer {
    private static let key = "MemoAutoIncrement"

    static func nextID() -> Int64 {
        let defaults = UserDefaults.standard
        let current = defaults.integer(forKey: key)
        let next = current + 1
        defaults.set(next, forKey: key)
        defaults.synchronize()
        return Int64(next)
    }

    static func resetIfNeeded(to value: Int64) {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: key) < value {
            defaults.set(Int(value), forKey: key)
            defaults.synchronize()
        }
    }
}

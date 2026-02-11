import XCTest
@testable import KotoKit

final class ReminderPresetTests: XCTestCase {
    func testMinutesPresetAddsInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let preset = ReminderPreset(label: "10分後", kind: .minutes(10))
        let resolved = preset.resolve(from: now)
        XCTAssertEqual(resolved, now.addingTimeInterval(600))
    }

    func testTonightMovesToTomorrowIfPastEightPM() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 27
        components.hour = 22
        components.minute = 30
        let now = calendar.date(from: components)!
        let preset = ReminderPreset(label: "今夜", kind: .tonight)
        let resolved = preset.resolve(from: now, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2025, month: 10, day: 28, hour: 20))
        XCTAssertEqual(resolved, expected)
    }

    func testTomorrowMorningAlwaysNextMorning() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2025, month: 10, day: 27, hour: 8))!
        let preset = ReminderPreset(label: "明日朝", kind: .tomorrowMorning)
        let resolved = preset.resolve(from: now, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2025, month: 10, day: 28, hour: 9))
        XCTAssertEqual(resolved, expected)
    }
}

import BibleCore
import SwiftUI
import UserNotifications

/// 매일 알림 (통독 · 오늘의 말씀). 내용이 날마다 달라서 앞으로 14일 치를 미리 예약함
enum Reminders {
    enum Kind: String {
        case plan, dailyVerse, prayer

        var title: String {
            switch self {
            case .plan: return "통독 알림"
            case .dailyVerse: return "오늘의 말씀 알림"
            case .prayer: return "기도 알림"
            }
        }
        var enabledKey: String { "reminder.\(rawValue).on" }
        var timeKey: String { "reminder.\(rawValue).minutes" }
        var defaultMinutes: Int {
            switch self {
            case .plan: return 21 * 60
            case .dailyVerse: return 7 * 60
            case .prayer: return 6 * 60 + 30
            }
        }
    }

    static func isOn(_ kind: Kind) -> Bool { UserDefaults.standard.bool(forKey: kind.enabledKey) }

    static func minutes(_ kind: Kind) -> Int {
        UserDefaults.standard.object(forKey: kind.timeKey) as? Int ?? kind.defaultMinutes
    }

    static func reschedule(model: AppModel) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let wantsAny = isOn(.plan) || isOn(.dailyVerse) || isOn(.prayer)
        guard wantsAny else { return }

        // 알림에 넣을 글은 여기(메인 스레드)에서 미리 만들어 둠
        var items: [(id: String, title: String, body: String, date: DateComponents)] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let planDays = model.planDays
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if isOn(.plan), let plan = model.user.data.plan {
                let index = (calendar.dateComponents([.day], from: calendar.startOfDay(for: plan.start), to: day).day ?? 0)
                if index >= 0, index < planDays.count, !plan.done.contains(index) {
                    items.append(("plan-\(offset)", "오늘 통독 · \(index + 1)일째", ReadingPlan.label(planDays[index]),
                                  components(day, minutes(.plan))))
                }
            }
            if isOn(.prayer) {
                let open = model.user.data.prayers.filter { $0.answered == nil }.count
                let phrase = Extras.daily(Extras.phrases.prayer, on: day) ?? Extras.daily(PrayerView.defaultPhrases, on: day) ?? ""
                let body = Extras.personalize(phrase) + (open > 0 ? " (기도 제목 \(open)개)" : "")
                items.append(("prayer-\(offset)", "기도할 시간", body, components(day, minutes(.prayer))))
            }
            if isOn(.dailyVerse), let ref = DailyVerses.reference(for: day) {
                let text = model.verses(model.primaryID, from: ref.start, to: ref.end ?? ref.start).map(\.text).joined(separator: " ")
                items.append(("verse-\(offset)", "오늘의 말씀 · \(ref.start.shortLabel)", text, components(day, minutes(.dailyVerse))))
            }
        }

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            DebugLog.write("알림 권한: \(granted) \(error.map { "\($0)" } ?? "")")
            guard granted else { return }
            for item in items {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.date, repeats: false)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    private static func components(_ day: Date, _ minutes: Int) -> DateComponents {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        c.hour = minutes / 60
        c.minute = minutes % 60
        return c
    }
}

/// 알림 켜기 + 시각 고르기
struct ReminderToggle: View {
    @Environment(AppModel.self) private var model
    let kind: Reminders.Kind
    @Local private var on = false
    @Local private var time = Date()

    var body: some View {
        HStack(spacing: 8) {
            Toggle(kind.title, isOn: $on)
                .toggleStyle(.switch)
                .controlSize(.small)
            if on {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 90)
            }
        }
        .onAppear {
            on = Reminders.isOn(kind)
            let minutes = Reminders.minutes(kind)
            time = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        }
        .onChange(of: on) { _, value in
            UserDefaults.standard.set(value, forKey: kind.enabledKey)
            Reminders.reschedule(model: model)
        }
        .onChange(of: time) { _, value in
            let c = Calendar.current.dateComponents([.hour, .minute], from: value)
            UserDefaults.standard.set((c.hour ?? 0) * 60 + (c.minute ?? 0), forKey: kind.timeKey)
            Reminders.reschedule(model: model)
        }
    }
}

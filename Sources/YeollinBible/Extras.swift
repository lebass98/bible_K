import Foundation

/// 사용자가 바꿔 넣을 수 있는 문구·목록 (없으면 앱에 든 기본값을 씀)
/// ~/Library/Application Support/YeollinBible/Extras/
///   daily_verses.json  ["창1:1", "시23:1-3", …]          오늘의 말씀 구절 목록
///   phrases.json       {"thanks": […], "plan": […], "prayer": […]}   감사 글 · 통독 격려 · 기도 알림 문구
enum Extras {
    static let folder: URL = UserStore.folder.appendingPathComponent("Extras", isDirectory: true)

    struct Phrases: Codable {
        var thanks: [String] = []
        var plan: [String] = []
        var prayer: [String] = []
    }

    static let dailyVerses: [String]? = {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("daily_verses.json")),
              let list = try? JSONDecoder().decode([String].self, from: data), !list.isEmpty else { return nil }
        return list
    }()

    static let phrases: Phrases = {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("phrases.json")),
              let value = try? JSONDecoder().decode(Phrases.self, from: data) else { return Phrases() }
        return value
    }()

    /// 날마다 하나씩 돌아가며 고름 (같은 날에는 늘 같은 문구)
    static func daily(_ list: [String], on date: Date = Date(), offset: Int = 0) -> String? {
        guard !list.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[(day + offset) % list.count]
    }

    /// 기도 알림 문구의 {{NAME}} 을 맥 사용자 이름으로
    static func personalize(_ text: String) -> String {
        let name = NSFullUserName().isEmpty ? "" : NSFullUserName()
        return text.replacingOccurrences(of: "{{NAME}}님", with: name.isEmpty ? "" : "\(name)님")
            .replacingOccurrences(of: "{{NAME}}", with: name)
            .trimmingCharacters(in: .whitespaces)
    }
}

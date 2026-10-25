import AppKit
import BibleCore
import Foundation
import Observation

/// 형광펜 색
enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow, green, blue, pink, orange
    var id: String { rawValue }

    var name: String {
        switch self {
        case .yellow: return "노랑"
        case .green: return "초록"
        case .blue: return "파랑"
        case .pink: return "분홍"
        case .orange: return "주황"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor(red: 1.0, green: 0.86, blue: 0.2, alpha: 1)
        case .green: return NSColor(red: 0.45, green: 0.85, blue: 0.45, alpha: 1)
        case .blue: return NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
        case .pink: return NSColor(red: 1.0, green: 0.5, blue: 0.7, alpha: 1)
        case .orange: return NSColor(red: 1.0, green: 0.62, blue: 0.3, alpha: 1)
        }
    }
}

struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    var ref: VerseRef
    var created = Date()
}

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: VerseRef
    var end: VerseRef
    var text: String
    var created = Date()
    var updated = Date()

    var label: String {
        start == end ? start.label : (start.chapter == end.chapter ? "\(start.label)-\(end.verse)" : "\(start.label) ~ \(end.shortLabel)")
    }

    func covers(_ ref: VerseRef) -> Bool { ref >= start && ref <= end }
}

struct HistoryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var chapter: ChapterRef
    var date = Date()
}

struct ThanksEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var text: String
}

struct PlanProgress: Codable, Hashable {
    var planID: String
    var start: Date
    var done: Set<Int> = []
}

/// 사용자가 만든 모든 기록. ~/Library/Application Support/YeollinBible/userdata.json 에 저장
struct UserData: Codable {
    var bookmarks: [Bookmark] = []
    var highlights: [Int: HighlightColor] = [:]     // 구절 아이디 → 색
    var notes: [Note] = []
    var history: [HistoryItem] = []
    var thanks: [ThanksEntry] = []
    var plan: PlanProgress?
    var lastLocation = ChapterRef(book: 1, chapter: 1)
    var hymnFavorites: Set<Int> = []
    var prayers: [PrayerItem] = []

    // 예전 백업 파일에 없는 항목이 있어도 읽히게
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookmarks = try c.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        highlights = try c.decodeIfPresent([Int: HighlightColor].self, forKey: .highlights) ?? [:]
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        history = try c.decodeIfPresent([HistoryItem].self, forKey: .history) ?? []
        thanks = try c.decodeIfPresent([ThanksEntry].self, forKey: .thanks) ?? []
        plan = try c.decodeIfPresent(PlanProgress.self, forKey: .plan)
        lastLocation = try c.decodeIfPresent(ChapterRef.self, forKey: .lastLocation) ?? ChapterRef(book: 1, chapter: 1)
        hymnFavorites = try c.decodeIfPresent(Set<Int>.self, forKey: .hymnFavorites) ?? []
        prayers = try c.decodeIfPresent([PrayerItem].self, forKey: .prayers) ?? []
    }
}

@Observable
final class UserStore {
    var data = UserData() {
        didSet { scheduleSave() }
    }

    static let folder: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YeollinBible", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private let fileURL = UserStore.folder.appendingPathComponent("userdata.json")
    @ObservationIgnored private var saveWork: DispatchWorkItem?

    init() {
        if let raw = try? Data(contentsOf: fileURL) {
            do {
                data = try Self.decoder.decode(UserData.self, from: raw)
            } catch {
                DebugLog.write("기록 파일 읽기 실패: \(error)")
                // 망가진 파일은 지우지 않고 옆에 남겨 둠
                try? FileManager.default.copyItem(at: fileURL, to: fileURL.appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970))"))
            }
        }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        do {
            try Self.encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            DebugLog.write("기록 저장 실패: \(error)")
        }
    }

    // MARK: 책갈피

    func isBookmarked(_ ref: VerseRef) -> Bool { data.bookmarks.contains { $0.ref == ref } }

    func toggleBookmark(_ refs: [VerseRef]) {
        let allMarked = refs.allSatisfy(isBookmarked)
        if allMarked {
            data.bookmarks.removeAll { refs.contains($0.ref) }
        } else {
            for ref in refs where !isBookmarked(ref) { data.bookmarks.insert(Bookmark(ref: ref), at: 0) }
        }
    }

    // MARK: 형광펜

    func setHighlight(_ color: HighlightColor?, for refs: [VerseRef]) {
        for ref in refs { data.highlights[ref.id] = color }
    }

    // MARK: 노트

    func notes(for ref: VerseRef) -> [Note] { data.notes.filter { $0.covers(ref) } }

    func saveNote(_ note: Note) {
        var note = note
        note.updated = Date()
        if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data.notes.removeAll { $0.id == note.id }
        } else if let index = data.notes.firstIndex(where: { $0.id == note.id }) {
            data.notes[index] = note
        } else {
            data.notes.insert(note, at: 0)
        }
    }

    // MARK: 읽은 기록

    func addHistory(_ chapter: ChapterRef) {
        data.lastLocation = chapter
        if data.history.first?.chapter == chapter {
            data.history[0].date = Date()
            return
        }
        data.history.insert(HistoryItem(chapter: chapter), at: 0)
        if data.history.count > 500 { data.history.removeLast(data.history.count - 500) }
    }

    // MARK: 찬송가

    func toggleHymnFavorite(_ number: Int) {
        if data.hymnFavorites.contains(number) { data.hymnFavorites.remove(number) } else { data.hymnFavorites.insert(number) }
    }

    // MARK: 백업

    func exportBackup(to url: URL) throws {
        try Self.encoder.encode(data).write(to: url, options: .atomic)
    }

    func importBackup(from url: URL) throws {
        let restored = try Self.decoder.decode(UserData.self, from: Data(contentsOf: url))
        data = restored
        saveNow()
    }
}

import AppKit
import BibleCore
import Foundation
import Observation
import SwiftUI

/// 왼쪽 목록의 화면들
enum AppSection: String, CaseIterable, Identifiable {
    case reader, search, records, history, plan, today, thanks, library
    var id: String { rawValue }

    var title: String {
        switch self {
        case .reader: return "성경 읽기"
        case .search: return "찾기"
        case .records: return "내 기록"
        case .history: return "읽은 기록"
        case .plan: return "통독"
        case .today: return "오늘의 말씀"
        case .thanks: return "한 줄 감사"
        case .library: return "역본 관리"
        }
    }

    var icon: String {
        switch self {
        case .reader: return "book"
        case .search: return "magnifyingglass"
        case .records: return "bookmark"
        case .history: return "clock.arrow.circlepath"
        case .plan: return "checklist"
        case .today: return "sun.max"
        case .thanks: return "heart.text.square"
        case .library: return "books.vertical"
        }
    }
}

/// 앱 전체 상태
@Observable
final class AppModel {
    // MARK: 데이터

    let bundled: BibleDatabase?
    let imported: BibleDatabase?
    private(set) var translations: [BibleTranslation] = []
    let user = UserStore()
    let speech = SpeechReader()

    // MARK: 화면 상태

    var section: AppSection = .reader
    var location: ChapterRef {
        didSet {
            guard location != oldValue else { return }
            user.addHistory(location)
            selection = []
            selectedStrong = nil
        }
    }
    /// 이 절로 스크롤 (찾기·관주에서 넘어올 때)
    var scrollTarget: VerseRef?
    /// 고른 절들 (클릭으로 고름)
    var selection: Set<VerseRef> = []
    var selectedStrong: String?
    var showInspector = false
    var cardVerses: [VerseRow]?
    var noteDraft: Note?
    var showGoTo = false
    var importError: String?

    // MARK: 설정 (UserDefaults에 저장)

    var primaryID: String { didSet { defaults.set(primaryID, forKey: "primary") } }
    var secondaryID: String? { didSet { defaults.set(secondaryID, forKey: "secondary") } }
    var parallel: Bool { didSet { defaults.set(parallel, forKey: "parallel") } }
    var showStrongs: Bool { didSet { defaults.set(showStrongs, forKey: "showStrongs") } }
    var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    var serif: Bool { didSet { defaults.set(serif, forKey: "serif") } }
    var lineSpacing: Double { didSet { defaults.set(lineSpacing, forKey: "lineSpacing") } }
    var showHeadings: Bool { didSet { defaults.set(showHeadings, forKey: "showHeadings") } }
    var showVerseNumbers: Bool { didSet { defaults.set(showVerseNumbers, forKey: "showVerseNumbers") } }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        if let path = Bundle.main.path(forResource: "bible", ofType: "sqlite") {
            bundled = try? BibleDatabase(path: path, readOnly: true)
        } else {
            bundled = nil
        }
        if bundled == nil { DebugLog.write("앱에 든 성경 DB를 열지 못함 — 번들: \(Bundle.main.bundlePath)") }
        imported = try? BibleDatabase(path: UserStore.folder.appendingPathComponent("imported.sqlite").path, readOnly: false)

        primaryID = defaults.string(forKey: "primary") ?? "kor"
        secondaryID = defaults.string(forKey: "secondary") ?? "kjv"
        parallel = defaults.bool(forKey: "parallel")
        showStrongs = defaults.bool(forKey: "showStrongs")
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 18
        serif = defaults.object(forKey: "serif") as? Bool ?? true
        lineSpacing = defaults.object(forKey: "lineSpacing") as? Double ?? 6
        showHeadings = defaults.object(forKey: "showHeadings") as? Bool ?? true
        showVerseNumbers = defaults.object(forKey: "showVerseNumbers") as? Bool ?? true
        location = user.data.lastLocation

        reloadTranslations()
        if translation(primaryID) == nil { primaryID = translations.first?.id ?? "kor" }
        speech.onChapterFinished = { [weak self] in
            guard let self, let next = self.location.next else { self?.speech.stop(); return }
            self.open(next)
            self.speak(from: nil)
        }
    }

    // MARK: 음성 읽기

    func speak(from start: VerseRef?) {
        speech.speak(chapter(primaryID, location), language: primary?.language ?? "ko", from: start)
    }

    /// 본문 글꼴 (명조를 고르면 한글은 애플명조, 영어는 세리프)
    func textFont(language: String, scale: Double = 1) -> Font {
        let size = fontSize * scale
        guard serif else { return .system(size: size) }
        return language == "ko" ? .custom("AppleMyungjo", size: size) : .system(size: size, design: .serif)
    }

    func reloadTranslations() {
        translations = (bundled?.translations(imported: false) ?? []) + (imported?.translations(imported: true) ?? [])
    }

    func translation(_ id: String?) -> BibleTranslation? { translations.first { $0.id == id } }
    var primary: BibleTranslation? { translation(primaryID) }
    var secondary: BibleTranslation? { parallel ? translation(secondaryID) : nil }

    func database(for id: String) -> BibleDatabase? {
        translation(id)?.isImported == true ? imported : bundled
    }

    // MARK: 본문

    func chapter(_ tr: String, _ ref: ChapterRef) -> [VerseRow] {
        database(for: tr)?.chapter(tr, ref) ?? []
    }

    func verses(_ tr: String, from: VerseRef, to: VerseRef) -> [VerseRow] {
        database(for: tr)?.verses(tr, from: from, to: to) ?? []
    }

    func verseText(_ ref: VerseRef, tr: String? = nil) -> String {
        let id = tr ?? primaryID
        return database(for: id)?.verse(id, ref)?.text ?? ""
    }

    func strong(_ id: String) -> StrongEntry? { bundled?.strong(id) }
    func crossRefs(_ ref: VerseRef) -> [CrossRef] { bundled?.crossRefs(ref) ?? [] }

    // MARK: 이동

    func open(_ ref: VerseRef, select: Bool = true) {
        section = .reader
        location = ChapterRef(book: ref.book, chapter: ref.chapter)
        scrollTarget = ref
        if select { selection = [ref] }
    }

    func open(_ chapter: ChapterRef) {
        section = .reader
        location = chapter
        scrollTarget = VerseRef(book: chapter.book, chapter: chapter.chapter, verse: 1)
    }

    func goNext() { if let next = location.next { open(next) } }
    func goPrevious() { if let prev = location.previous { open(prev) } }

    // MARK: 고른 절로 하는 일

    var sortedSelection: [VerseRef] { selection.sorted() }

    func copySelection() {
        copy(sortedSelection)
    }

    func copy(_ refs: [VerseRef]) {
        guard let first = refs.first, let last = refs.last else { return }
        let lines = refs.map { ref -> String in
            let text = verseText(ref)
            return refs.count > 1 ? "\(ref.verse) \(text)" : text
        }
        let range = first == last ? first.label : (first.chapter == last.chapter ? "\(first.label)-\(last.verse)" : "\(first.label) ~ \(last.shortLabel)")
        let body = lines.joined(separator: "\n") + "\n(\(range), \(primary?.short ?? ""))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(body, forType: .string)
    }

    func makeCard(_ refs: [VerseRef]) {
        guard let first = refs.first, let last = refs.last else { return }
        cardVerses = verses(primaryID, from: first, to: last)
    }

    func writeNote(_ refs: [VerseRef]) {
        guard let first = refs.first, let last = refs.last else { return }
        noteDraft = user.data.notes.first { $0.start == first && $0.end == last } ?? Note(start: first, end: last, text: "")
    }
}

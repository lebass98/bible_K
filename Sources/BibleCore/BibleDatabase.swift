import Foundation

/// 역본 정보
public struct BibleTranslation: Identifiable, Hashable, Sendable {
    public let id: String          // "kor", "kjv", 가져온 역본은 "u-…"
    public var name: String        // 화면에 보이는 이름
    public var short: String       // 짧은 이름 (대역 머리글)
    public var language: String    // "ko", "en", …
    public var license: String
    public var source: String
    public var hasStrongs: Bool
    public var isImported: Bool

    public init(id: String, name: String, short: String, language: String, license: String, source: String,
                hasStrongs: Bool = false, isImported: Bool = false) {
        self.id = id; self.name = name; self.short = short; self.language = language
        self.license = license; self.source = source; self.hasStrongs = hasStrongs; self.isImported = isImported
    }
}

public struct VerseRow: Identifiable, Hashable, Sendable {
    public let ref: VerseRef
    public let text: String
    public let heading: String?
    public let tagged: String?
    public var id: Int { ref.id }

    public init(ref: VerseRef, text: String, heading: String?, tagged: String?) {
        self.ref = ref; self.text = text; self.heading = heading; self.tagged = tagged
    }
}

/// 역본에 딸린 관주(link)·각주(note)
public struct VerseNote: Hashable, Sendable {
    public let kind: String       // "link" 관주, "note" 각주, 그 밖
    public let mark: String       // 본문에 붙은 표시 (ㄱ, 1, a …)
    public let text: String       // 설명
    public let refs: [String]     // 연결 구절 주소 ("요1:29")

    public var isFootnote: Bool { kind != "link" }
}

public struct StrongEntry: Hashable, Sendable {
    public let id: String
    public let lemma: String
    public let transliteration: String
    public let pronunciation: String
    public let definition: String
    public let kjvUsage: String
    public let derivation: String
}

public struct CrossRef: Hashable, Sendable {
    public let target: VerseRef
    public let targetEnd: VerseRef?
    public let votes: Int

    public var label: String {
        guard let end = targetEnd, end != target else { return target.shortLabel }
        if end.book == target.book && end.chapter == target.chapter { return "\(target.shortLabel)-\(end.verse)" }
        return "\(target.shortLabel) ~ \(end.shortLabel)"
    }
}

/// 성경 본문 DB. 앱에 들어 있는 것(읽기 전용)과 사용자가 가져온 것(쓰기 가능)이 같은 구조를 씀
public final class BibleDatabase {
    public let db: SQLiteDB

    public static let schema = """
        CREATE TABLE IF NOT EXISTS translations(
            id TEXT PRIMARY KEY, name TEXT, short TEXT, language TEXT, license TEXT, source TEXT,
            has_strongs INTEGER DEFAULT 0, sort INTEGER DEFAULT 0);
        CREATE TABLE IF NOT EXISTS verses(
            tr TEXT, id INTEGER, text TEXT, heading TEXT, tagged TEXT, PRIMARY KEY(tr, id)) WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS strongs(
            id TEXT PRIMARY KEY, lemma TEXT, xlit TEXT, pron TEXT, def TEXT, kjv TEXT, deriv TEXT) WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS xrefs(src INTEGER, dst INTEGER, dst_end INTEGER, votes INTEGER);
        CREATE INDEX IF NOT EXISTS xrefs_src ON xrefs(src);
        CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE IF NOT EXISTS notes(tr TEXT, id INTEGER, kind TEXT, mark TEXT, text TEXT, refs TEXT);
        CREATE INDEX IF NOT EXISTS notes_verse ON notes(tr, id);
        """

    public init(path: String, readOnly: Bool) throws {
        db = try SQLiteDB(path: path, readOnly: readOnly)
        if !readOnly { try db.exec(Self.schema) }
    }

    // MARK: 쓰기

    public func saveTranslation(_ t: BibleTranslation, sort: Int) {
        db.run("INSERT OR REPLACE INTO translations VALUES(?,?,?,?,?,?,?,?)",
               [t.id, t.name, t.short, t.language, t.license, t.source, t.hasStrongs, sort])
    }

    public func saveVerses(_ verses: [ParsedVerse], translation: String) throws {
        try db.transaction {
            let stmt = try db.prepare("INSERT OR REPLACE INTO verses VALUES(?,?,?,?,?)")
            for verse in verses {
                stmt.bind([translation, verse.ref.id, verse.text, verse.heading, verse.tagged])
                stmt.stepDone()
            }
        }
    }

    public func deleteTranslation(_ id: String) {
        db.run("DELETE FROM verses WHERE tr = ?", [id])
        db.run("DELETE FROM notes WHERE tr = ?", [id])
        db.run("DELETE FROM translations WHERE id = ?", [id])
    }

    // MARK: 읽기

    public func translations(imported: Bool) -> [BibleTranslation] {
        db.query("SELECT id, name, short, language, license, source, has_strongs FROM translations ORDER BY sort, name") {
            BibleTranslation(id: $0.text(0), name: $0.text(1), short: $0.text(2), language: $0.text(3),
                        license: $0.text(4), source: $0.text(5), hasStrongs: $0.int(6) != 0, isImported: imported)
        }
    }

    public func chapter(_ tr: String, _ ref: ChapterRef) -> [VerseRow] {
        let start = ref.book * 1_000_000 + ref.chapter * 1000
        return db.query("SELECT id, text, heading, tagged FROM verses WHERE tr = ? AND id > ? AND id < ? ORDER BY id",
                        [tr, start, start + 1000], row: Self.verseRow)
    }

    public func verses(_ tr: String, from: VerseRef, to: VerseRef) -> [VerseRow] {
        db.query("SELECT id, text, heading, tagged FROM verses WHERE tr = ? AND id >= ? AND id <= ? ORDER BY id",
                 [tr, from.id, to.id], row: Self.verseRow)
    }

    public func verse(_ tr: String, _ ref: VerseRef) -> VerseRow? {
        db.query("SELECT id, text, heading, tagged FROM verses WHERE tr = ? AND id = ?", [tr, ref.id], row: Self.verseRow).first
    }

    /// 찾기. 띄어쓰기를 무시하고 찾음 ("하나님이세상을" → "하나님이 세상을")
    public func search(_ tr: String, query: String, books: ClosedRange<Int> = 1...66, limit: Int = 2000) -> [VerseRow] {
        let words = query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let compact = query.replacingOccurrences(of: " ", with: "")
        // 낱말이 모두 들어간 절, 또는 띄어쓰기를 무시하면 이어지는 절
        var conditions = words.map { _ in "text LIKE ? ESCAPE '\\'" }.joined(separator: " AND ")
        conditions = "((\(conditions)) OR replace(text, ' ', '') LIKE ? ESCAPE '\\')"
        let args: [Any?] = [tr, books.lowerBound * 1_000_000, (books.upperBound + 1) * 1_000_000]
            + words.map { "%\(escapeLike($0))%" } + ["%\(escapeLike(compact))%"]
        return db.query("SELECT id, text, heading, tagged FROM verses WHERE tr = ? AND id >= ? AND id < ? AND \(conditions) ORDER BY id LIMIT \(limit)",
                        args, row: Self.verseRow)
    }

    public func strong(_ id: String) -> StrongEntry? {
        db.query("SELECT id, lemma, xlit, pron, def, kjv, deriv FROM strongs WHERE id = ?", [id]) {
            StrongEntry(id: $0.text(0), lemma: $0.text(1), transliteration: $0.text(2), pronunciation: $0.text(3),
                        definition: $0.text(4), kjvUsage: $0.text(5), derivation: $0.text(6))
        }.first
    }

    public func crossRefs(_ ref: VerseRef, limit: Int = 40) -> [CrossRef] {
        db.query("SELECT dst, dst_end, votes FROM xrefs WHERE src = ? ORDER BY votes DESC LIMIT \(limit)", [ref.id]) {
            let end = $0.int(1)
            return CrossRef(target: VerseRef(id: $0.int(0)), targetEnd: end > 0 ? VerseRef(id: end) : nil, votes: $0.int(2))
        }
    }

    /// 장마다 절 수 (통독 계획을 고르게 나눌 때 씀)
    public func verseCounts(_ tr: String) -> [ChapterRef: Int] {
        var result: [ChapterRef: Int] = [:]
        for (id, count) in db.query("SELECT id / 1000, count(*) FROM verses WHERE tr = ? GROUP BY id / 1000", [tr], row: { ($0.int(0), $0.int(1)) }) {
            result[ChapterRef(book: id / 1000, chapter: id % 1000)] = count
        }
        return result
    }

    /// 이 절의 관주·각주 (표가 없는 DB면 빈 목록)
    public func notes(_ tr: String, _ ref: VerseRef) -> [VerseNote] {
        db.query("SELECT kind, mark, text, refs FROM notes WHERE tr = ? AND id = ? ORDER BY rowid", [tr, ref.id]) {
            VerseNote(kind: $0.text(0), mark: $0.text(1), text: $0.text(2),
                      refs: $0.text(3).split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        }
    }

    /// 이 장에서 각주가 있는 절들
    public func footnotedVerses(_ tr: String, _ chapter: ChapterRef) -> Set<Int> {
        let start = chapter.book * 1_000_000 + chapter.chapter * 1000
        return Set(db.query("SELECT DISTINCT id FROM notes WHERE tr = ? AND id > ? AND id < ? AND kind != 'link'",
                            [tr, start, start + 1000]) { $0.int(0) })
    }

    public func meta(_ key: String) -> String? {
        db.query("SELECT value FROM meta WHERE key = ?", [key]) { $0.text(0) }.first
    }

    private static func verseRow(_ s: Statement) -> VerseRow {
        VerseRow(ref: VerseRef(id: s.int(0)), text: s.text(1), heading: s.string(2), tagged: s.string(3))
    }

    private func escapeLike(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}

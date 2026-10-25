import Foundation

/// 성경 66권 정보 (개신교 정경 순서)
public struct BibleBook: Identifiable, Hashable, Sendable {
    public let id: Int          // 1(창세기)~66(요한계시록)
    public let usfm: String     // USFM 코드 (GEN)
    public let osis: String     // OSIS 코드 (Gen) — 관주 데이터가 씀
    public let name: String     // 창세기
    public let short: String    // 창
    public let english: String  // Genesis
    public let chapters: Int

    public var isOldTestament: Bool { id <= 39 }
}

public enum Bible {
    public static let books: [BibleBook] = rawBooks.enumerated().map { index, row in
        BibleBook(id: index + 1, usfm: row.0, osis: row.1, name: row.2, short: row.3, english: row.4, chapters: row.5)
    }

    public static func book(_ id: Int) -> BibleBook? {
        guard id >= 1, id <= books.count else { return nil }
        return books[id - 1]
    }

    public static let oldTestament = Array(books[0..<39])
    public static let newTestament = Array(books[39...])
    public static let totalChapters = books.reduce(0) { $0 + $1.chapters }

    /// 이름·약어·코드 어느 것으로도 책 찾기 (창세기, 창, GEN, Gen, Genesis, 1, "1 Samuel", "1Sam")
    public static func findBook(_ text: String) -> BibleBook? {
        let key = normalize(text)
        guard !key.isEmpty else { return nil }
        if let number = Int(key) { return book(number) }
        return lookup[key]
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let lookup: [String: BibleBook] = {
        var map: [String: BibleBook] = [:]
        for book in books {
            for key in [book.usfm, book.osis, book.name, book.short, book.english] + (aliases[book.id] ?? []) {
                let normalized = normalize(key)
                if map[normalized] == nil { map[normalized] = book }
            }
        }
        return map
    }()

    /// 흔히 쓰는 다른 이름
    private static let aliases: [Int: [String]] = [
        13: ["역대기상", "역상"], 14: ["역대기하", "역하"], 19: ["시편", "Psalm", "Psa"],
        22: ["아가서", "Song of Songs", "Canticles"], 25: ["애가"], 43: ["요한"], 66: ["계시록", "Revelations"],
        44: ["행전"]
    ]

    private static let rawBooks: [(String, String, String, String, String, Int)] = [
        ("GEN", "Gen", "창세기", "창", "Genesis", 50),
        ("EXO", "Exod", "출애굽기", "출", "Exodus", 40),
        ("LEV", "Lev", "레위기", "레", "Leviticus", 27),
        ("NUM", "Num", "민수기", "민", "Numbers", 36),
        ("DEU", "Deut", "신명기", "신", "Deuteronomy", 34),
        ("JOS", "Josh", "여호수아", "수", "Joshua", 24),
        ("JDG", "Judg", "사사기", "삿", "Judges", 21),
        ("RUT", "Ruth", "룻기", "룻", "Ruth", 4),
        ("1SA", "1Sam", "사무엘상", "삼상", "1 Samuel", 31),
        ("2SA", "2Sam", "사무엘하", "삼하", "2 Samuel", 24),
        ("1KI", "1Kgs", "열왕기상", "왕상", "1 Kings", 22),
        ("2KI", "2Kgs", "열왕기하", "왕하", "2 Kings", 25),
        ("1CH", "1Chr", "역대상", "대상", "1 Chronicles", 29),
        ("2CH", "2Chr", "역대하", "대하", "2 Chronicles", 36),
        ("EZR", "Ezra", "에스라", "스", "Ezra", 10),
        ("NEH", "Neh", "느헤미야", "느", "Nehemiah", 13),
        ("EST", "Esth", "에스더", "에", "Esther", 10),
        ("JOB", "Job", "욥기", "욥", "Job", 42),
        ("PSA", "Ps", "시편", "시", "Psalms", 150),
        ("PRO", "Prov", "잠언", "잠", "Proverbs", 31),
        ("ECC", "Eccl", "전도서", "전", "Ecclesiastes", 12),
        ("SNG", "Song", "아가", "아", "Song of Solomon", 8),
        ("ISA", "Isa", "이사야", "사", "Isaiah", 66),
        ("JER", "Jer", "예레미야", "렘", "Jeremiah", 52),
        ("LAM", "Lam", "예레미야애가", "애", "Lamentations", 5),
        ("EZK", "Ezek", "에스겔", "겔", "Ezekiel", 48),
        ("DAN", "Dan", "다니엘", "단", "Daniel", 12),
        ("HOS", "Hos", "호세아", "호", "Hosea", 14),
        ("JOL", "Joel", "요엘", "욜", "Joel", 3),
        ("AMO", "Amos", "아모스", "암", "Amos", 9),
        ("OBA", "Obad", "오바댜", "옵", "Obadiah", 1),
        ("JON", "Jonah", "요나", "욘", "Jonah", 4),
        ("MIC", "Mic", "미가", "미", "Micah", 7),
        ("NAM", "Nah", "나훔", "나", "Nahum", 3),
        ("HAB", "Hab", "하박국", "합", "Habakkuk", 3),
        ("ZEP", "Zeph", "스바냐", "습", "Zephaniah", 3),
        ("HAG", "Hag", "학개", "학", "Haggai", 2),
        ("ZEC", "Zech", "스가랴", "슥", "Zechariah", 14),
        ("MAL", "Mal", "말라기", "말", "Malachi", 4),
        ("MAT", "Matt", "마태복음", "마", "Matthew", 28),
        ("MRK", "Mark", "마가복음", "막", "Mark", 16),
        ("LUK", "Luke", "누가복음", "눅", "Luke", 24),
        ("JHN", "John", "요한복음", "요", "John", 21),
        ("ACT", "Acts", "사도행전", "행", "Acts", 28),
        ("ROM", "Rom", "로마서", "롬", "Romans", 16),
        ("1CO", "1Cor", "고린도전서", "고전", "1 Corinthians", 16),
        ("2CO", "2Cor", "고린도후서", "고후", "2 Corinthians", 13),
        ("GAL", "Gal", "갈라디아서", "갈", "Galatians", 6),
        ("EPH", "Eph", "에베소서", "엡", "Ephesians", 6),
        ("PHP", "Phil", "빌립보서", "빌", "Philippians", 4),
        ("COL", "Col", "골로새서", "골", "Colossians", 4),
        ("1TH", "1Thess", "데살로니가전서", "살전", "1 Thessalonians", 5),
        ("2TH", "2Thess", "데살로니가후서", "살후", "2 Thessalonians", 3),
        ("1TI", "1Tim", "디모데전서", "딤전", "1 Timothy", 6),
        ("2TI", "2Tim", "디모데후서", "딤후", "2 Timothy", 4),
        ("TIT", "Titus", "디도서", "딛", "Titus", 3),
        ("PHM", "Phlm", "빌레몬서", "몬", "Philemon", 1),
        ("HEB", "Heb", "히브리서", "히", "Hebrews", 13),
        ("JAS", "Jas", "야고보서", "약", "James", 5),
        ("1PE", "1Pet", "베드로전서", "벧전", "1 Peter", 5),
        ("2PE", "2Pet", "베드로후서", "벧후", "2 Peter", 3),
        ("1JN", "1John", "요한일서", "요일", "1 John", 5),
        ("2JN", "2John", "요한이서", "요이", "2 John", 1),
        ("3JN", "3John", "요한삼서", "요삼", "3 John", 1),
        ("JUD", "Jude", "유다서", "유", "Jude", 1),
        ("REV", "Rev", "요한계시록", "계", "Revelation", 22),
    ]
}

/// 구절 위치. 숫자 아이디 = 책×1,000,000 + 장×1,000 + 절 (창 1:1 = 1001001)
public struct VerseRef: Hashable, Codable, Comparable, Sendable {
    public var book: Int
    public var chapter: Int
    public var verse: Int

    public init(book: Int, chapter: Int, verse: Int) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }

    public init(id: Int) {
        book = id / 1_000_000
        chapter = (id / 1000) % 1000
        verse = id % 1000
    }

    public var id: Int { book * 1_000_000 + chapter * 1000 + verse }

    public static func < (a: VerseRef, b: VerseRef) -> Bool { a.id < b.id }

    /// "창 1:1"
    public var shortLabel: String { "\(Bible.book(book)?.short ?? "?") \(chapter):\(verse)" }
    /// "창세기 1:1"
    public var label: String { "\(Bible.book(book)?.name ?? "?") \(chapter):\(verse)" }
}

/// 장 위치
public struct ChapterRef: Hashable, Codable, Sendable {
    public var book: Int
    public var chapter: Int

    public init(book: Int, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }

    /// "창세기 1장", 시편은 "시편 23편"
    public var label: String { "\(Bible.book(book)?.name ?? "?") \(chapter)\(book == 19 ? "편" : "장")" }

    /// 성경 전체에서 다음 장 (요한계시록 22장 다음은 없음)
    public var next: ChapterRef? {
        guard let info = Bible.book(book) else { return nil }
        if chapter < info.chapters { return ChapterRef(book: book, chapter: chapter + 1) }
        return book < 66 ? ChapterRef(book: book + 1, chapter: 1) : nil
    }

    public var previous: ChapterRef? {
        if chapter > 1 { return ChapterRef(book: book, chapter: chapter - 1) }
        guard book > 1, let prev = Bible.book(book - 1) else { return nil }
        return ChapterRef(book: book - 1, chapter: prev.chapters)
    }

    /// 성경 전체 1,189장 중 몇 번째 장인지 (0부터)
    public var globalIndex: Int {
        Bible.books.prefix(book - 1).reduce(0) { $0 + $1.chapters } + chapter - 1
    }

    public static func fromGlobalIndex(_ index: Int) -> ChapterRef? {
        var remaining = index
        for book in Bible.books {
            if remaining < book.chapters { return ChapterRef(book: book.id, chapter: remaining + 1) }
            remaining -= book.chapters
        }
        return nil
    }
}

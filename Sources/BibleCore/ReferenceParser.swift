import Foundation

/// "요3:16", "요한복음 3장 16절", "시 23", "롬 8:28-30", "John 3:16" 같은 구절 주소 읽기
public enum ReferenceParser {
    public struct Reference: Equatable {
        public let chapter: ChapterRef
        public let start: VerseRef
        public let end: VerseRef?
        public let hasVerse: Bool
    }

    private static let regex = try! NSRegularExpression(pattern: #"""
        ^\s*([1-3]?\s?[^\d\s:~-]+(?:\s[^\d\s:~-]+)*?)\s*(\d+)\s*(?:(?:[:.]|장|편)\s*(?:(\d+)\s*절?(?:\s*[-~]\s*(\d+)\s*절?)?)?)?\s*$
        """#.trimmingCharacters(in: .whitespacesAndNewlines))

    public static func parse(_ text: String) -> Reference? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func group(_ i: Int) -> String? {
            m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i))
        }
        guard let bookText = group(1), let book = Bible.findBook(bookText),
              let chapter = group(2).flatMap(Int.init), chapter >= 1, chapter <= book.chapters else { return nil }
        let chapterRef = ChapterRef(book: book.id, chapter: chapter)
        if let verse = group(3).flatMap(Int.init) {
            let start = VerseRef(book: book.id, chapter: chapter, verse: verse)
            let end = group(4).flatMap(Int.init).map { VerseRef(book: book.id, chapter: chapter, verse: $0) }
            return Reference(chapter: chapterRef, start: start, end: end, hasVerse: true)
        }
        return Reference(chapter: chapterRef, start: VerseRef(book: book.id, chapter: chapter, verse: 1), end: nil, hasVerse: false)
    }
}

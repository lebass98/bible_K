import Foundation

/// 읽어 들인 절 하나
public struct ParsedVerse: Sendable {
    public var ref: VerseRef
    public var text: String          // 꾸밈 없는 본문
    public var heading: String?      // 이 절 앞에 붙는 소제목
    public var tagged: String?       // 원어 번호가 붙은 본문 (TaggedText 형식). 없으면 nil

    public init(ref: VerseRef, text: String, heading: String? = nil, tagged: String? = nil) {
        self.ref = ref
        self.text = text
        self.heading = heading
        self.tagged = tagged
    }
}

/// 원어 번호가 붙은 본문 형식: 낱말마다 \u{1}낱말\u{2}H7225\u{3}
public enum TaggedText {
    public static let open: Character = "\u{1}"
    public static let mid: Character = "\u{2}"
    public static let close: Character = "\u{3}"

    public struct Segment: Hashable {
        public let text: String
        public let strongs: [String]   // 비어 있으면 그냥 글
    }

    public static func word(_ text: String, strongs: [String]) -> String {
        "\(open)\(text)\(mid)\(strongs.joined(separator: ","))\(close)"
    }

    public static func segments(_ tagged: String) -> [Segment] {
        var result: [Segment] = []
        var buffer = ""
        var word = ""
        var codes = ""
        var state = 0   // 0: 글, 1: 낱말, 2: 번호
        for ch in tagged {
            switch (state, ch) {
            case (0, open):
                if !buffer.isEmpty { result.append(Segment(text: buffer, strongs: [])) }
                buffer = ""; word = ""; codes = ""; state = 1
            case (1, mid): state = 2
            case (2, close):
                result.append(Segment(text: word, strongs: codes.split(separator: ",").map(String.init)))
                state = 0
            case (0, _): buffer.append(ch)
            case (1, _): word.append(ch)
            default: codes.append(ch)
            }
        }
        if !buffer.isEmpty { result.append(Segment(text: buffer, strongs: [])) }
        return result
    }

    /// "H0430" → "H430"
    public static func normalizeStrong(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard let prefix = trimmed.first, prefix == "H" || prefix == "G" else { return nil }
        let rest = trimmed.dropFirst()
        let digits = rest.prefix { $0.isNumber }
        guard let number = Int(digits) else { return nil }
        return "\(prefix)\(number)"
    }
}

// MARK: - USFM

/// USFM(성경 번역 표준 형식) 파일 읽기
public enum USFMParser {
    private static let ignoreMarkers: Set<String> = [
        "id", "ide", "h", "toc", "toca", "mt", "mte", "imt", "is", "ip", "ipi", "im", "ipr", "iot", "io", "ili", "ie",
        "rem", "cl", "cp", "ca", "va", "vp", "r", "sp", "mr", "sr", "periph", "sts", "restore", "usfm"
    ]
    private static let headingMarkers: Set<String> = ["s", "ms", "d", "qa"]
    private static let paragraphMarkers: Set<String> = [
        "p", "m", "pi", "mi", "nb", "q", "qc", "qr", "qm", "b", "li", "pc", "pmo", "pm", "pmc", "pmr", "tr",
        "th", "tc", "thr", "tcr", "cls", "lit", "po", "pr", "ph", "lh", "lf", "lim"
    ]

    /// 파일 하나(책 한 권)를 읽어 절 목록으로
    public static func parse(_ content: String) -> [ParsedVerse] {
        guard let book = bookID(in: content) else { return [] }

        var s = content
        s = replace(s, #"\\f\s.*?\\f\*"#, with: "")
        s = replace(s, #"\\fe\s.*?\\fe\*"#, with: "")
        s = replace(s, #"\\x\s.*?\\x\*"#, with: "")
        s = replace(s, #"\\fig\s.*?\\fig\*"#, with: "")
        // \w 낱말|strong="H1234"\w*  →  원어 번호 표시
        s = replaceMatches(s, #"\\\+?w\s+([^|\\]*?)(?:\|([^\\]*?))?\\\+?w\*"#) { groups in
            let word = groups[0] ?? ""
            guard let attrs = groups[1], let codes = firstMatch(attrs, #"strong\s*=\s*"([^"]*)""#) else { return word }
            let strongs = codes.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { TaggedText.normalizeStrong(String($0)) }
            return strongs.isEmpty ? word : TaggedText.word(word, strongs: strongs)
        }

        let state = ParseState(book: book)
        let markerRegex = try! NSRegularExpression(pattern: #"\\(\+?[A-Za-z]+[0-9]*\*?)"#)
        let ns = s as NSString
        var cursor = 0
        for match in markerRegex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            state.take(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length

            let raw = ns.substring(with: match.range(at: 1))
            if raw.hasSuffix("*") || raw.hasPrefix("+") { continue }   // 글자 꾸밈 표시
            let base = raw.trimmingCharacters(in: .decimalDigits)

            if state.target == .heading { state.flushHeading() }
            switch base {
            case "c":
                state.flushVerse()
                state.target = .chapterNumber
            case "v":
                state.flushVerse()
                state.target = .verseNumber
            case _ where headingMarkers.contains(base):
                state.target = .heading
            case _ where paragraphMarkers.contains(base):
                state.startParagraph()
            case _ where ignoreMarkers.contains(base):
                state.target = .discard
            default:
                continue   // 모르는 글자 꾸밈 표시: 그대로 이어서 받음
            }
        }
        state.take(ns.substring(from: cursor))
        if state.target == .heading { state.flushHeading() }
        state.flushVerse()
        return state.verses
    }

    /// 읽는 동안의 상태
    private final class ParseState {
        enum Target { case discard, heading, verse, chapterNumber, verseNumber }

        let book: Int
        var verses: [ParsedVerse] = []
        var target = Target.discard
        private var chapter = 0
        private var current: VerseRef?
        private var verseText = ""
        private var pendingHeadings: [String] = []
        private var headingBuffer = ""
        private var currentHeading: String?

        init(book: Int) { self.book = book }

        func startParagraph() {
            guard chapter > 0 else { return }   // 책 소개 부분은 버림
            if current != nil { verseText += " " }
            target = .verse
        }

        func flushHeading() {
            let heading = clean(TaggedText.plain(headingBuffer))
            if !heading.isEmpty { pendingHeadings.append(heading) }
            headingBuffer = ""
        }

        func flushVerse() {
            guard let ref = current else { return }
            let tagged = clean(verseText)
            let plain = clean(TaggedText.plain(verseText))
            if !plain.isEmpty {
                verses.append(ParsedVerse(ref: ref, text: plain, heading: currentHeading,
                                          tagged: tagged.contains(TaggedText.open) ? tagged : nil))
            }
            current = nil
            verseText = ""
            currentHeading = nil
        }

        func take(_ text: String) {
            switch target {
            case .discard: break
            case .heading: headingBuffer += text
            case .verse: if current != nil { verseText += text }
            case .chapterNumber:
                let digits = text.drop { $0 == " " }.prefix { $0.isNumber }
                if let number = Int(digits) { chapter = number }
                target = .discard
            case .verseNumber:
                let trimmed = text.drop { $0 == " " }
                let digits = trimmed.prefix { $0.isNumber }
                if let number = Int(digits), chapter > 0 {
                    current = VerseRef(book: book, chapter: chapter, verse: number)
                    currentHeading = pendingHeadings.isEmpty ? nil : pendingHeadings.joined(separator: "\n")
                    pendingHeadings = []
                    // "16-17" 같은 묶음 절 번호도 건너뜀
                    verseText = String(trimmed.drop { !$0.isWhitespace })
                }
                target = .verse
            }
        }
    }

    static func bookID(in content: String) -> Int? {
        guard let code = firstMatch(content, #"\\id\s+([A-Za-z0-9]{3})"#) else { return nil }
        return Bible.books.first { $0.usfm == code.uppercased() }?.id
    }
}

extension TaggedText {
    /// 원어 번호를 빼고 글만
    public static func plain(_ tagged: String) -> String {
        guard tagged.contains(open) else { return tagged }
        return segments(tagged).map(\.text).joined()
    }
}

// MARK: - 여러 형식 가져오기

public enum BibleImporter {
    public struct Result {
        public var verses: [ParsedVerse]
        public var suggestedName: String?
    }

    public enum ImportError: LocalizedError {
        case unknownFormat(String)
        case empty

        public var errorDescription: String? {
            switch self {
            case .unknownFormat(let name): return "\(name): 읽을 수 있는 성경 형식이 아니에요."
            case .empty: return "성경 구절을 하나도 찾지 못했어요."
            }
        }
    }

    /// 파일·폴더 여러 개를 읽어 하나의 역본으로 합침
    public static func load(urls: [URL]) throws -> Result {
        var files: [URL] = []
        var tempDirs: [URL] = []
        defer { tempDirs.forEach { try? FileManager.default.removeItem(at: $0) } }

        for url in urls {
            if url.pathExtension.lowercased() == "zip" {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                tempDirs.append(dir)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-x", "-k", url.path, dir.path]
                try process.run()
                process.waitUntilExit()
                files += allFiles(in: dir)
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                files += allFiles(in: url)
            } else {
                files.append(url)
            }
        }

        var verses: [ParsedVerse] = []
        var name: String?
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let ext = file.pathExtension.lowercased()
            guard ["usfm", "sfm", "ptx", "json", "txt", "tsv", "csv", "vpl"].contains(ext) else { continue }
            guard let content = readText(file) else { continue }
            switch ext {
            case "usfm", "sfm", "ptx":
                verses += USFMParser.parse(content)
            case "json":
                verses += try parseJSON(content, fileName: file.lastPathComponent)
            default:
                if content.contains("\\id ") && content.contains("\\v ") {
                    verses += USFMParser.parse(content)
                } else {
                    verses += parseLines(content)
                }
            }
            if name == nil, urls.count == 1 { name = urls[0].deletingPathExtension().lastPathComponent }
        }
        guard !verses.isEmpty else { throw ImportError.empty }
        return Result(verses: verses, suggestedName: name)
    }

    private static func allFiles(in dir: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        return (enumerator?.allObjects as? [URL] ?? []).filter { !$0.lastPathComponent.hasPrefix(".") }
    }

    private static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let text = String(data: data, encoding: .utf8) { return text.replacingOccurrences(of: "\u{FEFF}", with: "") }
        // 오래된 한글 파일 (EUC-KR)
        let cp949 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: cp949))
    }

    /// JSON: [{"abbrev":"gn","chapters":[["1절","2절"],…]}, …] (66권 순서)
    ///    또는 [{"book":"창","chapter":1,"verse":1,"text":"…"}, …]
    static func parseJSON(_ content: String, fileName: String) throws -> [ParsedVerse] {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            throw ImportError.unknownFormat(fileName)
        }
        var root = object
        if let dict = object as? [String: Any] {
            root = dict["books"] ?? dict["verses"] ?? dict["data"] ?? dict
        }
        guard let items = root as? [[String: Any]] else { throw ImportError.unknownFormat(fileName) }

        var verses: [ParsedVerse] = []
        if items.first?["chapters"] != nil {
            for (index, item) in items.enumerated() {
                let named = (item["name"] as? String).flatMap(Bible.findBook)
                guard let book = named?.id ?? Bible.book(index + 1)?.id,
                      let chapters = item["chapters"] as? [Any] else { continue }
                for (c, chapter) in chapters.enumerated() {
                    let lines: [String]
                    if let array = chapter as? [String] {
                        lines = array
                    } else if let dict = chapter as? [String: Any], let array = dict["verses"] as? [Any] {
                        lines = array.compactMap { ($0 as? String) ?? (($0 as? [String: Any])?["text"] as? String) }
                    } else { continue }
                    for (v, text) in lines.enumerated() where !text.isEmpty {
                        verses.append(ParsedVerse(ref: VerseRef(book: book, chapter: c + 1, verse: v + 1), text: clean(text)))
                    }
                }
            }
        } else {
            for item in items {
                let bookValue = item["book"] ?? item["book_id"] ?? item["b"]
                let book: BibleBook? = (bookValue as? Int).flatMap(Bible.book) ?? (bookValue as? String).flatMap(Bible.findBook)
                guard let book,
                      let chapter = intValue(item["chapter"] ?? item["c"]),
                      let verse = intValue(item["verse"] ?? item["v"]),
                      let text = (item["text"] ?? item["t"]) as? String else { continue }
                verses.append(ParsedVerse(ref: VerseRef(book: book.id, chapter: chapter, verse: verse), text: clean(text)))
            }
        }
        if verses.isEmpty { throw ImportError.unknownFormat(fileName) }
        return verses
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let text = value as? String { return Int(text) }
        return nil
    }

    /// 한 줄에 한 절: "창 1:1 태초에…", "GEN 1:1 In the…", "1<탭>1<탭>1<탭>태초에…", "창,1,1,태초에…"
    static func parseLines(_ content: String) -> [ParsedVerse] {
        var verses: [ParsedVerse] = []
        let refLine = try! NSRegularExpression(pattern: #"^\s*([1-3]?\s?[^\d\s:,\t]+?)\s*(\d+)\s*[:장.]\s*(\d+)절?\s+(.+)$"#)
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            for separator in ["\t", ","] {
                let parts = line.components(separatedBy: separator)
                if parts.count >= 4, let book = Bible.findBook(parts[0].trimmingCharacters(in: .init(charactersIn: "\" "))),
                   let chapter = Int(parts[1].trimmingCharacters(in: .init(charactersIn: "\" "))),
                   let verse = Int(parts[2].trimmingCharacters(in: .init(charactersIn: "\" "))) {
                    var text = parts[3...].joined(separator: separator)
                    if separator == "," { text = text.trimmingCharacters(in: .init(charactersIn: "\"")) }
                    verses.append(ParsedVerse(ref: VerseRef(book: book.id, chapter: chapter, verse: verse), text: clean(text)))
                    break
                }
                if separator == "," {
                    let ns = line as NSString
                    if let m = refLine.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
                       let book = Bible.findBook(ns.substring(with: m.range(at: 1))),
                       let chapter = Int(ns.substring(with: m.range(at: 2))),
                       let verse = Int(ns.substring(with: m.range(at: 3))) {
                        verses.append(ParsedVerse(ref: VerseRef(book: book.id, chapter: chapter, verse: verse),
                                                  text: clean(ns.substring(with: m.range(at: 4)))))
                    }
                }
            }
        }
        return verses
    }
}

// MARK: - 글 다듬기 도구

func clean(_ text: String) -> String {
    text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func replace(_ text: String, _ pattern: String, with template: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return text }
    return regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: template)
}

func firstMatch(_ text: String, _ pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
          match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
    return (text as NSString).substring(with: match.range(at: 1))
}

func replaceMatches(_ text: String, _ pattern: String, transform: ([String?]) -> String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return text }
    let ns = text as NSString
    var result = ""
    var cursor = 0
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
        let groups = (1..<match.numberOfRanges).map { i -> String? in
            let range = match.range(at: i)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
        result += transform(groups)
        cursor = match.range.location + match.range.length
    }
    result += ns.substring(from: cursor)
    return result
}

import BibleCore
import Foundation

// 앱에 넣을 성경 DB 만들기 (공개 저작물·자유 이용 허락 데이터만)
// 사용법: swift run BibleBuilder <내려받은 자료 폴더> <만들 DB 경로>
//   자료 폴더에 있어야 하는 것 (scripts/fetch_data.sh가 내려받음):
//     kor/, eng-kjv2006/, engwebp/       eBible.org USFM
//     strongs-hebrew.js, strongs-greek.js  OpenScriptures Strong's 사전
//     xref/cross_references.txt          OpenBible.info 관주

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("사용법: BibleBuilder <자료 폴더> <만들 DB 경로>")
    exit(1)
}
let raw = URL(fileURLWithPath: args[1])
let output = args[2]
try? FileManager.default.removeItem(atPath: output)
let database = try BibleDatabase(path: output, readOnly: false)

// MARK: 역본

struct Source {
    let folder: String
    let translation: BibleTranslation
    let fix: (String) -> String
}

/// 한글 공개본의 따옴표·느낌표 표기 다듬기 (`말' → ‘말’, "하라 !" → "하라!")
func fixKorean(_ text: String) -> String {
    var s = text
    s = s.replacingOccurrences(of: "`", with: "‘")
    s = s.replacingOccurrences(of: "'", with: "’")
    s = s.replacingOccurrences(of: " !", with: "!")
    s = s.replacingOccurrences(of: " ?", with: "?")
    return s
}

let sources = [
    Source(folder: "kor", translation: BibleTranslation(
        id: "kor", name: "한글 성경 (공개본)", short: "한글", language: "ko",
        license: "퍼블릭 도메인", source: "eBible.org ‘Korean Bible 1910’ (kor)"), fix: fixKorean),
    Source(folder: "eng-kjv2006", translation: BibleTranslation(
        id: "kjv", name: "King James Version", short: "KJV", language: "en",
        license: "퍼블릭 도메인", source: "eBible.org (eng-kjv2006)", hasStrongs: true),
        fix: { $0.replacingOccurrences(of: "¶ ", with: "").replacingOccurrences(of: "¶", with: "") }),
    Source(folder: "engwebp", translation: BibleTranslation(
        id: "web", name: "World English Bible", short: "WEB", language: "en",
        license: "퍼블릭 도메인", source: "eBible.org (engwebp)", hasStrongs: true), fix: { $0 }),
]

for (index, source) in sources.enumerated() {
    let folder = raw.appendingPathComponent(source.folder)
    let files = (try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
        .filter { ["usfm", "sfm"].contains($0.pathExtension.lowercased()) }
    var verses: [ParsedVerse] = []
    for file in files {
        verses += USFMParser.parse(try String(contentsOf: file, encoding: .utf8))
    }
    verses = verses.map { verse in
        var v = verse
        v.text = source.fix(v.text)
        v.tagged = v.tagged.map(source.fix)
        v.heading = v.heading.map(source.fix)
        return v
    }
    database.saveTranslation(source.translation, sort: index)
    try database.saveVerses(verses, translation: source.translation.id)
    print("역본 \(source.translation.short): \(verses.count)절 (원어 번호 붙은 절 \(verses.filter { $0.tagged != nil }.count))")
}

// MARK: Strong's 사전

func loadStrongs(_ file: String) throws -> [String: [String: String]] {
    let text = try String(contentsOf: raw.appendingPathComponent(file), encoding: .utf8)
    guard let start = text.range(of: "= {")?.upperBound, let end = text.range(of: "};", options: .backwards)?.lowerBound else { return [:] }
    let json = "{" + text[start..<end] + "}"
    let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [String: Any]] ?? [:]
    return object.mapValues { $0.compactMapValues { $0 as? String } }
}

var strongCount = 0
try database.db.transaction {
    let stmt = try database.db.prepare("INSERT OR REPLACE INTO strongs VALUES(?,?,?,?,?,?,?)")
    for file in ["strongs-hebrew.js", "strongs-greek.js"] {
        for (key, entry) in try loadStrongs(file) {
            guard let id = TaggedText.normalizeStrong(key) else { continue }
            stmt.bind([id, entry["lemma"] ?? "", entry["xlit"] ?? entry["translit"] ?? "", entry["pron"] ?? "",
                       (entry["strongs_def"] ?? "").trimmingCharacters(in: .whitespaces), entry["kjv_def"] ?? "",
                       entry["derivation"] ?? ""])
            stmt.stepDone()
            strongCount += 1
        }
    }
}
print("원어 사전: \(strongCount)개")

// MARK: 관주 (OpenBible.info, 추천 3표 이상만)

func osisRef(_ text: Substring) -> VerseRef? {
    let parts = text.split(separator: ".")
    guard parts.count == 3, let book = Bible.books.first(where: { $0.osis == parts[0] }),
          let chapter = Int(parts[1]), let verse = Int(parts[2]) else { return nil }
    return VerseRef(book: book.id, chapter: chapter, verse: verse)
}

var xrefCount = 0
let xrefText = try String(contentsOf: raw.appendingPathComponent("xref/cross_references.txt"), encoding: .utf8)
try database.db.transaction {
    let stmt = try database.db.prepare("INSERT INTO xrefs VALUES(?,?,?,?)")
    for line in xrefText.split(separator: "\n").dropFirst() {
        let cols = line.split(separator: "\t")
        guard cols.count >= 3, let votes = Int(cols[2]), votes >= 3, let src = osisRef(cols[0]) else { continue }
        let range = cols[1].split(separator: "-")
        guard let dst = osisRef(range[0]) else { continue }
        let end = range.count > 1 ? osisRef(range[1]) : nil
        stmt.bind([src.id, dst.id, end?.id ?? 0, votes])
        stmt.stepDone()
        xrefCount += 1
    }
}
print("관주: \(xrefCount)개")

let formatter = ISO8601DateFormatter()
database.db.run("INSERT OR REPLACE INTO meta VALUES('built', ?)", [formatter.string(from: Date())])
try database.db.exec("VACUUM")
print("완료: \(output)")

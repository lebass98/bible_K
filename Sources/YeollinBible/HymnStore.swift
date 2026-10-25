import AppKit
import Foundation
import Observation

/// 찬송가 한 곡
struct Hymn: Codable, Identifiable, Hashable {
    var number: Int
    var title: String
    var section: String?
    var lyrics: String?
    var image: String?      // 폴더 안의 악보 파일 이름
    var id: Int { number }

    var label: String { "\(number)장 \(title)" }
}

/// 사용자가 가져온 찬송가 (앱에는 찬송가 데이터가 들어 있지 않음)
/// ~/Library/Application Support/YeollinBible/Hymns 에 악보 파일과 hymns.json 을 둠
@Observable
final class HymnStore {
    private(set) var hymns: [Hymn] = []
    private(set) var name = ""

    static let folder = UserStore.folder.appendingPathComponent("Hymns", isDirectory: true)
    private static let indexFile = folder.appendingPathComponent("hymns.json")
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "tif", "tiff", "heic", "webp", "pdf"]

    private struct Index: Codable {
        var name: String?
        var hymns: [Hymn]
    }

    init() { load() }

    var isEmpty: Bool { hymns.isEmpty }

    func load() {
        guard let data = try? Data(contentsOf: Self.indexFile),
              let index = Self.decodeIndex(data) else {
            hymns = []
            name = ""
            return
        }
        hymns = index.hymns.sorted { $0.number < $1.number }
        name = index.name ?? "찬송가"
    }

    func hymn(_ number: Int) -> Hymn? { hymns.first { $0.number == number } }

    func imageURL(_ hymn: Hymn) -> URL? {
        guard let file = hymn.image else { return nil }
        let url = Self.folder.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 번호·제목·가사로 찾기 (띄어쓰기 무시)
    func search(_ query: String) -> [Hymn] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return hymns }
        if let number = Int(text.replacingOccurrences(of: "장", with: "")) {
            let exact = hymns.filter { $0.number == number }
            let prefix = hymns.filter { $0.number != number && String($0.number).hasPrefix(String(number)) }
            return exact + prefix
        }
        let key = text.replacingOccurrences(of: " ", with: "")
        let titled = hymns.filter { $0.title.replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(key) }
        let lyric = hymns.filter { hymn in
            !titled.contains(hymn)
                && (hymn.lyrics ?? "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
                    .localizedCaseInsensitiveContains(key)
        }
        return titled + lyric
    }

    // MARK: 가져오기

    enum ImportError: LocalizedError {
        case noImages
        var errorDescription: String? { "폴더에서 번호가 붙은 악보 파일(예: 305.png)을 찾지 못했어요." }
    }

    /// 폴더를 통째로 가져와 지금 찬송가를 바꿈. 가져온 곡 수를 돌려줌
    /// - 폴더에 hymns.json 이 있으면 번호·제목·가사·파일 이름을 그대로 씀
    /// - 없으면 파일 이름의 첫 숫자를 장 번호로 씀 (1.png, 001.jpg, hymn305.png, "305 나 같은 죄인.pdf")
    static func importFolder(_ source: URL) throws -> Int {
        let fm = FileManager.default
        let files = (try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil))
            .filter { !$0.lastPathComponent.hasPrefix(".") }
        let images = files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        guard !images.isEmpty else { throw ImportError.noImages }

        var hymns: [Hymn]
        var name = source.lastPathComponent
        if let data = try? Data(contentsOf: source.appendingPathComponent("hymns.json")), let index = decodeIndex(data) {
            hymns = index.hymns
            name = index.name ?? name
        } else {
            hymns = images.compactMap { url -> Hymn? in
                let base = url.deletingPathExtension().lastPathComponent
                guard let range = base.range(of: #"\d+"#, options: .regularExpression), let number = Int(base[range]) else { return nil }
                let rest = base[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " _-.장"))
                return Hymn(number: number, title: rest.isEmpty ? "\(number)장" : rest, section: nil, lyrics: nil,
                            image: url.lastPathComponent)
            }
        }
        // 파일 이름이 없는 곡은 번호로 맞는 파일을 찾아 줌
        let byNumber = Dictionary(images.compactMap { url -> (Int, String)? in
            let base = url.deletingPathExtension().lastPathComponent
            guard let range = base.range(of: #"\d+"#, options: .regularExpression), let n = Int(base[range]) else { return nil }
            return (n, url.lastPathComponent)
        }, uniquingKeysWith: { a, _ in a })
        for index in hymns.indices where hymns[index].image == nil || !fm.fileExists(atPath: source.appendingPathComponent(hymns[index].image!).path) {
            hymns[index].image = byNumber[hymns[index].number]
        }

        // 새 폴더에 복사한 뒤 바꿔치기 (중간에 실패해도 예전 찬송가는 남음)
        let staging = UserStore.folder.appendingPathComponent("Hymns-importing", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        for file in Set(hymns.compactMap(\.image)) {
            try fm.copyItem(at: source.appendingPathComponent(file), to: staging.appendingPathComponent(file))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(Index(name: name, hymns: hymns.sorted { $0.number < $1.number }))
            .write(to: staging.appendingPathComponent("hymns.json"))
        try? fm.removeItem(at: folder)
        try fm.moveItem(at: staging, to: folder)
        return hymns.count
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: Self.folder)
        load()
    }

    private static func decodeIndex(_ data: Data) -> Index? {
        let decoder = JSONDecoder()
        if let index = try? decoder.decode(Index.self, from: data) { return index }
        if let list = try? decoder.decode([Hymn].self, from: data) { return Index(name: nil, hymns: list) }
        return nil
    }
}

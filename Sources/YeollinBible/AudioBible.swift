import AVFoundation
import BibleCore
import Foundation
import Observation

/// 녹음된 오디오 성경 듣기 (장마다 음원 파일 하나)
/// 앱에는 음원이 들어 있지 않음. 사용자가 음원 폴더를 정하면 그 안의 파일을 찾아 씀
/// - 파일 이름: 음원 약자 2글자 + 책 2자리 + 장 3자리 (예: rv43003.mp3 = rv 음원의 요한복음 3장)
/// - 같은 폴더(또는 앱 저장 위치 Audio/)의 timings.json 이 있으면 절마다 시작 시각을 알아서 읽는 절을 표시함
///   {"sets": {"rv": {"name": "…", "translation": "역본 아이디"}}, "timings": {"rv43003": {"1": 0.0, "2": 9.3}}}
@Observable
final class AudioBible: NSObject, AVAudioPlayerDelegate {
    struct AudioSet: Codable, Hashable {
        var name: String
        var translation: String?
    }

    // MARK: 설정

    static let defaultFolder = UserStore.folder.appendingPathComponent("Audio", isDirectory: true)

    var folder: URL {
        didSet {
            UserDefaults.standard.set(folder.path, forKey: "audioFolder")
            reload()
        }
    }
    /// 녹음 음원이 있으면 기계 음성 대신 먼저 들려줌
    var preferRecorded: Bool = UserDefaults.standard.object(forKey: "audioPreferRecorded") as? Bool ?? true {
        didSet { UserDefaults.standard.set(preferRecorded, forKey: "audioPreferRecorded") }
    }
    var rate: Double = UserDefaults.standard.object(forKey: "audioRate") as? Double ?? 1.0 {
        didSet {
            UserDefaults.standard.set(rate, forKey: "audioRate")
            player?.rate = Float(rate)
        }
    }
    /// 역본마다 고른 음원 약자 (역본 아이디 → 약자)
    var chosenSet: [String: String] = UserDefaults.standard.dictionary(forKey: "audioChosenSet") as? [String: String] ?? [:] {
        didSet { UserDefaults.standard.set(chosenSet, forKey: "audioChosenSet") }
    }

    // MARK: 찾은 음원

    private(set) var files: [String: URL] = [:]            // "rv43003" → 파일
    private(set) var sets: [String: AudioSet] = [:]        // "rv" → 이름
    @ObservationIgnored private var timings: [String: [Int: Double]] = [:]

    // MARK: 재생 상태

    private(set) var chapter: ChapterRef?
    private(set) var prefix: String?
    private(set) var currentVerse: VerseRef?
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var lastError: String?
    var isActive: Bool { chapter != nil }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    /// 장 끝까지 들으면 부름 (다음 장으로 넘어가기)
    @ObservationIgnored var onFinished: (() -> Void)?

    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif"]

    override init() {
        let saved = UserDefaults.standard.string(forKey: "audioFolder")
        folder = saved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
        super.init()
        try? FileManager.default.createDirectory(at: Self.defaultFolder, withIntermediateDirectories: true)
        reload()
    }

    /// 폴더를 다시 훑어 음원과 시각표를 찾음
    func reload() {
        var found: [String: URL] = [:]
        let pattern = try! NSRegularExpression(pattern: #"^([a-z]{2})(\d{2})(\d{3})$"#)
        for root in Set([folder, Self.defaultFolder]) {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                                  options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator where Self.audioExtensions.contains(url.pathExtension.lowercased()) {
                let stem = url.deletingPathExtension().lastPathComponent.lowercased()
                if pattern.firstMatch(in: stem, range: NSRange(location: 0, length: (stem as NSString).length)) != nil,
                   found[stem] == nil {
                    found[stem] = url
                }
            }
        }
        files = found

        var loadedSets: [String: AudioSet] = [:]
        var loadedTimings: [String: [Int: Double]] = [:]
        for root in [folder, Self.defaultFolder] {
            guard let data = try? Data(contentsOf: root.appendingPathComponent("timings.json")),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for (key, value) in json["sets"] as? [String: [String: String]] ?? [:] where loadedSets[key] == nil {
                loadedSets[key] = AudioSet(name: value["name"] ?? key, translation: value["translation"])
            }
            for (name, table) in json["timings"] as? [String: [String: Double]] ?? [:] where loadedTimings[name] == nil {
                var verses: [Int: Double] = [:]
                for (verse, time) in table { if let v = Int(verse) { verses[v] = time } }
                loadedTimings[name] = verses
            }
        }
        // 시각표에 없는 약자도 음원이 있으면 목록에 넣음
        for stem in found.keys {
            let key = String(stem.prefix(2))
            if loadedSets[key] == nil { loadedSets[key] = AudioSet(name: key.uppercased(), translation: nil) }
        }
        sets = loadedSets
        timings = loadedTimings
        DebugLog.write("오디오 성경: 음원 \(found.count)개, 시각표 \(loadedTimings.count)장 — \(folder.path)")
    }

    static func stem(_ prefix: String, _ chapter: ChapterRef) -> String {
        String(format: "%@%02d%03d", prefix, chapter.book, chapter.chapter)
    }

    /// 이 장의 음원이 있는 약자들
    func availablePrefixes(for chapter: ChapterRef) -> [String] {
        sets.keys.filter { files[Self.stem($0, chapter)] != nil }.sorted()
    }

    /// 역본에 맞는 음원: 고른 것 → 짝 역본 → 아무거나
    func preferredPrefix(translation: String, chapter: ChapterRef) -> String? {
        let available = availablePrefixes(for: chapter)
        guard !available.isEmpty else { return nil }
        if let chosen = chosenSet[translation], available.contains(chosen) { return chosen }
        if let matched = available.first(where: { sets[$0]?.translation == translation }) { return matched }
        return available.first
    }

    func hasTimings(_ prefix: String, _ chapter: ChapterRef) -> Bool { timings[Self.stem(prefix, chapter)] != nil }

    var counts: [(prefix: String, name: String, files: Int)] {
        sets.keys.sorted().map { key in
            (key, sets[key]?.name ?? key, files.keys.filter { $0.hasPrefix(key) }.count)
        }
    }

    // MARK: 재생

    func play(_ chapter: ChapterRef, prefix: String, from verse: Int? = nil) {
        guard let url = files[Self.stem(prefix, chapter)] else { return }
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.rate = Float(rate)
            player.prepareToPlay()
            self.player = player
            self.chapter = chapter
            self.prefix = prefix
            duration = player.duration
            if let verse, let start = startTime(of: verse) { player.currentTime = start }
            player.play()
            isPlaying = true
            lastError = nil
            startTimer()
            tick()
        } catch {
            lastError = "음원을 열지 못했어요: \(url.lastPathComponent)"
            DebugLog.write("오디오 재생 실패 \(url.path): \(error)")
        }
    }

    func togglePause() {
        guard let player else { return }
        if player.isPlaying { player.pause(); isPlaying = false } else { player.play(); isPlaying = true }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
        chapter = nil
        prefix = nil
        currentVerse = nil
        currentTime = 0
        duration = 0
    }

    func seek(to time: Double) {
        player?.currentTime = max(0, min(time, duration))
        tick()
    }

    /// 절로 건너뛰기 (시각표가 있을 때)
    func seek(toVerse verse: Int) {
        guard let start = startTime(of: verse) else { return }
        seek(to: start)
    }

    func step(verses delta: Int) {
        guard let current = currentVerse?.verse else { return }
        seek(toVerse: max(1, current + delta))
    }

    private func startTime(of verse: Int) -> Double? {
        guard let prefix, let chapter, let table = timings[Self.stem(prefix, chapter)] else { return nil }
        return table[verse]
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let player, let chapter, let prefix else { return }
        currentTime = player.currentTime
        guard let table = timings[Self.stem(prefix, chapter)] else { return }
        // 지금 시각보다 앞에서 시작한 절 가운데 마지막 절
        let verse = table.filter { $0.value <= player.currentTime + 0.05 }.max { $0.value < $1.value }?.key ?? 1
        let ref = VerseRef(book: chapter.book, chapter: chapter.chapter, verse: verse)
        if currentVerse != ref { currentVerse = ref }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.onFinished?()
        }
    }
}

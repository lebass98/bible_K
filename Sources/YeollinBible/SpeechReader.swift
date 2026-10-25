import AVFoundation
import BibleCore
import Foundation
import Observation

/// 읽어 줄 목소리 종류
enum SpeechEngine: String, CaseIterable, Identifiable {
    case google, system
    var id: String { rawValue }
    var title: String { self == .google ? "구글 음성 (Google Cloud TTS)" : "맥 음성" }
}

/// 본문 읽어 주기 (한 절씩 읽고, 읽는 절을 화면에 표시)
/// 구글 음성을 고르고 API 키가 있으면 구글 TTS, 아니면 맥에 들어 있는 음성
@Observable
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private(set) var current: VerseRef?
    private(set) var isSpeaking = false
    /// 구글 음성이 실패해서 맥 음성으로 읽을 때 등 알려 줄 말
    var lastError: String?

    var engine: SpeechEngine = SpeechEngine(rawValue: UserDefaults.standard.string(forKey: "speechEngine") ?? "") ?? .google {
        didSet { UserDefaults.standard.set(engine.rawValue, forKey: "speechEngine") }
    }
    /// 맥 음성 빠르기 (0.3~0.65)
    var rate: Double = UserDefaults.standard.object(forKey: "speechRate") as? Double ?? 0.48 {
        didSet { UserDefaults.standard.set(rate, forKey: "speechRate") }
    }
    /// 구글 음성 빠르기 (1.0이 보통)
    var googleRate: Double = UserDefaults.standard.object(forKey: "googleRate") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(googleRate, forKey: "googleRate") }
    }
    /// 언어별 구글 목소리 이름 (비어 있으면 구글이 고르는 기본 목소리)
    var googleVoices: [String: String] = UserDefaults.standard.dictionary(forKey: "googleVoices") as? [String: String] ?? [:] {
        didSet { UserDefaults.standard.set(googleVoices, forKey: "googleVoices") }
    }
    /// 장 끝에 오면 다음 장으로 넘어가서 계속 읽음
    var continueToNextChapter: Bool = UserDefaults.standard.object(forKey: "speechContinue") as? Bool ?? true {
        didSet { UserDefaults.standard.set(continueToNextChapter, forKey: "speechContinue") }
    }

    var usesGoogle: Bool { engine == .google && APIKeyStore.hasKey }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var queue: [VerseRow] = []
    @ObservationIgnored private var language = "ko"
    /// 멈추거나 새로 읽기 시작하면 바뀜 — 늦게 도착한 음성은 버림
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var previewing = false
    @ObservationIgnored private var downloads: [Int: Task<Data, Error>] = [:]
    /// 장을 다 읽었을 때 다음 장 본문을 달라고 부름
    @ObservationIgnored var onChapterFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ verses: [VerseRow], language: String, from start: VerseRef? = nil) {
        stopSpeaking(clearState: false)
        self.language = language
        previewing = false
        queue = verses.filter { start == nil || $0.ref >= start! }
        isSpeaking = !queue.isEmpty
        lastError = nil
        speakNext()
    }

    func stop() { stopSpeaking(clearState: true) }

    /// 설정 화면의 "들어 보기"
    func preview(_ text: String, language: String) {
        speak([VerseRow(ref: VerseRef(book: 0, chapter: 0, verse: 0), text: text, heading: nil, tagged: nil)], language: language)
        previewing = true
    }

    private func stopSpeaking(clearState: Bool) {
        generation += 1
        queue = []
        downloads.values.forEach { $0.cancel() }
        downloads = [:]
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        if clearState {
            isSpeaking = false
            current = nil
        }
    }

    private func speakNext() {
        guard !queue.isEmpty else {
            let wasSpeaking = isSpeaking
            current = nil
            isSpeaking = false
            if wasSpeaking, !previewing, continueToNextChapter, let next = onChapterFinished { next() }
            return
        }
        let verse = queue.removeFirst()
        current = verse.ref.book == 0 ? nil : verse.ref
        guard usesGoogle else {
            speakWithSystem(verse)
            return
        }
        let task = download(verse)
        queue.prefix(2).forEach { _ = download($0) }   // 다음 절을 미리 받아 둠
        let ticket = generation
        Task { @MainActor in
            do {
                let audio = try await task.value
                guard ticket == self.generation else { return }
                self.downloads[verse.ref.id] = nil
                let player = try AVAudioPlayer(data: audio)
                player.delegate = self
                self.player = player
                player.play()
            } catch {
                guard ticket == self.generation else { return }
                self.downloads[verse.ref.id] = nil
                self.lastError = "구글 음성 오류: \(error.localizedDescription) — 맥 음성으로 읽어요."
                DebugLog.write(self.lastError ?? "")
                self.speakWithSystem(verse)
            }
        }
    }

    private func download(_ verse: VerseRow) -> Task<Data, Error> {
        if let existing = downloads[verse.ref.id] { return existing }
        let language = language
        let voice = googleVoices[language] ?? ""
        let rate = googleRate
        let task = Task { try await GoogleTTS.synthesize(text: verse.text, language: language, voice: voice, rate: rate) }
        downloads[verse.ref.id] = task
        return task
    }

    private func speakWithSystem(_ verse: VerseRow) {
        let code: String
        switch language {
        case "ko": code = "ko-KR"
        case "en": code = "en-US"
        default: code = AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(language) }?.language ?? language
        }
        let utterance = AVSpeechUtterance(string: verse.text)
        utterance.voice = AVSpeechSynthesisVoice(language: code)
        utterance.rate = Float(rate)
        utterance.postUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    private func finishedOne() {
        let ticket = generation
        // 절 사이에 잠깐 쉼
        DispatchQueue.main.asyncAfter(deadline: .now() + (usesGoogle ? 0.25 : 0)) { [weak self] in
            guard let self, self.isSpeaking, ticket == self.generation else { return }
            self.speakNext()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.finishedOne() }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in self?.finishedOne() }
    }
}

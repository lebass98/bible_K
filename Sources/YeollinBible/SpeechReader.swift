import AVFoundation
import BibleCore
import Foundation
import Observation

/// 맥에 들어 있는 음성으로 본문 읽어 주기 (한 절씩 읽고, 읽는 절을 화면에 표시)
@Observable
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var current: VerseRef?
    private(set) var isSpeaking = false
    var rate: Double = UserDefaults.standard.object(forKey: "speechRate") as? Double ?? 0.48 {
        didSet { UserDefaults.standard.set(rate, forKey: "speechRate") }
    }
    /// 장 끝에 오면 다음 장으로 넘어가서 계속 읽음
    var continueToNextChapter: Bool = UserDefaults.standard.object(forKey: "speechContinue") as? Bool ?? true {
        didSet { UserDefaults.standard.set(continueToNextChapter, forKey: "speechContinue") }
    }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var queue: [VerseRow] = []
    @ObservationIgnored private var language = "ko-KR"
    /// 장을 다 읽었을 때 다음 장 본문을 달라고 부름
    @ObservationIgnored var onChapterFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ verses: [VerseRow], language: String, from start: VerseRef? = nil) {
        stopSpeaking(clearState: false)
        switch language {
        case "ko": self.language = "ko-KR"
        case "en": self.language = "en-US"
        default:
            self.language = AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(language) }?.language ?? language
        }
        queue = verses.filter { start == nil || $0.ref >= start! }
        isSpeaking = !queue.isEmpty
        speakNext()
    }

    func stop() { stopSpeaking(clearState: true) }

    private func stopSpeaking(clearState: Bool) {
        queue = []
        synthesizer.stopSpeaking(at: .immediate)
        if clearState {
            isSpeaking = false
            current = nil
        }
    }

    private func speakNext() {
        guard !queue.isEmpty else {
            current = nil
            if isSpeaking, continueToNextChapter, let next = onChapterFinished {
                next()
            } else {
                isSpeaking = false
            }
            return
        }
        let verse = queue.removeFirst()
        current = verse.ref
        let utterance = AVSpeechUtterance(string: verse.text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = Float(rate)
        utterance.postUtteranceDelay = 0.15
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isSpeaking else { return }
            self.speakNext()
        }
    }
}

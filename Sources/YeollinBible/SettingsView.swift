import BibleCore
import SwiftUI

/// 설정 창 (⌘,)
struct SettingsView: View {
    var body: some View {
        TabView {
            TextSettings().tabItem { Label("본문", systemImage: "text.alignleft") }
            FontSettings().tabItem { Label("글꼴", systemImage: "textformat") }
            SpeechSettings().tabItem { Label("읽어 주기", systemImage: "speaker.wave.2") }
            ReminderSettings().tabItem { Label("알림", systemImage: "bell") }
        }
        .frame(width: 560, height: 640)
    }
}

private struct TextSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            SwiftUI.Section("글자") {
                FontSizeControl()
                LabeledContent("줄 간격") {
                    Slider(value: $model.lineSpacing, in: 0...16, step: 1)
                }
                Toggle("소제목 보기", isOn: $model.showHeadings)
                Toggle("절 번호 보기", isOn: $model.showVerseNumbers)
            }
            SwiftUI.Section("미리 보기") {
                Text("하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 저를 믿는 자마다 멸망치 않고 영생을 얻게 하려 하심이니라")
                    .font(model.textFont(language: "ko"))
                    .lineSpacing(model.lineSpacing)
                Text("For God so loved the world, that he gave his only begotten Son.")
                    .font(model.textFont(language: "en"))
                    .lineSpacing(model.lineSpacing)
            }
            SwiftUI.Section("역본") {
                Picker("읽을 역본", selection: $model.primaryID) {
                    ForEach(model.translations) { Text($0.name).tag($0.id) }
                }
                Picker("대역 역본", selection: Binding(get: { model.secondaryID ?? "" }, set: { model.secondaryID = $0 })) {
                    ForEach(model.translations) { Text($0.name).tag($0.id) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct FontSettings: View {
    @Environment(AppModel.self) private var model
    @Local private var latin = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $latin) {
                Text("본문 글꼴: \(FontLibrary.displayName(model.fontFamily))").tag(false)
                Text("영어 역본: \(FontLibrary.displayName(model.latinFontFamily))").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if latin {
                FontPickerList(selection: $model.latinFontFamily, includeSameAsBody: true,
                               sample: "In the beginning God created the heaven and the earth.")
            } else {
                FontPickerList(selection: $model.fontFamily)
            }
            Text("맥에 설치된 글꼴을 모두 쓸 수 있어요. ‘글꼴 파일 추가’로 넣은 글꼴은 이 앱에서만 쓰여요.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

private struct SpeechSettings: View {
    @Environment(AppModel.self) private var model
    @Local private var keyInput = ""
    @Local private var hasKey = APIKeyStore.hasKey
    @Local private var voices: [String: [GoogleTTS.Voice]] = [:]
    @Local private var loading = false
    @Local private var status: String?
    @Local private var cacheSize = 0

    var body: some View {
        @Bindable var speech = model.speech
        Form {
            SwiftUI.Section {
                Picker("목소리", selection: $speech.engine) {
                    ForEach(SpeechEngine.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Toggle("장이 끝나면 다음 장 이어 읽기", isOn: $speech.continueToNextChapter)
            }

            if speech.engine == .google {
                SwiftUI.Section {
                    if hasKey {
                        LabeledContent("API 키") {
                            HStack {
                                Text("저장됨 ••••\(String((APIKeyStore.load() ?? "").suffix(4)))").foregroundStyle(.secondary)
                                Button("지우기", role: .destructive) {
                                    APIKeyStore.delete()
                                    hasKey = false
                                    voices = [:]
                                }
                            }
                        }
                    } else {
                        SecureField("API 키", text: $keyInput)
                        Button("저장") {
                            let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty else { return }
                            hasKey = APIKeyStore.save(key)
                            keyInput = ""
                            status = hasKey ? "키를 키체인에 저장했어요." : "키를 저장하지 못했어요."
                            if hasKey { loadVoices() }
                        }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("""
                    Google Cloud 콘솔에서 Text-to-Speech API를 켜고 API 키를 만들어 넣으세요. \
                    키는 맥 키체인에 저장돼요. 매달 무료 사용량이 있고, 넘으면 Google Cloud 요금이 나와요. \
                    한 번 읽은 절은 이 Mac에 저장해 두고 다시 요청하지 않아요.
                    """)
                    .font(.caption).foregroundStyle(.secondary)
                    Link("Text-to-Speech API 켜기 (Google Cloud 콘솔)",
                         destination: URL(string: "https://console.cloud.google.com/apis/library/texttospeech.googleapis.com")!)
                        .font(.caption)
                } header: {
                    Text("구글 API 키")
                }

                SwiftUI.Section {
                    voicePicker("한국어 목소리", language: "ko", sample: "여호와는 나의 목자시니 내가 부족함이 없으리로다")
                    voicePicker("영어 목소리", language: "en", sample: "The LORD is my shepherd; I shall not want.")
                    LabeledContent("빠르기") {
                        HStack {
                            Slider(value: $speech.googleRate, in: 0.6...1.6, step: 0.05)
                            Text(String(format: "%.2f배", speech.googleRate)).monospacedDigit().frame(width: 52)
                        }
                    }
                    HStack {
                        Button(loading ? "불러오는 중…" : "목소리 목록 불러오기", action: loadVoices)
                            .disabled(!hasKey || loading)
                        Spacer()
                        Text("저장해 둔 음성 \(ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .file))")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("비우기") {
                            GoogleTTS.clearCache()
                            cacheSize = 0
                        }
                    }
                } header: {
                    Text("구글 목소리")
                }
            } else {
                SwiftUI.Section("맥 음성") {
                    LabeledContent("빠르기") {
                        Slider(value: $speech.rate, in: 0.3...0.65)
                    }
                    Button("들어 보기") { model.speech.preview("여호와는 나의 목자시니 내가 부족함이 없으리로다", language: "ko") }
                    Text("더 자연스러운 한국어 음성은 시스템 설정 › 손쉬운 사용 › 읽기 및 말하기에서 내려받을 수 있어요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let message = status ?? speech.lastError {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            cacheSize = GoogleTTS.cacheSize()
            if hasKey && voices.isEmpty { loadVoices() }
        }
    }

    private func voicePicker(_ title: String, language: String, sample: String) -> some View {
        @Bindable var speech = model.speech
        let list = voices[language] ?? []
        let selected = Binding(get: { speech.googleVoices[language] ?? "" }, set: { speech.googleVoices[language] = $0 })
        return HStack {
            Picker(title, selection: selected) {
                Text("기본 (구글이 고름)").tag("")
                ForEach(list) { Text($0.label).tag($0.name) }
                // 목록을 아직 못 불러왔어도 고른 값은 보이게
                if !selected.wrappedValue.isEmpty, !list.contains(where: { $0.name == selected.wrappedValue }) {
                    Text(selected.wrappedValue).tag(selected.wrappedValue)
                }
            }
            Button("들어 보기") {
                model.speech.preview(sample, language: language)
            }
            .disabled(!hasKey)
        }
    }

    private func loadVoices() {
        loading = true
        status = nil
        Task { @MainActor in
            do {
                async let ko = GoogleTTS.voices(language: "ko")
                async let en = GoogleTTS.voices(language: "en")
                voices = ["ko": try await ko, "en": try await en]
                status = "목소리 \(voices["ko"]?.count ?? 0)개(한국어), \(voices["en"]?.count ?? 0)개(영어)를 불러왔어요."
            } catch {
                status = error.localizedDescription
            }
            loading = false
        }
    }
}

private struct ReminderSettings: View {
    var body: some View {
        Form {
            SwiftUI.Section("매일 알림") {
                ReminderToggle(kind: .plan)
                ReminderToggle(kind: .dailyVerse)
            }
        }
        .formStyle(.grouped)
    }
}

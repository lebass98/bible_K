import BibleCore
import SwiftUI

/// 설정 창 (⌘,)
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var speech = model.speech
        Form {
            SwiftUI.Section("본문") {
                Picker("글꼴", selection: $model.serif) {
                    Text("명조").tag(true)
                    Text("고딕").tag(false)
                }
                .pickerStyle(.segmented)
                LabeledContent("글자 크기") {
                    HStack {
                        Slider(value: $model.fontSize, in: 12...36, step: 1)
                        Text("\(Int(model.fontSize))").monospacedDigit().frame(width: 28)
                    }
                }
                LabeledContent("줄 간격") {
                    Slider(value: $model.lineSpacing, in: 0...16, step: 1)
                }
                Toggle("소제목 보기", isOn: $model.showHeadings)
                Toggle("절 번호 보기", isOn: $model.showVerseNumbers)
                Text("하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니")
                    .font(model.textFont(language: "ko"))
                    .lineSpacing(model.lineSpacing)
                    .foregroundStyle(.secondary)
            }
            SwiftUI.Section("역본") {
                Picker("읽을 역본", selection: $model.primaryID) {
                    ForEach(model.translations) { Text($0.name).tag($0.id) }
                }
                Picker("대역 역본", selection: Binding(get: { model.secondaryID ?? "" }, set: { model.secondaryID = $0 })) {
                    ForEach(model.translations) { Text($0.name).tag($0.id) }
                }
            }
            SwiftUI.Section("소리 내어 읽기") {
                LabeledContent("빠르기") {
                    Slider(value: $speech.rate, in: 0.3...0.65)
                }
                Toggle("장이 끝나면 다음 장 이어 읽기", isOn: $speech.continueToNextChapter)
                Text("맥에 들어 있는 음성을 써요. 더 자연스러운 한국어 음성은 시스템 설정 › 손쉬운 사용 › 읽기 및 말하기에서 내려받을 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SwiftUI.Section("알림") {
                ReminderToggle(kind: .plan)
                ReminderToggle(kind: .dailyVerse)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 620)
    }
}

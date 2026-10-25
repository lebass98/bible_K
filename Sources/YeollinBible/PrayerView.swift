import BibleCore
import SwiftUI

/// 기도 제목 하나
struct PrayerItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var note = ""
    var created = Date()
    var answered: Date?
}

/// 기도: 기도 제목 적기 · 응답 표시 · 기도 알림
struct PrayerView: View {
    @Environment(AppModel.self) private var model
    @Local private var draft = ""
    @Local private var showAnswered = false
    @Local private var editing: PrayerItem?

    var body: some View {
        let all = model.user.data.prayers
        let items = all.filter { showAnswered ? $0.answered != nil : $0.answered == nil }
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("기도 제목").font(.title3.bold())
                if let phrase = Extras.daily(Extras.phrases.prayer) ?? Extras.daily(Self.defaultPhrases) {
                    Text(Extras.personalize(phrase)).foregroundStyle(.secondary)
                }
                HStack {
                    TextField("기도 제목을 적으세요", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("기도 남기기", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                HStack {
                    Picker("", selection: $showAnswered) {
                        Text("기도 중 \(all.filter { $0.answered == nil }.count)").tag(false)
                        Text("응답됨 \(all.filter { $0.answered != nil }.count)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    Spacer()
                    ReminderToggle(kind: .prayer).font(.callout)
                }
            }
            .padding(20)
            Divider()
            List {
                ForEach(items) { item in
                    row(item)
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(showAnswered ? "응답된 기도가 아직 없어요" : "기도 제목을 적어 보세요",
                                           systemImage: showAnswered ? "checkmark.seal" : "hands.sparkles")
                }
            }
        }
        .sheet(item: $editing) { item in
            PrayerEditor(item: item)
        }
    }

    private func row(_ item: PrayerItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { toggleAnswered(item) } label: {
                Image(systemName: item.answered == nil ? "circle" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(item.answered == nil ? Color.secondary : Color.green)
            }
            .buttonStyle(.plain)
            .help(item.answered == nil ? "응답됨으로 표시" : "다시 기도 중으로")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).fontWeight(.medium)
                if !item.note.isEmpty {
                    Text(item.note).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                }
                HStack(spacing: 8) {
                    Text("시작 \(item.created.formatted(.dateTime.year().month().day()))")
                    if let answered = item.answered {
                        Text("응답 \(answered.formatted(.dateTime.year().month().day()))").foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editing = item }
        .contextMenu {
            Button("고치기…") { editing = item }
            Button(item.answered == nil ? "응답됨으로 표시" : "다시 기도 중으로") { toggleAnswered(item) }
            Button("지우기", role: .destructive) { model.user.data.prayers.removeAll { $0.id == item.id } }
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.user.data.prayers.insert(PrayerItem(title: text), at: 0)
        draft = ""
    }

    private func toggleAnswered(_ item: PrayerItem) {
        guard let index = model.user.data.prayers.firstIndex(where: { $0.id == item.id }) else { return }
        model.user.data.prayers[index].answered = item.answered == nil ? Date() : nil
    }

    /// 문구 파일이 없을 때 쓰는 기본 문구
    static let defaultPhrases = [
        "지금 이 시간, 하나님께 마음을 올려 드려요.",
        "기도 제목 하나를 골라 오늘 한 번 더 구해 보세요.",
        "감사 한 줄로 기도를 시작해 보세요.",
        "응답된 기도를 돌아보며 감사해 보세요.",
    ]
}

/// 기도 제목 고치기
struct PrayerEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Local var item: PrayerItem

    var body: some View {
        Form {
            TextField("기도 제목", text: $item.title)
            TextField("메모", text: $item.note, axis: .vertical)
                .lineLimit(4...10)
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장") {
                    if let index = model.user.data.prayers.firstIndex(where: { $0.id == item.id }) {
                        model.user.data.prayers[index] = item
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }
}

/// 신앙고백: 사도신경(전통 번역) · 주기도문 · 십계명 (주기도문·십계명은 지금 고른 역본 본문)
struct CreedView: View {
    @Environment(AppModel.self) private var model
    @Local private var tab = Tab.creed

    enum Tab: String, CaseIterable, Identifiable {
        case creed = "사도신경", lordsPrayer = "주기도문", commandments = "십계명"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .padding(14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tab.rawValue).font(model.textFont(language: "ko", scale: 1.4).weight(.bold))
                    switch tab {
                    case .creed:
                        Text(Self.apostlesCreed)
                            .font(model.textFont(language: "ko", scale: 1.1))
                            .lineSpacing(model.lineSpacing + 6)
                            .textSelection(.enabled)
                        Text("전통 번역(옛 찬송가에 실린 사도신경)")
                            .font(.caption).foregroundStyle(.secondary)
                    case .lordsPrayer:
                        passage(from: VerseRef(book: 40, chapter: 6, verse: 9), to: VerseRef(book: 40, chapter: 6, verse: 13))
                    case .commandments:
                        passage(from: VerseRef(book: 2, chapter: 20, verse: 1), to: VerseRef(book: 2, chapter: 20, verse: 17))
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func passage(from: VerseRef, to: VerseRef) -> some View {
        let verses = model.verses(model.primaryID, from: from, to: to)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(verses) { verse in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(verse.ref.verse)").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                    Text(verse.text)
                        .font(model.textFont(language: model.primary?.language ?? "ko", scale: 1.1))
                        .lineSpacing(model.lineSpacing + 4)
                        .textSelection(.enabled)
                }
            }
            Button { model.open(from) } label: {
                Label("\(from.label)-\(to.verse) (\(model.primary?.short ?? "")) 본문으로", systemImage: "book")
            }
            .buttonStyle(.link)
        }
    }

    static let apostlesCreed = """
    전능하사 천지를 만드신 하나님 아버지를 내가 믿사오며, \
    그 외아들 우리 주 예수 그리스도를 믿사오니, \
    이는 성령으로 잉태하사 동정녀 마리아에게 나시고, \
    본디오 빌라도에게 고난을 받으사, 십자가에 못 박혀 죽으시고, \
    장사한 지 사흘 만에 죽은 자 가운데서 다시 살아나시며, \
    하늘에 오르사, 전능하신 하나님 우편에 앉아 계시다가, \
    저리로서 산 자와 죽은 자를 심판하러 오시리라.

    성령을 믿사오며, 거룩한 공회와, 성도가 서로 교통하는 것과, \
    죄를 사하여 주시는 것과, 몸이 다시 사는 것과, \
    영원히 사는 것을 믿사옵나이다. 아멘.
    """
}

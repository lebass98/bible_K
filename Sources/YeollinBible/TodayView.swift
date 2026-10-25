import BibleCore
import SwiftUI

/// 오늘의 말씀으로 돌아가며 보여 줄 구절 (구절 주소만 있음 — 본문은 고른 역본에서 가져옴)
enum DailyVerses {
    static let references: [String] = [
        "창1:1", "창1:27", "창12:2", "창28:15", "창50:20", "출14:14", "출15:2", "출33:14", "레19:18", "민6:24-26",
        "신6:4-5", "신31:6", "신31:8", "수1:9", "수24:15", "삼상16:7", "삼하22:31", "대상16:34", "대하7:14", "느8:10",
        "욥19:25", "욥23:10", "시1:1-2", "시16:8", "시18:2", "시19:14", "시23:1", "시23:4", "시27:1", "시27:14",
        "시30:5", "시32:8", "시34:8", "시34:18", "시37:4", "시37:5", "시40:1", "시42:11", "시46:1", "시46:10",
        "시51:10", "시55:22", "시56:3", "시62:1", "시63:3", "시73:26", "시84:10", "시90:12", "시91:1-2", "시100:4",
        "시103:2", "시103:12", "시118:1", "시119:105", "시121:1-2", "시126:5", "시127:1", "시133:1", "시139:14", "시145:18",
        "시147:3", "잠1:7", "잠3:5-6", "잠3:9", "잠4:23", "잠16:3", "잠16:9", "잠17:17", "잠18:10", "잠22:6",
        "전3:1", "전12:1", "사9:6", "사12:2", "사26:3", "사40:8", "사40:29", "사40:31", "사41:10", "사43:1",
        "사43:19", "사53:5", "사55:8-9", "사58:11", "사60:1", "렘17:7", "렘29:11", "렘31:3", "렘33:3", "애3:22-23",
        "겔36:26", "단12:3", "호6:3", "욜2:28", "미6:8", "합3:17-18", "습3:17", "학2:9", "슥4:6", "말3:10",
        "마5:3", "마5:9", "마5:14", "마5:16", "마6:9-10", "마6:33", "마6:34", "마7:7", "마7:12", "마11:28",
        "마11:29", "마16:24", "마18:20", "마22:37-39", "마28:19-20", "막9:23", "막10:45", "막11:24", "막12:30", "눅1:37",
        "눅2:14", "눅6:31", "눅6:38", "눅9:23", "눅12:34", "눅19:10", "요1:1", "요1:12", "요1:14", "요3:16",
        "요4:24", "요6:35", "요8:12", "요8:32", "요10:10", "요10:11", "요11:25", "요13:34", "요14:1", "요14:6",
        "요14:27", "요15:5", "요15:13", "요16:33", "행1:8", "행2:42", "행4:12", "행16:31", "행20:35", "롬1:16",
        "롬3:23", "롬5:8", "롬6:23", "롬8:1", "롬8:18", "롬8:28", "롬8:31", "롬8:38-39", "롬10:9", "롬10:17",
        "롬12:1", "롬12:2", "롬12:12", "롬12:21", "롬15:13", "고전10:13", "고전10:31", "고전13:4", "고전13:13", "고전15:58",
        "고후4:16", "고후4:18", "고후5:17", "고후9:7", "고후12:9", "갈2:20", "갈5:1", "갈5:22-23", "갈6:2", "갈6:9",
        "엡2:8", "엡2:10", "엡3:20", "엡4:2-3", "엡4:32", "엡5:20", "엡6:10", "빌1:6", "빌1:21", "빌2:3",
        "빌3:13-14", "빌4:4", "빌4:6-7", "빌4:13", "빌4:19", "골2:6-7", "골3:2", "골3:15", "골3:23", "살전5:16-18",
        "살후3:3", "딤전4:12", "딤후1:7", "딤후3:16", "딤후4:7", "딛3:5", "히4:12", "히4:16", "히10:24", "히11:1",
        "히12:1-2", "히13:5", "히13:8", "약1:2-3", "약1:5", "약1:17", "약1:22", "약4:8", "약5:16", "벧전2:9",
        "벧전3:15", "벧전1:3", "벧후3:9", "요일1:9", "요일3:18", "요일4:7", "요일4:8", "요일4:18", "요일4:19", "요일5:14",
        "유1:24", "계3:20", "계21:4", "계22:13", "계22:20",
    ]

    /// 날짜마다 정해진 구절 (같은 날에는 늘 같은 구절)
    static func reference(for date: Date) -> ReferenceParser.Reference? {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return ReferenceParser.parse(references[day % references.count])
    }
}

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Local private var date = Date()

    var body: some View {
        let reference = DailyVerses.reference(for: date)
        let verses = reference.map { model.verses(model.primaryID, from: $0.start, to: $0.end ?? $0.start) } ?? []
        let language = model.primary?.language ?? "ko"

        VStack(spacing: 24) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                Text(date, format: .dateTime.year().month().day().weekday())
                    .font(.headline)
                    .frame(minWidth: 200)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                if !Calendar.current.isDateInToday(date) {
                    Button("오늘") { date = Date() }
                }
            }
            .buttonStyle(.borderless)

            Spacer()
            VStack(spacing: 18) {
                Image(systemName: "quote.opening").font(.largeTitle).foregroundStyle(Color.accentColor.opacity(0.6))
                Text(verses.map(\.text).joined(separator: " "))
                    .font(model.textFont(language: language, scale: 1.35))
                    .lineSpacing(model.lineSpacing + 4)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 620)
                if let reference {
                    Text(label(reference)).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Spacer()

            if let reference {
                let refs = verses.map(\.ref)
                // 창이 좁으면 글자를 빼고 그림 단추만
                ViewThatFits(in: .horizontal) {
                    actions(reference, refs).labelStyle(.titleAndIcon)
                    actions(reference, refs).labelStyle(.iconOnly)
                }
            }
            ReminderToggle(kind: .dailyVerse)
                .font(.callout)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func actions(_ reference: ReferenceParser.Reference, _ refs: [VerseRef]) -> some View {
        HStack(spacing: 12) {
            Button { model.open(reference.start) } label: { Label("본문 보기", systemImage: "book") }.help("본문 보기")
            Button { model.copy(refs) } label: { Label("복사", systemImage: "doc.on.doc") }.help("복사")
            Button { model.makeCard(refs) } label: { Label("말씀 카드", systemImage: "photo.on.rectangle") }.help("말씀 카드")
            Button { model.user.toggleBookmark(refs) } label: {
                Label("책갈피", systemImage: refs.allSatisfy(model.user.isBookmarked) ? "bookmark.fill" : "bookmark")
            }
            .help("책갈피")
        }
        .buttonStyle(.bordered)
        .fixedSize()
    }

    private func shift(_ days: Int) {
        date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func label(_ reference: ReferenceParser.Reference) -> String {
        if let end = reference.end { return "\(reference.start.label)-\(end.verse)" }
        return reference.start.label
    }
}

/// 한 줄 감사 일기
struct ThanksView: View {
    @Environment(AppModel.self) private var model
    @Local private var draft = ""
    @FocusState private var focused: Bool

    private static let prompts = [
        "오늘 들은 따뜻한 말 한마디는?", "오늘 먹은 음식 가운데 고마운 것은?", "오늘 나를 도와준 사람은?",
        "오늘 지켜 주신 일은?", "오늘 본 아름다운 것은?", "오늘 배운 것 하나는?", "오늘 쉼이 되었던 순간은?",
        "오늘 웃었던 일은?", "오늘 읽은 말씀에서 남은 한 구절은?", "가족에게 고마운 점 하나는?",
    ]

    var body: some View {
        let todayCount = model.user.data.thanks.filter { Calendar.current.isDateInToday($0.date) }.count
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("오늘 감사한 일을 한 줄로 적어 보세요").font(.title3.bold())
                Text(Self.prompts[(Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0) % Self.prompts.count])
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("감사합니다…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit(add)
                    Button("적기", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("오늘 \(todayCount)개 · 모두 \(model.user.data.thanks.count)개")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()
            let groups = Dictionary(grouping: model.user.data.thanks) { Calendar.current.startOfDay(for: $0.date) }
                .sorted { $0.key > $1.key }
            List {
                ForEach(groups, id: \.key) { day, items in
                    SwiftUI.Section(day.formatted(.dateTime.year().month().day().weekday())) {
                        ForEach(items) { item in
                            HStack(alignment: .top) {
                                Image(systemName: "heart.fill").foregroundStyle(.pink).font(.caption)
                                Text(item.text).textSelection(.enabled)
                            }
                            .contextMenu {
                                Button("지우기", role: .destructive) { model.user.data.thanks.removeAll { $0.id == item.id } }
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.user.data.thanks.isEmpty {
                    ContentUnavailableView("아직 적은 감사가 없어요", systemImage: "heart")
                }
            }
        }
        .onAppear { focused = true }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.user.data.thanks.insert(ThanksEntry(text: text), at: 0)
        draft = ""
    }
}

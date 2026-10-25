import BibleCore
import SwiftUI

@main
struct YeollinBibleApp: App {
    @Local private var model = AppModel()

    init() {
        DebugLog.write("앱 시작 — 위치: \(Bundle.main.bundlePath)")
        FontLibrary.registerUserFonts()
    }

    var body: some Scene {
        WindowGroup("열린성경") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 560)
                .task { Reminders.reschedule(model: model) }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("이동") {
                Button("구절로 이동…") { model.showGoTo = true }
                    .keyboardShortcut("l")
                Button("찾기") { model.section = .search }
                    .keyboardShortcut("f")
                Divider()
                Button("이전 장") { model.goPrevious() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("다음 장") { model.goNext() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Divider()
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) { model.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            CommandMenu("보기") {
                Button("글자 크게") { model.fontSize = min(model.fontSize + 1, 40) }
                    .keyboardShortcut("+")
                Button("글자 작게") { model.fontSize = max(model.fontSize - 1, 12) }
                    .keyboardShortcut("-")
                Button("글자 기본 크기") { model.fontSize = 18 }
                    .keyboardShortcut("0")
                Divider()
                Toggle("대역 (두 역본 함께 보기)", isOn: $model.parallel)
                    .keyboardShortcut("d")
                Toggle("원어 번호 보기", isOn: $model.showStrongs)
                Toggle("오른쪽 정보 창", isOn: $model.showInspector)
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.section) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } detail: {
            Group {
                switch model.section {
                case .reader: ReaderView()
                case .search: SearchView()
                case .records: RecordsView()
                case .history: HistoryView()
                case .plan: PlanView()
                case .today: TodayView()
                case .thanks: ThanksView()
                case .library: LibraryView()
                }
            }
            .navigationTitle(model.section == .reader ? "열린성경" : model.section.title)
        }
        .sheet(isPresented: $model.showGoTo) { GoToSheet() }
        .sheet(item: Binding(get: { model.cardVerses.map(CardRequest.init) }, set: { model.cardVerses = $0?.verses })) { request in
            CardMakerView(verses: request.verses)
        }
        .sheet(item: $model.noteDraft) { note in
            NoteEditor(note: note)
        }
    }
}

struct CardRequest: Identifiable {
    let verses: [VerseRow]
    var id: Int { verses.first?.id ?? 0 }
}

/// ⌘L: "요3:16" 처럼 적어서 바로 가기
struct GoToSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Local private var text = ""
    @Local private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("구절로 이동").font(.headline)
            TextField("예: 요3:16, 시편 23, 롬 8:28", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .onSubmit(go)
            if failed {
                Text("주소를 알아보지 못했어요. 책 이름과 장을 적어 주세요.")
                    .font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("이동", action: go).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func go() {
        guard let ref = ReferenceParser.parse(text) else { failed = true; return }
        if ref.hasVerse { model.open(ref.start) } else { model.open(ref.chapter) }
        dismiss()
    }
}

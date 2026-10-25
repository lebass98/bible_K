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
                .frame(minWidth: 460, minHeight: 420)
                .task {
                    model.appearance.apply()
                    Reminders.reschedule(model: model)
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("이동") {
                Button("목차검색…") { model.showGoTo = true }
                    .keyboardShortcut("l")
                Button("찾기") { model.section = .search }
                    .keyboardShortcut("f")
                Divider()
                Button(model.section == .hymns ? "이전 곡" : "이전 장") { model.goPrevious() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button(model.section == .hymns ? "다음 곡" : "다음 장") { model.goNext() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Divider()
                // ⌘1~⌘9 (아홉 개까지만 단축키를 붙임)
                ForEach(Array(AppSection.allCases.prefix(9).enumerated()), id: \.element) { index, section in
                    Button(section.title) { model.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            // 시스템의 보기 메뉴 안에 넣음 (따로 만들면 보기 메뉴가 두 개가 됨)
            CommandGroup(before: .toolbar) {
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
                Divider()
                Picker("모양", selection: $model.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                Button("라이트 · 다크 바꾸기") {
                    let dark = model.appearance == .dark
                        || (model.appearance == .system && NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
                    model.appearance = dark ? .light : .dark
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
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
    @Local private var columns = NavigationSplitViewVisibility.automatic
    @Local private var width: CGFloat = 0

    /// 이보다 좁으면 왼쪽 목록을 접음
    private static let narrow: CGFloat = 760

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columns) {
            BibleSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            Group {
                switch model.section {
                case .reader: ReaderView()
                case .search: SearchView()
                case .records: RecordsView()
                case .history: HistoryView()
                case .plan: PlanView()
                case .today: TodayView()
                case .hymns: HymnView()
                case .creeds: CreedView()
                case .prayer: PrayerView()
                case .thanks: ThanksView()
                case .library: LibraryView()
                }
            }
            .navigationTitle(model.section == .reader ? "열린성경" : model.section.title)
        }
        .tint(BibleStyle.accent)
        .accentColor(BibleStyle.accent)
        .readWidth($width)
        .onChange(of: width) { old, new in
            // 좁아지는 순간에만 접고, 넓어지는 순간에만 펼침 (사용자가 직접 연 목록은 그대로 둠)
            if old >= Self.narrow, new < Self.narrow { columns = .detailOnly }
            if old < Self.narrow, new >= Self.narrow, old > 0 { columns = .all }
        }
        .onAppear { if width > 0, width < Self.narrow { columns = .detailOnly } }
        .sheet(isPresented: $model.showGoTo) { BookIndexSheet() }
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

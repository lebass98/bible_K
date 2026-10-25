import BibleCore
import SwiftUI

/// 내 기록: 책갈피 · 형광펜 · 노트
struct RecordsView: View {
    @Environment(AppModel.self) private var model
    @Local private var tab = Tab.bookmarks
    @Local private var colorFilter: HighlightColor?

    enum Tab: String, CaseIterable, Identifiable {
        case bookmarks = "책갈피", highlights = "형광펜", notes = "묵상 노트"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .padding(12)
            Divider()
            switch tab {
            case .bookmarks: bookmarks
            case .highlights: highlights
            case .notes: notes
            }
        }
    }

    private var bookmarks: some View {
        List {
            ForEach(model.user.data.bookmarks) { item in
                row(item.ref.label, model.verseText(item.ref), date: item.created) { model.open(item.ref) }
                    .contextMenu { Button("책갈피 빼기") { model.user.toggleBookmark([item.ref]) } }
            }
        }
        .overlay {
            if model.user.data.bookmarks.isEmpty {
                ContentUnavailableView("책갈피가 없어요", systemImage: "bookmark", description: Text("본문에서 절을 고르고 책갈피 단추를 누르세요."))
            }
        }
    }

    private var highlights: some View {
        let items = model.user.data.highlights
            .filter { colorFilter == nil || $0.value == colorFilter }
            .sorted { $0.key < $1.key }
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button("모두") { colorFilter = nil }.buttonStyle(.bordered).tint(colorFilter == nil ? .accentColor : nil)
                ForEach(HighlightColor.allCases) { color in
                    Button { colorFilter = color } label: {
                        Circle().fill(Color(nsColor: color.nsColor)).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.primary.opacity(colorFilter == color ? 0.7 : 0), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(color.name)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            List {
                ForEach(items, id: \.key) { id, color in
                    let ref = VerseRef(id: id)
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: color.nsColor)).frame(width: 4)
                        row(ref.label, model.verseText(ref), date: nil) { model.open(ref) }
                    }
                    .contextMenu { Button("형광펜 지우기") { model.user.setHighlight(nil, for: [ref]) } }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("형광펜 칠한 절이 없어요", systemImage: "highlighter", description: Text("본문에서 절을 고르고 색을 누르세요."))
                }
            }
        }
    }

    private var notes: some View {
        List {
            ForEach(model.user.data.notes) { note in
                row(note.label, note.text, date: note.updated) { model.noteDraft = note }
                    .contextMenu {
                        Button("본문으로 가기") { model.open(note.start) }
                        Button("노트 지우기", role: .destructive) { model.user.data.notes.removeAll { $0.id == note.id } }
                    }
            }
        }
        .overlay {
            if model.user.data.notes.isEmpty {
                ContentUnavailableView("노트가 없어요", systemImage: "note.text", description: Text("본문에서 절을 고르고 노트 단추를 누르세요."))
            }
        }
    }

    private func row(_ title: String, _ text: String, date: Date?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor)
                    Spacer()
                    if let date { Text(date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(.secondary) }
                }
                Text(text).lineLimit(3).multilineTextAlignment(.leading)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 읽은 기록
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let groups = Dictionary(grouping: model.user.data.history) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
        List {
            ForEach(groups, id: \.key) { day, items in
                SwiftUI.Section(day.formatted(.dateTime.year().month().day().weekday())) {
                    ForEach(items) { item in
                        Button { model.open(item.chapter) } label: {
                            HStack {
                                Text(item.chapter.label)
                                Spacer()
                                Text(item.date, format: .dateTime.hour().minute()).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if model.user.data.history.isEmpty {
                ContentUnavailableView("읽은 기록이 없어요", systemImage: "clock")
            }
        }
        .toolbar {
            Button("기록 지우기") { model.user.data.history = [] }
                .disabled(model.user.data.history.isEmpty)
        }
    }
}

/// 노트 쓰기 창
struct NoteEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Local var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.label).font(.headline)
            ScrollView {
                Text(model.verses(model.primaryID, from: note.start, to: note.end).map { "\($0.ref.verse) \($0.text)" }.joined(separator: "\n"))
                    .font(model.textFont(language: model.primary?.language ?? "ko", scale: 0.85))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            TextEditor(text: $note.text)
                .font(.body)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            HStack {
                if model.user.data.notes.contains(where: { $0.id == note.id }) {
                    Button("지우기", role: .destructive) {
                        model.user.data.notes.removeAll { $0.id == note.id }
                        dismiss()
                    }
                }
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장") {
                    model.user.saveNote(note)
                    dismiss()
                }
                .keyboardShortcut("s")
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

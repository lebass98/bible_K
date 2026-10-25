import BibleCore
import SwiftUI

/// 목차검색: 구분별 책 목록 · 장 · 절을 세 칸으로 고르고, 초성으로 책을 찾음
struct BookIndexSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @Local private var book = 1
    @Local private var chapter = 1
    @Local private var query = ""
    @Local private var showKeypad = true
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                bookColumn
                Divider()
                chapterColumn.frame(width: 96)
                Divider()
                verseColumn.frame(width: 96)
            }
            Divider()
            inputBar
            if showKeypad {
                ChoseongKeypad { key in
                    if key == "⌫" { if !query.isEmpty { query.removeLast() } } else { query.append(key) }
                }
            }
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 560, idealHeight: 680)
        .onAppear {
            book = model.location.book
            chapter = model.location.chapter
            focused = true
        }
        .onChange(of: query) { _, value in
            // 책이 하나만 남으면 바로 고름
            // 이름·약어가 꼭 맞는 책("요" → 요한복음)이 있으면 그 책, 아니면 하나만 남았을 때
            let matches = BookIndex.filter(value)
            if let pick = matches.first(where: { BookIndex.isExact(value, $0) }) ?? (matches.count == 1 ? matches.first : nil),
               pick.id != book {
                book = pick.id
                chapter = 1
            }
        }
    }

    // MARK: 머리

    private var header: some View {
        HStack {
            Text("목차검색").font(.headline)
            Text("성경본문").font(.headline).foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                .help("닫기 (esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: 책

    private var bookColumn: some View {
        let filtered = BookIndex.filter(query)
        return ScrollViewReader { proxy in
            HStack(spacing: 0) {
                List {
                    ForEach(BookIndex.groups) { group in
                        let books = group.books.filter { item in filtered.contains { $0.id == item.id } }
                        if !books.isEmpty {
                            SwiftUI.Section(group.title) {
                                ForEach(books) { item in
                                    bookRow(item).id("book-\(item.id)")
                                }
                            }
                            .id("group-\(group.id)")
                        }
                    }
                }
                .listStyle(.plain)
                .onAppear { proxy.scrollTo("book-\(book)", anchor: .center) }
                .onChange(of: book) { _, value in withAnimation { proxy.scrollTo("book-\(value)", anchor: .center) } }

                // 오른쪽 빠른 이동 글자
                VStack(spacing: 2) {
                    ForEach(BookIndex.groups.filter { !$0.jump.isEmpty }) { group in
                        Button(group.jump) { proxy.scrollTo("group-\(group.id)", anchor: .top) }
                            .buttonStyle(.plain)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22, height: 20)
                            .help(group.title)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func bookRow(_ item: BibleBook) -> some View {
        let selected = item.id == book
        return Button {
            book = item.id
            chapter = 1
            if item.chapters == 1 { chapter = 1 }
        } label: {
            HStack(spacing: 10) {
                Text(item.short)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? Color.red : Color.accentColor)
                    .frame(width: 30, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.body.weight(selected ? .semibold : .regular))
                    Text(item.english).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    // MARK: 장 · 절

    private var unit: String { book == 19 ? "편" : "장" }

    private var chapterColumn: some View {
        let count = Bible.book(book)?.chapters ?? 1
        return ScrollViewReader { proxy in
            List(1...count, id: \.self) { number in
                Button {
                    chapter = number
                } label: {
                    Text("\(number) \(unit)")
                        .font(.callout.monospacedDigit().weight(number == chapter ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(number == chapter ? Color.accentColor.opacity(0.25) : Color.clear)
                .id(number)
                // 장을 두 번 누르면 그 장 처음으로
                .simultaneousGesture(TapGesture(count: 2).onEnded { go(VerseRef(book: book, chapter: number, verse: 1), selectVerse: false) })
            }
            .listStyle(.plain)
            .onAppear { proxy.scrollTo(chapter, anchor: .center) }
            .onChange(of: book) { _, _ in proxy.scrollTo(1, anchor: .top) }
        }
    }

    private var verseColumn: some View {
        let ref = ChapterRef(book: book, chapter: chapter)
        let verses = model.chapter(model.primaryID, ref).map(\.ref.verse)
        let numbers = verses.isEmpty ? Array(1...max(model.chapter("kjv", ref).count, 1)) : verses
        return List(numbers, id: \.self) { number in
            Button {
                go(VerseRef(book: book, chapter: chapter, verse: number), selectVerse: number > 1)
            } label: {
                Text("\(number) 절")
                    .font(.callout.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .id("verses-\(book)-\(chapter)")
    }

    // MARK: 입력 줄

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(currentLabel, text: $query)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .multilineTextAlignment(.center)
                .focused($focused)
                .onSubmit(submit)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
            Button { go(VerseRef(book: book, chapter: chapter, verse: 1), selectVerse: false) } label: {
                Text("이동").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .help("고른 장으로 가기 (↩)")
            Button { showKeypad.toggle() } label: { Image(systemName: showKeypad ? "keyboard.chevron.compact.down" : "keyboard") }
                .buttonStyle(.borderless)
                .help("초성 자판 보이기·숨기기")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var currentLabel: String {
        "\(Bible.book(book)?.name ?? "") \(chapter)\(unit)"
    }

    /// ↩: "요3:16"처럼 주소를 적었으면 거기로, 아니면 고른 장으로
    private func submit() {
        if let reference = ReferenceParser.parse(query) {
            go(reference.start, selectVerse: reference.hasVerse)
        } else {
            go(VerseRef(book: book, chapter: chapter, verse: 1), selectVerse: false)
        }
    }

    private func go(_ ref: VerseRef, selectVerse: Bool) {
        if selectVerse {
            model.open(ref)
        } else {
            model.open(ChapterRef(book: ref.book, chapter: ref.chapter))
        }
        dismiss()
    }
}

/// 초성 자판 (ㄱ ㄴ ㄷ … ㅎ)
struct ChoseongKeypad: View {
    let onKey: (String) -> Void
    private let keys = ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ", "⌫"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Button { onKey(key) } label: {
                    Group {
                        if key == "⌫" { Image(systemName: "delete.left") } else { Text(key) }
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

/// 성경 구분과 초성 찾기
enum BookIndex {
    struct Group: Identifiable {
        let id: Int
        let title: String
        let jump: String          // 오른쪽 빠른 이동 글자
        let books: [BibleBook]
    }

    static let groups: [Group] = {
        let ranges: [(String, String, ClosedRange<Int>)] = [
            ("율법서", "창", 1...5), ("역사서", "수", 6...17), ("시가서", "욥", 18...22),
            ("대선지서", "사", 23...27), ("소선지서", "호", 28...39), ("복음서", "마", 40...43),
            ("역사서", "행", 44...44), ("바울서신", "롬", 45...57), ("일반서신", "히", 58...65), ("예언서", "계", 66...66),
        ]
        return ranges.enumerated().map { index, item in
            Group(id: index, title: item.0, jump: item.1, books: item.2.compactMap(Bible.book))
        }
    }()

    /// 초성·이름·약어·영어로 책 거르기 ("ㅅㅍ", "시ㅍ", "시편", "시", "Ps")
    static func filter(_ query: String) -> [BibleBook] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return Bible.books }
        // "시23", "요3:16" 처럼 숫자가 붙으면 책 이름 부분만 씀
        let name = String(text.prefix { !$0.isNumber && $0 != ":" }).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return Bible.books }
        return Bible.books.filter { book in
            matches(name, book.name) || matches(name, book.short) || book.english.lowercased().hasPrefix(name.lowercased())
        }
    }

    static func isExact(_ query: String, _ book: BibleBook) -> Bool {
        let name = String(query.prefix { !$0.isNumber && $0 != ":" }).trimmingCharacters(in: .whitespaces)
        return name == book.name || name == book.short
    }

    /// 앞에서부터 한 글자씩 비교. 찾는 글자가 자음만 있으면(ㅅ) 그 글자의 초성과 비교
    private static func matches(_ query: String, _ target: String) -> Bool {
        let q = Array(query), t = Array(target)
        guard q.count <= t.count else { return false }
        for (a, b) in zip(q, t) {
            if let initial = choseongIndex(of: a) {
                guard syllableInitial(b) == initial || a == b else { return false }
            } else if a != b {
                return false
            }
        }
        return true
    }

    private static let choseong: [Character] = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]

    private static func choseongIndex(of ch: Character) -> Int? { choseong.firstIndex(of: ch) }

    private static func syllableInitial(_ ch: Character) -> Int? {
        guard let scalar = ch.unicodeScalars.first, (0xAC00...0xD7A3).contains(scalar.value) else { return nil }
        return Int((scalar.value - 0xAC00) / 588)
    }
}

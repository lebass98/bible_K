import BibleCore
import SwiftUI

/// 성경 읽기 화면
struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @Local private var showTextStyle = false
    @Local private var width: CGFloat = 900

    /// 창이 이보다 좁으면 대역을 위아래로 쌓음
    private var stacked: Bool { width < 720 }
    /// 좌우 여백 (좁은 창일수록 작게)
    private var gutter: CGFloat { width < 560 ? 16 : (width < 900 ? 24 : 36) }

    var body: some View {
        @Bindable var model = model
        let primary = model.chapter(model.primaryID, model.location)
        let secondaryID = model.secondary?.id
        let secondary = secondaryID.map { model.chapter($0, model.location) } ?? []
        let rows = mergedRows(primary, secondary)
        let footnoted = model.database(for: model.primaryID)?.footnotedVerses(model.primaryID, model.location) ?? []

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: model.lineSpacing + 8) {
                    header
                    if rows.isEmpty {
                        ContentUnavailableView("이 장의 본문이 없어요", systemImage: "book.closed",
                                               description: Text("\(model.primary?.name ?? "이 역본")에는 \(model.location.label)이 들어 있지 않아요. 다른 역본을 골라 보세요."))
                    }
                    ForEach(rows, id: \.ref) { row in
                        VerseRowView(ref: row.ref, primary: row.primary, secondary: secondaryID == nil ? nil : .some(row.secondary),
                                     stacked: stacked, footnoted: footnoted.contains(row.ref.id))
                            .id(row.ref)
                    }
                    footer
                }
                .padding(.horizontal, gutter)
                .padding(.vertical, width < 560 ? 22 : 36)
                .frame(maxWidth: model.parallel ? 1200 : 780)
                .background(BibleStyle.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(BibleStyle.rule.opacity(0.7), lineWidth: 1) }
                .frame(maxWidth: .infinity)
                .padding(width < 560 ? 10 : 24)
            }
            .onAppear { scroll(proxy, to: model.scrollTarget, animated: false) }
            .onChange(of: model.scrollTarget) { _, target in scroll(proxy, to: target, animated: true) }
            .onChange(of: model.location) { _, _ in
                if model.scrollTarget == nil { proxy.scrollTo(rows.first?.ref, anchor: .top) }
            }
            .onChange(of: model.audio.currentVerse) { _, current in
                // 듣고 있는 장을 보고 있을 때만 따라감
                if let current, model.audio.chapter == model.location { withAnimation { proxy.scrollTo(current, anchor: .center) } }
            }
            .onChange(of: model.speech.current) { _, current in
                if let current { withAnimation { proxy.scrollTo(current, anchor: .center) } }
            }
        }
        .background(BibleStyle.canvas)
        .readWidth($width)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if model.audio.isActive { AudioPlayerBar(compact: width < 640) }
                if let error = model.speech.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .onTapGesture { model.speech.lastError = nil }
                }
                if !model.selection.isEmpty { SelectionBar(compact: width < 640) }
            }
            .padding(10)
        }
        .toolbar { toolbar }
        .inspector(isPresented: $model.showInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 260, ideal: 320, max: 460)
        }
    }

    /// 듣기 단추 설명: 이 장에 녹음 음원이 있는지에 따라
    private var listenHelp: String {
        if model.audio.preferRecorded, let prefix = model.audio.preferredPrefix(translation: model.primaryID, chapter: model.location) {
            return "듣기 (고른 절부터) · 녹음 음원 \(model.audio.sets[prefix]?.name ?? prefix)"
        }
        return "소리 내어 읽기 (고른 절부터) · \(model.speech.usesGoogle ? "구글 음성" : "맥 음성")"
    }

    private func scroll(_ proxy: ScrollViewProxy, to target: VerseRef?, animated: Bool) {
        guard let target else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation { proxy.scrollTo(target, anchor: .center) }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
            model.scrollTarget = nil
        }
    }

    private struct Row {
        let ref: VerseRef
        let primary: VerseRow?
        let secondary: VerseRow?
    }

    /// 두 역본의 절 번호가 다를 수 있어서 합쳐서 줄을 만듦
    private func mergedRows(_ primary: [VerseRow], _ secondary: [VerseRow]) -> [Row] {
        guard !secondary.isEmpty else { return primary.map { Row(ref: $0.ref, primary: $0, secondary: nil) } }
        let first = Dictionary(primary.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        let second = Dictionary(secondary.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        return Set(first.keys).union(second.keys).sorted().map { Row(ref: $0, primary: first[$0], secondary: second[$0]) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(BibleStyle.accent.opacity(0.6)).frame(width: 20, height: 1)
                Text(Bible.book(model.location.book)?.english.uppercased() ?? "")
                    .font(.system(size: 10, weight: .semibold)).tracking(2)
                    .foregroundStyle(BibleStyle.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(model.location.label)
                    .font(model.textFont(language: "ko", scale: 1.7).weight(.bold))
                Text("\(model.chapter(model.primaryID, model.location).count)절")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !stacked, let secondary = model.secondary, let primary = model.primary {
                HStack(spacing: 20) {
                    Text(primary.name).frame(maxWidth: .infinity, alignment: .leading)
                    Text(secondary.name).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(model.primary?.name ?? "")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Rectangle().fill(BibleStyle.rule).frame(height: 1).padding(.top, 8)
        }
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            missingNotice
            navigation
        }
        .padding(.top, 24)
    }

    /// 역본 데이터에 빠진 절이 있으면 알려 줌 (KJV 절 수와 비교)
    @ViewBuilder
    private var missingNotice: some View {
        let have = model.chapter(model.primaryID, model.location).count
        let expected = model.primaryID == "kjv" ? have : model.chapter("kjv", model.location).count
        if have > 0, expected - have >= 3 {
            Label("\(model.primary?.short ?? "") 데이터에는 이 장의 일부(약 \(expected - have)절)가 빠져 있어요. 대역(⌘D)으로 다른 역본을 함께 보세요.",
                  systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var navigation: some View {
        HStack {
            if let prev = model.location.previous {
                Button { model.open(prev) } label: { Label(prev.label, systemImage: "chevron.left") }
            }
            Spacer()
            if let next = model.location.next {
                Button { model.open(next) } label: {
                    Label(next.label, systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle())
                }
            }
        }
        .buttonStyle(.bordered)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var model = model
        ToolbarItemGroup(placement: .navigation) {
            Button { model.goPrevious() } label: { Image(systemName: "chevron.left") }
                .help("이전 장 (⌘←)")
                .disabled(model.location.previous == nil)
            Button { model.showGoTo = true } label: {
                HStack(spacing: 4) {
                    Text(model.location.label).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }
            .help("목차검색: 책·장·절 고르기 (⌘L)")
            Button { model.goNext() } label: { Image(systemName: "chevron.right") }
                .help("다음 장 (⌘→)")
                .disabled(model.location.next == nil)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("역본", selection: $model.primaryID) {
                    ForEach(model.translations) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.inline)
            } label: {
                Text(model.primary?.short ?? "역본")
            }
            .help("읽을 역본: \(model.primary?.name ?? "")")
            Toggle(isOn: $model.parallel) { Label("대역", systemImage: "rectangle.split.2x1") }
                .help("두 역본 함께 보기 (⌘D)")
            if model.parallel {
                Menu {
                    Picker("대역 역본", selection: Binding(get: { model.secondaryID ?? "" }, set: { model.secondaryID = $0 })) {
                        ForEach(model.translations.filter { $0.id != model.primaryID }) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text(model.secondary?.short ?? "대역")
                }
                .help("함께 볼 역본: \(model.secondary?.name ?? "")")
            }
            if model.translations.contains(where: \.hasStrongs) {
                Toggle(isOn: $model.showStrongs) { Label("원어", systemImage: "character.book.closed") }
                    .help("원어 번호(Strong's)가 붙은 낱말 표시")
            }
            Button { showTextStyle.toggle() } label: { Label("글꼴", systemImage: "textformat.size") }
                .help("글꼴·글자 크기·줄 간격")
                .popover(isPresented: $showTextStyle, arrowEdge: .bottom) { TextStylePanel() }
            Button {
                if model.isListening { model.stopListening() } else { model.listen(from: model.sortedSelection.first) }
            } label: {
                Label(model.isListening ? "멈춤" : "듣기", systemImage: model.isListening ? "stop.fill" : "speaker.wave.2")
            }
            .help(model.isListening ? "듣기 멈춤" : listenHelp)
            Button { model.showInspector.toggle() } label: { Label("정보", systemImage: "sidebar.right") }
                .help("관주·원어·노트 (⌥⌘I)")
        }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}

/// 한 절
struct VerseRowView: View {
    @Environment(AppModel.self) private var model
    let ref: VerseRef
    let primary: VerseRow?
    /// nil이면 대역 아님, .some(nil)이면 대역인데 이 절이 없음
    let secondary: VerseRow??
    /// 좁은 창: 대역을 아래에 쌓아서 보여 줌
    var stacked = false
    /// 역본 각주가 있는 절 (정보 창에서 봄)
    var footnoted = false

    var body: some View {
        let selected = model.selection.contains(ref)
        let speaking = model.speech.current == ref || model.audio.currentVerse == ref
        let highlight = model.user.data.highlights[ref.id]

        VStack(alignment: .leading, spacing: 6) {
            if model.showHeadings, let heading = primary?.heading ?? (secondary ?? nil)?.heading {
                Text(heading)
                    .font(model.textFont(language: model.primary?.language ?? "ko", scale: 0.85).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            if stacked, let secondary {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        column(primary, translation: model.primary)
                        markers
                    }
                    if let second = secondary {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(model.secondary?.short ?? "")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            column(second, translation: model.secondary, scale: 0.9, dimmed: true)
                        }
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 2)
                        }
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    column(primary, translation: model.primary)
                    if let secondary {
                        column(secondary, translation: model.secondary)
                    }
                    markers
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(background(selected: selected, speaking: speaking, highlight: highlight))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.accentColor.opacity(selected ? 0.6 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection() }
        .contextMenu { VerseMenu(refs: model.selection.contains(ref) ? model.sortedSelection : [ref]) }
    }

    private func background(selected: Bool, speaking: Bool, highlight: HighlightColor?) -> Color {
        if speaking { return Color.accentColor.opacity(0.18) }
        if let highlight { return Color(nsColor: highlight.nsColor).opacity(selected ? 0.45 : 0.3) }
        return selected ? Color.accentColor.opacity(0.1) : .clear
    }

    private func toggleSelection() {
        if NSEvent.modifierFlags.contains(.shift), let anchor = model.selection.max() ?? model.selection.min(),
           anchor.book == ref.book, anchor.chapter == ref.chapter {
            // Shift-클릭: 사이의 절을 모두 고름
            let range = min(anchor.verse, ref.verse)...max(anchor.verse, ref.verse)
            for v in range { model.selection.insert(VerseRef(book: ref.book, chapter: ref.chapter, verse: v)) }
        } else if model.selection.contains(ref) {
            model.selection.remove(ref)
        } else {
            model.selection.insert(ref)
        }
        model.selectedStrong = nil
    }

    @ViewBuilder
    private func column(_ verse: VerseRow?, translation: BibleTranslation?, scale: Double = 1, dimmed: Bool = false) -> some View {
        let language = translation?.language ?? "ko"
        Group {
            if let verse {
                verseText(verse, language: language)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .font(model.textFont(language: language, scale: scale))
        .foregroundStyle(dimmed ? .secondary : .primary)
        .lineSpacing(model.lineSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func verseText(_ verse: VerseRow, language: String) -> Text {
        var number = Text("")
        if model.showVerseNumbers {
            number = Text("\(ref.verse)  ")
                .font(.system(size: model.fontSize * 0.62, weight: .semibold))
                .foregroundColor(.accentColor)
                .baselineOffset(model.fontSize * 0.28)
        }
        guard model.showStrongs, let tagged = verse.tagged else { return number + Text(verse.text) }
        var body = Text("")
        for segment in TaggedText.segments(tagged) {
            if segment.strongs.isEmpty {
                body = body + Text(segment.text)
            } else {
                body = body + Text(segment.text).foregroundColor(.accentColor)
                    + Text(segment.strongs.joined(separator: " "))
                        .font(.system(size: model.fontSize * 0.5))
                        .foregroundColor(.secondary)
                        .baselineOffset(model.fontSize * 0.3)
            }
        }
        return number + body
    }

    private var markers: some View {
        VStack(spacing: 4) {
            if model.user.isBookmarked(ref) {
                Image(systemName: "bookmark.fill").foregroundStyle(.orange)
            }
            if !model.user.notes(for: ref).isEmpty {
                Image(systemName: "note.text").foregroundStyle(.secondary)
            }
            if footnoted {
                Image(systemName: "asterisk").foregroundStyle(.orange)
                    .help("각주가 있어요 — 절을 고르고 정보 창에서 보세요")
            }
        }
        .font(.caption)
        .frame(width: 14)
    }
}

/// 절 오른쪽 클릭 메뉴
struct VerseMenu: View {
    @Environment(AppModel.self) private var model
    let refs: [VerseRef]

    var body: some View {
        Button("복사") { model.copy(refs) }
        Button(refs.allSatisfy(model.user.isBookmarked) ? "책갈피 빼기" : "책갈피") { model.user.toggleBookmark(refs) }
        Menu("형광펜") {
            ForEach(HighlightColor.allCases) { color in
                Button(color.name) { model.user.setHighlight(color, for: refs) }
            }
            Divider()
            Button("형광펜 지우기") { model.user.setHighlight(nil, for: refs) }
        }
        Button("노트 쓰기…") { model.writeNote(refs) }
        Button("말씀 카드 만들기…") { model.makeCard(refs) }
        Divider()
        Button("관주·원어 보기") {
            model.selection = Set(refs)
            model.showInspector = true
        }
        Button("여기부터 듣기") { model.listen(from: refs.first) }
    }
}

/// 절을 고르면 아래에 뜨는 막대
struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    /// 좁은 창: 구절 이름을 빼고 형광펜 색을 메뉴 하나로 묶음
    var compact = false

    var body: some View {
        let refs = model.sortedSelection
        HStack(spacing: compact ? 12 : 14) {
            if !compact {
                Text(label(refs))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Divider().frame(height: 18)
            }
            if compact {
                Menu {
                    ForEach(HighlightColor.allCases) { color in
                        Button("형광펜 \(color.name)") { model.user.setHighlight(color, for: refs) }
                    }
                    Divider()
                    Button("형광펜 지우기") { model.user.setHighlight(nil, for: refs) }
                } label: {
                    Image(systemName: "highlighter")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("형광펜")
            } else {
                HStack(spacing: 6) {
                    ForEach(HighlightColor.allCases) { color in
                        Button { model.user.setHighlight(color, for: refs) } label: {
                            Circle().fill(Color(nsColor: color.nsColor)).frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                        .help("형광펜 \(color.name)")
                    }
                    Button { model.user.setHighlight(nil, for: refs) } label: {
                        Image(systemName: "eraser")
                    }
                    .buttonStyle(.plain)
                    .help("형광펜 지우기")
                }
                Divider().frame(height: 18)
            }
            Group {
                Button { model.user.toggleBookmark(refs) } label: {
                    Image(systemName: refs.allSatisfy(model.user.isBookmarked) ? "bookmark.fill" : "bookmark")
                }.help("책갈피")
                Button { model.writeNote(refs) } label: { Image(systemName: "square.and.pencil") }.help("노트 쓰기")
                Button { model.copy(refs) } label: { Image(systemName: "doc.on.doc") }.help("복사")
                Button { model.makeCard(refs) } label: { Image(systemName: "photo.on.rectangle") }.help("말씀 카드 만들기")
                Button { model.listen(from: refs.first) } label: { Image(systemName: "speaker.wave.2") }.help("여기부터 듣기")
                Button { model.showInspector = true } label: { Image(systemName: "link") }.help("관주·원어 보기")
            }
            .buttonStyle(.plain)
            if !compact { Divider().frame(height: 18) }
            Button { model.selection = [] } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("고르기 취소 (esc)")
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func label(_ refs: [VerseRef]) -> String {
        guard let first = refs.first, let last = refs.last else { return "" }
        if refs.count == 1 { return first.shortLabel }
        return "\(first.shortLabel)-\(last.verse) · \(refs.count)절"
    }
}

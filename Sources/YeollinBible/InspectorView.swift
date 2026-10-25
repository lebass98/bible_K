import BibleCore
import SwiftUI

/// 오른쪽 정보 창: 고른 절의 노트·원어·관주
struct InspectorView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let ref = model.sortedSelection.first {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(ref.label).font(.title3.bold())
                    notes(ref)
                    translationNotes(ref)
                    strongs(ref)
                    crossRefs(ref)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("절을 골라 주세요", systemImage: "hand.tap",
                                   description: Text("본문에서 절을 클릭하면 관주, 원어 뜻, 노트가 여기에 보여요."))
        }
    }

    // MARK: 노트

    @ViewBuilder
    private func notes(_ ref: VerseRef) -> some View {
        let notes = model.user.notes(for: ref)
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.label).font(.caption).foregroundStyle(.secondary)
                        Text(note.text).font(.callout).textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { model.noteDraft = note }
                }
                Button { model.writeNote(model.sortedSelection) } label: { Label("노트 쓰기", systemImage: "square.and.pencil") }
                    .buttonStyle(.borderless)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("노트", systemImage: "note.text")
        }
    }

    // MARK: 역본 관주·각주

    @ViewBuilder
    private func translationNotes(_ ref: VerseRef) -> some View {
        let items = model.verseNotes(ref)
        if !items.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.mark)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.isFootnote ? Color.orange : Color.accentColor)
                                .frame(minWidth: 18, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                if item.isFootnote || item.refs.isEmpty {
                                    Text(plainNote(item.text)).font(.callout).textSelection(.enabled)
                                }
                                if !item.refs.isEmpty {
                                    FlowLayout(spacing: 6) {
                                        ForEach(item.refs, id: \.self) { address in
                                            refButton(address)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("\(model.primary?.short ?? "") 관주·각주", systemImage: "text.book.closed")
            }
        }
    }

    /// "요1:29" → 누르면 그 구절로, 마우스를 올리면 본문
    @ViewBuilder
    private func refButton(_ address: String) -> some View {
        // "막8:31-9:1", "왕하18-20" 처럼 장을 넘는 범위는 시작 위치로
        if let reference = ReferenceParser.parse(address)
            ?? ReferenceParser.parse(String(address.split(separator: "-").first ?? "")) {
            Button(address) {
                if reference.hasVerse { model.open(reference.start) } else { model.open(reference.chapter) }
            }
            .buttonStyle(.link)
            .font(.callout)
            .help(reference.hasVerse ? model.verseText(reference.start) : reference.chapter.label)
        } else {
            Text(address).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func plainNote(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    // MARK: 원어

    @ViewBuilder
    private func strongs(_ ref: VerseRef) -> some View {
        // 지금 역본에 원어 번호가 없으면 원어 번호가 있는 첫 역본(KJV 등)을 씀
        let source = model.primary?.hasStrongs == true ? model.primary : model.translations.first(where: \.hasStrongs)
        if let source, let tagged = model.database(for: source.id)?.verse(source.id, ref)?.tagged {
            let words = TaggedText.segments(tagged).filter { !$0.strongs.isEmpty }
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(source.short) 낱말에 붙은 원어 번호 — 클릭하면 뜻이 보여요")
                        .font(.caption).foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            ForEach(word.strongs, id: \.self) { code in
                                Button { model.selectedStrong = code } label: {
                                    VStack(spacing: 0) {
                                        Text(word.text).font(.callout)
                                        Text(code).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 5)
                                        .fill(model.selectedStrong == code ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let code = model.selectedStrong, let entry = model.strong(code) {
                        StrongCard(entry: entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("원어", systemImage: "character.book.closed")
            }
        }
    }

    // MARK: 관주

    @ViewBuilder
    private func crossRefs(_ ref: VerseRef) -> some View {
        let refs = model.crossRefs(ref)
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if refs.isEmpty {
                    Text("이 절에 연결된 관주가 없어요.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(refs, id: \.self) { item in
                    Button { model.open(item.target) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label).font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor)
                            Text(model.verseText(item.target))
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text("관주: OpenBible.info (CC BY)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("관주 \(refs.count)", systemImage: "link")
        }
    }
}

struct StrongCard: View {
    let entry: StrongEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.lemma).font(.title2)
                Text(entry.transliteration).italic()
                Spacer()
                Text(entry.id).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if !entry.pronunciation.isEmpty {
                Text("발음: \(entry.pronunciation)").font(.caption).foregroundStyle(.secondary)
            }
            labeled("뜻", entry.definition)
            labeled("KJV 번역", entry.kjvUsage)
            labeled("어원", entry.derivation)
            Text("Strong's 사전 (영어, OpenScriptures · CC BY-SA)").font(.caption2).foregroundStyle(.tertiary)
        }
        .textSelection(.enabled)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder
    private func labeled(_ title: String, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(text).font(.callout)
            }
        }
    }
}

/// 낱말 단추를 줄바꿈하며 늘어놓기
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? 300, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 300, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            for (index, x) in row.items {
                subviews[index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private struct Row { var items: [(Int, CGFloat)] = []; var y: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, !rows[rows.count - 1].items.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index, x))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
        }
        return rows
    }
}

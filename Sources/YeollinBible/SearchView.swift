import BibleCore
import SwiftUI

/// 찾기: 낱말로 찾기 + "요3:16" 같은 주소로 바로 가기
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Local private var query = ""
    @Local private var translationID = ""
    @Local private var scope = Scope.all
    @Local private var results: [VerseRow] = []
    @Local private var searched = ""
    @FocusState private var focused: Bool

    enum Scope: String, CaseIterable, Identifiable {
        case all = "성경 전체", old = "구약", new = "신약", book = "지금 읽는 책"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("찾을 말 또는 구절 주소 (예: 사랑, 목자, 요3:16)", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(run)
                Picker("범위", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 170)
                Picker("역본", selection: $translationID) {
                    ForEach(model.translations) { Text($0.short).tag($0.id) }
                }
                .frame(width: 140)
                Button("찾기", action: run).keyboardShortcut(.defaultAction)
            }
            .padding(14)
            Divider()

            if let reference = ReferenceParser.parse(query.trimmingCharacters(in: .whitespaces)) {
                Button {
                    if reference.hasVerse { model.open(reference.start) } else { model.open(reference.chapter) }
                } label: {
                    Label("\(reference.hasVerse ? reference.start.label : reference.chapter.label)(으)로 가기", systemImage: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .padding(12)
                Divider()
            }

            if !searched.isEmpty {
                HStack {
                    Text("‘\(searched)’ \(results.count)절\(results.count >= 2000 ? " 이상" : "")")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    if !results.isEmpty { bookCounts }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }

            List(results) { verse in
                Button { model.open(verse.ref) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verse.ref.label).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                        Text(highlighted(verse.text))
                            .font(model.textFont(language: model.translation(translationID)?.language ?? "ko", scale: 0.85))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { VerseMenu(refs: [verse.ref]) }
            }
            .overlay {
                if !searched.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: searched)
                } else if searched.isEmpty {
                    ContentUnavailableView("성경에서 찾기", systemImage: "magnifyingglass",
                                           description: Text("띄어쓰기가 달라도 찾아요. 여러 낱말을 띄어 쓰면 모두 들어간 절을 찾아요."))
                }
            }
        }
        .onAppear {
            if translationID.isEmpty { translationID = model.primaryID }
            focused = true
        }
    }

    private var bookCounts: some View {
        let counts = Dictionary(grouping: results, by: { $0.ref.book }).mapValues(\.count)
        let top = counts.sorted { $0.value > $1.value }.prefix(4)
        return Text(top.map { "\(Bible.book($0.key)?.short ?? "") \($0.value)" }.joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary)
    }

    private func run() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let db = model.database(for: translationID) else { return }
        let range: ClosedRange<Int>
        switch scope {
        case .all: range = 1...66
        case .old: range = 1...39
        case .new: range = 40...66
        case .book: range = model.location.book...model.location.book
        }
        results = db.search(translationID, query: text, books: range)
        searched = text
    }

    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for word in searched.split(separator: " ") {
            var start = attributed.startIndex
            while let range = attributed[start...].range(of: word, options: .caseInsensitive) {
                attributed[range].backgroundColor = Color.yellow.opacity(0.45)
                attributed[range].inlinePresentationIntent = .stronglyEmphasized
                start = range.upperBound
            }
        }
        return attributed
    }
}

import AppKit
import BibleCore
import SwiftUI
import UniformTypeIdentifiers

/// 역본 관리: 들어 있는 역본, 가져오기, 백업
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Local private var pending: PendingImport?
    @Local private var busy = false
    @Local private var message: String?
    @Local private var confirmDelete: BibleTranslation?
    @Local private var hymnBusy = false
    @Local private var hymnMessage: String?
    @Local private var confirmHymnDelete = false

    var body: some View {
        List {
            SwiftUI.Section {
                ForEach(model.translations) { translation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: translation.isImported ? "square.and.arrow.down" : "book.closed")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(translation.name).font(.headline)
                                Text(translation.short).font(.caption).padding(.horizontal, 5)
                                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                if translation.hasStrongs {
                                    Text("원어 번호").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("\(translation.license) · \(translation.source)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if translation.id == model.primaryID {
                            Text("읽는 중").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("읽기") { model.primaryID = translation.id; model.section = .reader }
                        }
                        if translation.isImported {
                            Button(role: .destructive) { confirmDelete = translation } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                                .help("이 역본 지우기")
                        }
                    }
                    .padding(.vertical, 10)
                }
            } header: {
                Text("역본")
            }

            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("내가 가진 성경 파일을 가져와서 읽을 수 있어요.")
                    Text("""
                    읽을 수 있는 형식: USFM 파일·폴더·zip (eBible.org 등), JSON, \
                    한 줄에 한 절인 글 파일 (예: `창 1:1 태초에…`, `GEN<탭>1<탭>1<탭>…`, `1,1,1,…`)
                    """)
                    .font(.callout).foregroundStyle(.secondary)
                    Text("개역개정·새번역·NIV 같은 역본은 저작권이 있어요. 사용 허락을 받은 파일만 가져오세요. 가져온 본문은 이 Mac에만 저장돼요.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button { chooseFiles() } label: { Label("파일 가져오기…", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.borderedProminent)
                            .disabled(busy)
                        if busy { ProgressView().controlSize(.small) }
                        if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                    }
                }
                .padding(.vertical, 10)
            } header: {
                Text("역본 가져오기")
            }

            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 8) {
                    if model.hymns.isEmpty {
                        Text("가져온 찬송가가 없어요. 악보 파일 폴더를 가져오면 ‘찬송가’ 화면에서 볼 수 있어요.")
                            .font(.callout)
                    } else {
                        Text("‘\(model.hymns.name)’ \(model.hymns.hymns.count)곡 — 이 Mac에만 저장돼 있어요.")
                            .font(.callout)
                    }
                    HStack {
                        HymnImportButton(busy: $hymnBusy, message: $hymnMessage,
                                         title: model.hymns.isEmpty ? "찬송가 폴더 가져오기…" : "다른 폴더로 바꾸기…")
                        if !model.hymns.isEmpty {
                            Button("찬송가 지우기", role: .destructive) { confirmHymnDelete = true }
                        }
                        if let hymnMessage { Text(hymnMessage).font(.callout).foregroundStyle(.secondary) }
                    }
                }
                .padding(.vertical, 10)
            } header: {
                Text("찬송가")
            }

            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("책갈피·형광펜·노트·감사·통독 기록을 파일 하나로 내보내고, 다른 Mac에서 가져올 수 있어요.")
                        .font(.callout)
                    HStack {
                        Button("백업 내보내기…", action: exportBackup)
                        Button("백업 가져오기…", action: importBackup)
                    }
                }
                .padding(.vertical, 10)
            } header: {
                Text("백업")
            }

            SwiftUI.Section {
                VStack(alignment: .leading, spacing: 4) {
                    credit("한글 성경 (공개본)", "eBible.org ‘Korean Bible 1910’ — 퍼블릭 도메인")
                    credit("KJV · WEB", "eBible.org — 퍼블릭 도메인")
                    credit("원어 사전", "Strong's Hebrew/Greek Dictionary, OpenScriptures — CC BY-SA")
                    credit("관주", "OpenBible.info Cross References — CC BY")
                    Text("열린성경은 갓피플성경의 기능을 참고해 새로 만든 오픈소스 앱이며, 갓피플과 관계가 없습니다.")
                        .font(.caption).foregroundStyle(.tertiary).padding(.top, 6)
                }
            } header: {
                Text("데이터 출처")
            }
        }
        .confirmationDialog("가져온 찬송가를 모두 지울까요?", isPresented: $confirmHymnDelete) {
            Button("지우기", role: .destructive) {
                model.hymns.removeAll()
                model.currentHymn = nil
            }
        }
        .sheet(item: $pending) { item in
            ImportSheet(item: item) { translation in
                save(item, as: translation)
            }
        }
        .confirmationDialog("‘\(confirmDelete?.name ?? "")’ 역본을 지울까요?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("지우기", role: .destructive) {
                if let target = confirmDelete {
                    model.imported?.deleteTranslation(target.id)
                    if model.primaryID == target.id { model.primaryID = "kor" }
                    if model.secondaryID == target.id { model.secondaryID = "kjv" }
                    model.reloadTranslations()
                }
                confirmDelete = nil
            }
        }
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.callout.weight(.semibold)).frame(width: 130, alignment: .leading)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: 가져오기

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.message = "성경 파일(USFM·JSON·글 파일·zip)이나 폴더를 고르세요"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        busy = true
        message = "읽는 중…"
        Task.detached {
            do {
                let result = try BibleImporter.load(urls: urls)
                await MainActor.run {
                    busy = false
                    message = nil
                    pending = PendingImport(result: result)
                }
            } catch {
                await MainActor.run {
                    busy = false
                    message = error.localizedDescription
                    DebugLog.write("가져오기 실패: \(error)")
                }
            }
        }
    }

    private func save(_ item: PendingImport, as translation: BibleTranslation) {
        guard let db = model.imported else { message = "저장할 곳을 열지 못했어요."; return }
        do {
            db.saveTranslation(translation, sort: 100)
            try db.saveVerses(item.result.verses, translation: translation.id)
            model.reloadTranslations()
            message = "‘\(translation.name)’ \(item.result.verses.count)절을 가져왔어요."
        } catch {
            message = "저장하지 못했어요: \(error)"
            DebugLog.write("가져온 역본 저장 실패: \(error)")
        }
    }

    // MARK: 백업

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let date = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "열린성경 백업 \(date).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.user.exportBackup(to: url)
            message = "백업을 저장했어요."
        } catch {
            message = "백업을 저장하지 못했어요: \(error.localizedDescription)"
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = "백업을 가져올까요?"
        alert.informativeText = "지금 있는 책갈피·형광펜·노트·감사·통독 기록이 백업 내용으로 바뀌어요."
        alert.addButton(withTitle: "가져오기")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try model.user.importBackup(from: url)
            message = "백업을 가져왔어요."
        } catch {
            message = "백업 파일을 읽지 못했어요: \(error.localizedDescription)"
        }
    }
}

struct PendingImport: Identifiable {
    let id = UUID()
    let result: BibleImporter.Result
}

/// 가져온 역본 이름 정하기
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: PendingImport
    let onSave: (BibleTranslation) -> Void
    @Local private var name = ""
    @Local private var short = ""
    @Local private var language = "ko"

    var body: some View {
        let verses = item.result.verses
        let books = Set(verses.map(\.ref.book)).count
        let looksKorean = verses.prefix(50).contains { $0.text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }

        Form {
            Text("\(books)권 · \(verses.count)절을 찾았어요").font(.headline)
            if let first = verses.first {
                Text("\(first.ref.label) \(first.text)").font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            TextField("역본 이름", text: $name)
            TextField("짧은 이름 (대역 머리글)", text: $short)
            Picker("언어", selection: $language) {
                Text("한국어").tag("ko")
                Text("영어").tag("en")
                Text("그 밖의 언어").tag("xx")
            }
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("가져오기") {
                    let id = "u-\(UUID().uuidString.prefix(8).lowercased())"
                    onSave(BibleTranslation(id: id, name: name.isEmpty ? "가져온 역본" : name,
                                       short: short.isEmpty ? String((name.isEmpty ? "가져옴" : name).prefix(4)) : short,
                                       language: language, license: "사용자가 가져옴", source: "이 Mac",
                                       hasStrongs: verses.contains { $0.tagged != nil }, isImported: true))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear {
            name = item.result.suggestedName ?? ""
            language = looksKorean ? "ko" : "en"
        }
    }
}

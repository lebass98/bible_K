import AppKit
import SwiftUI

/// 찬송가: 번호·제목·가사로 찾고 악보 보기
struct HymnView: View {
    @Environment(AppModel.self) private var model
    @Local private var query = ""
    @Local private var width: CGFloat = 900
    @Local private var showList = true

    private var narrow: Bool { width < 700 }

    var body: some View {
        Group {
            if model.hymns.isEmpty {
                HymnImportPrompt()
            } else if narrow {
                // 좁은 창: 목록과 악보를 번갈아 보여 줌
                if showList || model.currentHymn == nil {
                    list
                } else {
                    HymnSheetView(onShowList: { showList = true })
                }
            } else {
                HStack(spacing: 0) {
                    list.frame(width: 280)
                    Divider()
                    HymnSheetView(onShowList: nil)
                }
            }
        }
        .readWidth($width)
    }

    private var list: some View {
        @Bindable var model = model
        let results = model.hymns.search(query)
        let favorites = model.user.data.hymnFavorites
        return VStack(spacing: 0) {
            TextField("장 번호, 제목, 가사로 찾기", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(10)
                .onSubmit {
                    if let first = results.first { select(first.number) }
                }
            List(selection: Binding(get: { model.currentHymn }, set: { if let n = $0 { select(n) } })) {
                if query.isEmpty, !favorites.isEmpty {
                    SwiftUI.Section("즐겨찾기") {
                        ForEach(favorites.sorted(), id: \.self) { number in
                            if let hymn = model.hymns.hymn(number) { row(hymn).tag(hymn.number) }
                        }
                    }
                }
                SwiftUI.Section(query.isEmpty ? model.hymns.name : "찾은 곡 \(results.count)") {
                    ForEach(results) { hymn in
                        row(hymn).tag(hymn.number)
                    }
                }
            }
        }
    }

    private func row(_ hymn: Hymn) -> some View {
        HymnRow(hymn: hymn, favorite: model.user.data.hymnFavorites.contains(hymn.number))
    }

    private func select(_ number: Int) {
        model.currentHymn = number
        showList = false
    }
}

private struct HymnRow: View {
    let hymn: Hymn
    let favorite: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(hymn.number)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, alignment: .trailing)
            Text(hymn.title).lineLimit(1)
            Spacer(minLength: 0)
            if favorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
        }
    }
}

/// 악보 한 장 보기
struct HymnSheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    /// 좁은 창에서 목록으로 돌아가는 단추
    let onShowList: (() -> Void)?
    @Local private var zoom: Double = UserDefaults.standard.object(forKey: "hymnZoom") as? Double ?? 0
    @Local private var showLyrics = false
    @Local private var invert = UserDefaults.standard.bool(forKey: "hymnInvert")

    var body: some View {
        if let number = model.currentHymn, let hymn = model.hymns.hymn(number) {
            VStack(spacing: 0) {
                header(hymn)
                Divider()
                GeometryReader { geo in
                    ScrollView([.vertical, .horizontal]) {
                        content(hymn, available: geo.size.width)
                            .frame(minWidth: geo.size.width)
                    }
                }
            }
        } else {
            ContentUnavailableView("찬송가를 골라 주세요", systemImage: "music.note.list",
                                   description: Text("왼쪽 목록에서 고르거나 장 번호를 적으세요."))
        }
    }

    private func header(_ hymn: Hymn) -> some View {
        HStack(spacing: 10) {
            if let onShowList {
                Button { onShowList() } label: { Image(systemName: "list.bullet") }
                    .help("목록")
            }
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .help("이전 곡 (⌘←)")
                .disabled(model.hymns.hymns.first?.number == hymn.number)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(hymn.number)장").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(hymn.title).font(.headline).lineLimit(1)
            }
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .help("다음 곡 (⌘→)")
                .disabled(model.hymns.hymns.last?.number == hymn.number)
            Spacer(minLength: 4)
            Button {
                model.user.toggleHymnFavorite(hymn.number)
            } label: {
                Image(systemName: model.user.data.hymnFavorites.contains(hymn.number) ? "star.fill" : "star")
            }
            .help("즐겨찾기")
            if hymn.lyrics?.isEmpty == false {
                Toggle(isOn: $showLyrics) { Image(systemName: "text.alignleft") }
                    .toggleStyle(.button)
                    .help("가사만 크게 보기")
            }
            if colorScheme == .dark {
                Toggle(isOn: Binding(get: { invert }, set: { invert = $0; UserDefaults.standard.set($0, forKey: "hymnInvert") })) {
                    Image(systemName: "circle.lefthalf.filled")
                }
                .toggleStyle(.button)
                .help("다크 모드에서 악보 색 뒤집기")
            }
            Menu {
                Button("창에 맞추기") { setZoom(0) }
                Divider()
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                    Button("\(Int(value * 100))%") { setZoom(value) }
                }
            } label: {
                Text(zoom == 0 ? "맞춤" : "\(Int(zoom * 100))%").monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("악보 크기")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func content(_ hymn: Hymn, available: CGFloat) -> some View {
        if showLyrics, let lyrics = hymn.lyrics {
            Text(lyrics)
                .font(model.textFont(language: "ko", scale: 1.15))
                .lineSpacing(model.lineSpacing + 4)
                .textSelection(.enabled)
                .frame(maxWidth: 640, alignment: .leading)
                .padding(24)
        } else if let url = model.hymns.imageURL(hymn), let image = NSImage(contentsOf: url) {
            let natural = image.size.width
            let fitted = max(200, min(available - 32, 1100))
            let width = zoom == 0 ? fitted : natural * zoom
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
                .background(Color.white)
                .colorInvert(colorScheme == .dark && invert)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                .padding(16)
        } else {
            ContentUnavailableView("악보 파일이 없어요", systemImage: "photo",
                                   description: Text("\(hymn.number)장의 악보 파일을 찾지 못했어요."))
                .padding(40)
        }
    }

    private func setZoom(_ value: Double) {
        zoom = value
        UserDefaults.standard.set(value, forKey: "hymnZoom")
    }

    private func move(_ step: Int) { model.moveHymn(step) }
}

private extension View {
    @ViewBuilder
    func colorInvert(_ on: Bool) -> some View {
        if on { self.colorInvert() } else { self }
    }
}

/// 찬송가가 아직 없을 때: 가져오기 안내
struct HymnImportPrompt: View {
    @Environment(AppModel.self) private var model
    @Local private var busy = false
    @Local private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list").font(.system(size: 44)).foregroundStyle(Color.accentColor)
            Text("찬송가 악보를 가져오세요").font(.title2.bold())
            Text("""
            열린성경에는 찬송가 데이터가 들어 있지 않아요. 가지고 있는 악보 파일 폴더를 가져오면 \
            장 번호·제목·가사로 찾아서 볼 수 있어요. 가져온 파일은 이 Mac에만 저장돼요.
            """)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 480)
            VStack(alignment: .leading, spacing: 4) {
                Text("폴더 안에 넣을 것").font(.caption.weight(.semibold))
                Text("• 악보 파일: 이름에 장 번호 (예: `305.png`, `001.jpg`, `305 나 같은 죄인.pdf`)")
                Text("• 선택: `hymns.json` — 장 번호·제목·가사 목록")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HymnImportButton(busy: $busy, message: $message)
            if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 찬송가 폴더 고르기 → 복사 (오래 걸릴 수 있어 뒤에서 함)
struct HymnImportButton: View {
    @Environment(AppModel.self) private var model
    @Binding var busy: Bool
    @Binding var message: String?
    var title = "찬송가 폴더 가져오기…"

    var body: some View {
        HStack {
            Button(title, action: choose)
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            if busy { ProgressView().controlSize(.small) }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "악보 파일이 들어 있는 폴더를 고르세요"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true
        message = "가져오는 중…"
        Task.detached {
            do {
                let count = try HymnStore.importFolder(url)
                await MainActor.run {
                    model.hymns.load()
                    busy = false
                    message = "\(count)곡을 가져왔어요."
                    if model.currentHymn == nil { model.currentHymn = model.hymns.hymns.first?.number }
                }
            } catch {
                await MainActor.run {
                    busy = false
                    message = error.localizedDescription
                    DebugLog.write("찬송가 가져오기 실패: \(error)")
                }
            }
        }
    }
}

import AppKit
import CoreText
import SwiftUI

/// 본문 글꼴 고르기: 맥에 설치된 글꼴 + 사용자가 추가한 글꼴 파일
enum FontLibrary {
    /// 기본값으로 고를 수 있는 것 (글꼴 이름 대신 저장하는 값)
    static let system = ""             // 시스템 고딕 (San Francisco · Apple SD 산돌고딕 Neo)
    static let myungjo = "@myungjo"    // 한글은 애플명조, 영어는 시스템 세리프
    static let sameAsBody = "@same"    // 영어 글꼴: 본문 글꼴과 같게

    /// 추가한 글꼴 파일을 두는 곳
    static let folder: URL = {
        let url = UserStore.folder.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let fontExtensions: Set<String> = ["ttf", "otf", "ttc", "otc"]

    /// 앱이 켜질 때 추가해 둔 글꼴 파일을 이 앱에서 쓸 수 있게 등록
    static func registerUserFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where fontExtensions.contains(file.pathExtension.lowercased()) {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error) {
                DebugLog.write("글꼴 등록 실패 \(file.lastPathComponent): \(error?.takeRetainedValue().localizedDescription ?? "")")
            }
        }
    }

    /// 글꼴 파일을 복사해 두고 등록. 새로 생긴 글꼴 이름(패밀리)들을 돌려줌
    static func add(_ urls: [URL]) -> (families: [String], failed: [String]) {
        var families: [String] = []
        var failed: [String] = []
        for url in urls where fontExtensions.contains(url.pathExtension.lowercased()) {
            let target = folder.appendingPathComponent(url.lastPathComponent)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            guard !descriptors.isEmpty else { failed.append(url.lastPathComponent); continue }
            do {
                if FileManager.default.fileExists(atPath: target.path) {
                    CTFontManagerUnregisterFontsForURL(target as CFURL, .process, nil)
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.copyItem(at: url, to: target)
            } catch {
                failed.append(url.lastPathComponent)
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(target as CFURL, .process, &error) {
                for descriptor in descriptors {
                    if let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
                       !families.contains(family) {
                        families.append(family)
                    }
                }
            } else {
                failed.append(url.lastPathComponent)
            }
        }
        cachedFamilies = nil
        return (families, failed)
    }

    /// 사용자가 추가한 글꼴 패밀리 이름들
    static func userFamilies() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var result = Set<String>()
        for file in files {
            for descriptor in CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor] ?? [] {
                if let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String {
                    result.insert(family)
                }
            }
        }
        return result
    }

    static func removeUserFont(family: String) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let names = (CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor] ?? [])
                .compactMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String }
            if names.contains(family) {
                CTFontManagerUnregisterFontsForURL(file as CFURL, .process, nil)
                try? FileManager.default.removeItem(at: file)
            }
        }
        cachedFamilies = nil
    }

    // MARK: 목록

    struct Family: Identifiable, Hashable {
        let name: String          // 글꼴 패밀리 이름 (저장하는 값)
        let displayName: String   // 화면에 보이는 이름 (한글 이름이 있으면 한글)
        let supportsKorean: Bool
        var id: String { name }
    }

    private static var cachedFamilies: [Family]?

    static func families() -> [Family] {
        if let cachedFamilies { return cachedFamilies }
        let manager = NSFontManager.shared
        let result = manager.availableFontFamilies
            .filter { !$0.hasPrefix(".") }   // 시스템 내부용 글꼴은 뺌
            .map { name -> Family in
                let display = manager.localizedName(forFamily: name, face: nil)
                return Family(name: name, displayName: display.isEmpty ? name : display, supportsKorean: supportsKorean(name))
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        cachedFamilies = result
        return result
    }

    static func supportsKorean(_ family: String) -> Bool {
        guard let member = NSFontManager.shared.availableMembers(ofFontFamily: family)?.first,
              let postScript = member.first as? String,
              let font = NSFont(name: postScript, size: 12) else { return false }
        return font.coveredCharacterSet.contains(Unicode.Scalar(0xAC00)!)   // "가"
    }

    static func displayName(_ choice: String) -> String {
        switch choice {
        case system: return "시스템 고딕"
        case myungjo: return "명조 (애플명조)"
        case sameAsBody: return "본문 글꼴과 같게"
        default:
            let name = NSFontManager.shared.localizedName(forFamily: choice, face: nil)
            return name.isEmpty ? choice : name
        }
    }

    /// 고른 값으로 SwiftUI 글꼴 만들기
    static func font(_ choice: String, size: CGFloat, latin: Bool) -> Font {
        switch choice {
        case system: return .system(size: size)
        case myungjo: return latin ? .system(size: size, design: .serif) : .custom("AppleMyungjo", size: size)
        default:
            // 지워진 글꼴이면 시스템 글꼴로
            guard NSFontManager.shared.availableMembers(ofFontFamily: choice) != nil else { return .system(size: size) }
            return .custom(choice, size: size)
        }
    }
}

/// 글꼴 목록 (찾기 + 한글 되는 글꼴만 + 미리보기)
struct FontPickerList: View {
    @Binding var selection: String
    /// 영어 글꼴을 고를 때는 "본문 글꼴과 같게"를 맨 위에 보여 줌
    var includeSameAsBody = false
    var sample = "태초에 하나님이 천지를 창조하시니라 In the beginning"

    @Local private var query = ""
    @Local private var koreanOnly = true
    @Local private var families: [FontLibrary.Family] = []
    @Local private var userFamilies: Set<String> = []
    @Local private var message: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("글꼴 찾기", text: $query)
                    .textFieldStyle(.roundedBorder)
                Toggle("한글 되는 글꼴만", isOn: $koreanOnly)
                    .toggleStyle(.checkbox)
            }
            List {
                if query.isEmpty {
                    if includeSameAsBody { presetRow(FontLibrary.sameAsBody) }
                    presetRow(FontLibrary.system)
                    presetRow(FontLibrary.myungjo)
                }
                ForEach(filtered) { family in
                    row(family)
                }
            }
            .listStyle(.plain)
            HStack {
                Button { addFonts() } label: { Label("글꼴 파일 추가…", systemImage: "plus") }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Spacer()
                Text("\(filtered.count)개 · 파일을 끌어다 놓아도 돼요").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: reload)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { install([url]) }
                }
            }
            return true
        }
    }

    private var filtered: [FontLibrary.Family] {
        families.filter { family in
            (!koreanOnly || family.supportsKorean || userFamilies.contains(family.name))
                && (query.isEmpty || family.displayName.localizedCaseInsensitiveContains(query)
                    || family.name.localizedCaseInsensitiveContains(query))
        }
    }

    private func reload() {
        families = FontLibrary.families()
        userFamilies = FontLibrary.userFamilies()
        // 영어 글꼴을 고를 때는 한글 여부를 따지지 않음
        if includeSameAsBody { koreanOnly = false }
    }

    private func presetRow(_ choice: String) -> some View {
        Button { selection = choice } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(FontLibrary.displayName(choice)).font(.callout.weight(.semibold))
                    if choice != FontLibrary.sameAsBody {
                        Text(sample).font(FontLibrary.font(choice, size: 15, latin: false)).lineLimit(1)
                    }
                }
                Spacer()
                if selection == choice { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private func row(_ family: FontLibrary.Family) -> some View {
        Button { selection = family.name } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(family.displayName).font(.callout.weight(.semibold))
                        if userFamilies.contains(family.name) {
                            Text("추가함").font(.caption2).padding(.horizontal, 4)
                                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                        }
                    }
                    Text(sample).font(.custom(family.name, size: 15)).lineLimit(1)
                }
                Spacer()
                if selection == family.name { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .contextMenu {
            if userFamilies.contains(family.name) {
                Button("추가한 글꼴 지우기", role: .destructive) {
                    FontLibrary.removeUserFont(family: family.name)
                    if selection == family.name { selection = FontLibrary.myungjo }
                    reload()
                }
            }
        }
    }

    private func addFonts() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.font]
        panel.message = "글꼴 파일(.ttf, .otf)을 고르세요. 이 앱에서만 쓰이고 맥 전체에는 설치되지 않아요."
        guard panel.runModal() == .OK else { return }
        install(panel.urls)
    }

    private func install(_ urls: [URL]) {
        let result = FontLibrary.add(urls)
        reload()
        if let first = result.families.first {
            selection = first
            message = "추가했어요: \(result.families.joined(separator: ", "))"
        }
        if !result.failed.isEmpty {
            message = "읽지 못한 파일: \(result.failed.joined(separator: ", "))"
        }
    }
}

/// 본문 도구 막대의 "가" 단추: 글꼴·크기·줄 간격을 바로 바꿈
struct TextStylePanel: View {
    @Environment(AppModel.self) private var model
    @Local private var latin = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            AppearancePicker()
            FontSizeControl()
            HStack {
                Text("줄 간격").frame(width: 64, alignment: .leading)
                Slider(value: $model.lineSpacing, in: 0...16, step: 1)
            }
            Picker("", selection: $latin) {
                Text("본문 글꼴").tag(false)
                Text("영어 역본 글꼴").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if latin {
                FontPickerList(selection: $model.latinFontFamily, includeSameAsBody: true,
                               sample: "In the beginning God created the heaven and the earth.")
            } else {
                FontPickerList(selection: $model.fontFamily)
            }
        }
        .buttonStyle(.borderless)
        .padding(14)
        .frame(width: 440, height: 520)
    }
}

/// 글자 크기: 단계 단추 + 세밀하게 밀기
struct FontSizeControl: View {
    @Environment(AppModel.self) private var model

    static let presets: [(String, Double)] = [("작게", 15), ("보통", 18), ("크게", 22), ("아주 크게", 28)]

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("글자 크기").frame(width: 64, alignment: .leading)
                ForEach(Self.presets, id: \.0) { title, size in
                    Button(title) { model.fontSize = size }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(model.fontSize == size ? .accentColor : nil)
                }
            }
            HStack {
                Spacer().frame(width: 64)
                Button { model.fontSize = max(model.fontSize - 1, 12) } label: { Image(systemName: "textformat.size.smaller") }
                    .buttonStyle(.borderless)
                    .help("작게 (⌘-)")
                Slider(value: $model.fontSize, in: 12...40, step: 1)
                Button { model.fontSize = min(model.fontSize + 1, 40) } label: { Image(systemName: "textformat.size.larger") }
                    .buttonStyle(.borderless)
                    .help("크게 (⌘+)")
                Text("\(Int(model.fontSize))pt").monospacedDigit().frame(width: 36)
            }
        }
    }
}

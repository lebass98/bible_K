import AppKit
import BibleCore
import SwiftUI

/// 읽기 화면은 따뜻한 종이색, 조작부는 낮은 채도의 녹색으로 구분한다.
/// NSColor의 동적 제공자를 사용하므로 기존 자동/라이트/다크 설정을 그대로 따른다.
enum BibleStyle {
    static var canvas: Color { adaptive(light: 0xF2F2EC, dark: 0x1B231E) }
    static var paper: Color { adaptive(light: 0xFFFEFA, dark: 0x242D27) }
    static var accent: Color { adaptive(light: 0x41634E, dark: 0xB3CCAC) }
    static var rule: Color { adaptive(light: 0xDEE3D8, dark: 0x3B493E) }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

/// 네이티브 목록 선택·키보드 탐색을 유지하며 목적별로 묶은 탐색 영역.
struct BibleSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.section) {
            Section("말씀과 함께") { rows([.reader, .search, .today]) }
            Section("나의 묵상") { rows([.records, .history, .plan, .thanks]) }
            Section("신앙의 일상") { rows([.hymns, .prayer, .creeds]) }
            Section("라이브러리") { rows([.library]) }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            BibleBrandLogo(width: 174)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 18)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { model.section = .reader } label: {
                HStack(spacing: 10) {
                    Image(systemName: "leaf").foregroundStyle(BibleStyle.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("지금 읽는 말씀").font(.caption2).foregroundStyle(.secondary)
                        Text(model.location.label).font(.callout.weight(.medium))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(BibleStyle.rule).frame(height: 1) }
            .help("읽던 말씀으로 돌아가기")
        }
    }

    private func rows(_ sections: [AppSection]) -> some View {
        ForEach(sections) { section in
            Label(section.title, systemImage: section.icon)
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 3)
                .tag(section)
        }
    }
}

/// macOS 앱 묶음의 실제 브랜드 리소스. 개발 중 리소스가 없어도 화면은 동작한다.
enum BibleBrand {
    static func image(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Brand") else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct BibleBrandLogo: View {
    var width: CGFloat = 180

    var body: some View {
        Group {
            if let image = BibleBrand.image("Logo") {
                Image(nsImage: image).resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(BibleStyle.accent)
            } else {
                Label("열린성경", systemImage: "book.closed.fill").font(.title2.weight(.semibold))
                    .foregroundStyle(BibleStyle.accent)
            }
        }
        .frame(width: width, height: width * 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("열린성경 YEOLLIN BIBLE")
    }
}

/// 앱에 들어온 첫날만 표시하며, 기다림을 강제하지 않는 시작 화면.
struct BibleWelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onStart: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BibleStyle.canvas
                if let image = BibleBrand.image(colorScheme == .dark ? "Welcome-Dark" : "Welcome-Light") {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().accessibilityHidden(true)
                }
                VStack(spacing: 16) {
                    BibleBrandLogo(width: min(260, geometry.size.width * 0.55))
                    Text("말씀을 읽고, 마음을 열다.")
                        .font(.system(size: 13, weight: .medium)).tracking(1.5)
                        .foregroundStyle(BibleStyle.accent)
                    Button(action: onStart) {
                        Label("말씀 읽기 시작하기", systemImage: "arrow.right")
                            .padding(.horizontal, 16).padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 8)
                    Spacer(minLength: 0)
                }
                .padding(.top, max(25, geometry.size.height * 0.1))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("brand-welcome")
    }
}

/// 본문 이외의 화면을 묶는 공통 문서 레이아웃. 실제 목록·입력 기능은 각 화면에 둔다.
private struct BibleWorkspace: ViewModifier {
    let section: AppSection
    @Local private var width: CGFloat = 900

    private var copy: (String, String, String) {
        switch section {
        case .records: return ("YOUR QUIET COLLECTION", "오래 간직하고 싶은 말씀.", "책갈피와 형광펜, 묵상 노트를 한곳에서 돌아보세요.")
        case .history: return ("THE PATH YOU HAVE READ", "말씀을 따라 걸어온 시간.", "읽었던 말씀으로 돌아가, 다시 이어가세요.")
        case .plan: return ("ONE CHAPTER AT A TIME", "작은 읽기가 쌓이는 날들.", "내 속도에 맞는 계획으로 오늘의 말씀에 집중해보세요.")
        case .thanks: return ("SMALL MOMENTS, DEEP GRATITUDE", "오늘의 감사 한 줄.", "마음에 남은 작은 순간을 기록해보세요.")
        case .prayer: return ("WORDS FROM THE HEART", "마음을 모으는 기도.", "기도 제목과 작은 응답을 함께 기억하세요.")
        case .hymns: return ("SONGS FOR THE SOUL", "마음으로 부르는 찬송.", "내 악보와 가사를 편안하게 살펴보세요.")
        case .creeds: return ("WORDS OF FAITH", "함께 고백하는 믿음.", "익숙한 고백을 또렷하게, 예배의 흐름 속에서.")
        case .library: return ("YOUR BIBLE LIBRARY", "나에게 익숙한 말씀으로.", "읽을 역본을 고르고, 내 자료와 기록을 관리하세요.")
        default: return ("YEOLLIN BIBLE", section.title, "")
        }
    }

    func body(content: Content) -> some View {
        let compact = width < 580
        VStack(alignment: .leading, spacing: compact ? 14 : 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text(copy.0).font(.system(size: 10, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(BibleStyle.accent)
                Text(copy.1).font(.system(size: compact ? 22 : 28, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if width >= 520 {
                    Text(copy.2).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, compact ? 4 : 8)
            content
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BibleStyle.paper, in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(BibleStyle.rule.opacity(0.8), lineWidth: 1) }
        }
        .frame(maxWidth: 1100, maxHeight: .infinity, alignment: .topLeading)
        .padding(compact ? 14 : 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BibleStyle.canvas)
        .readWidth($width)
    }
}

extension View {
    func bibleWorkspace(_ section: AppSection) -> some View { modifier(BibleWorkspace(section: section)) }
}

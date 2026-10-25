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
            Section("말씀과 함께") { rows([.reader, .search, .today, .hymns, .creeds]) }
            Section("나의 묵상") { rows([.records, .history, .plan, .prayer, .thanks]) }
            Section("라이브러리") { rows([.library]) }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(BibleStyle.accent)
                    .frame(width: 36, height: 40)
                    .background(BibleStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text("열린성경").font(.system(size: 19, weight: .semibold))
                    Text("YEOLLIN BIBLE").font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 24)
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
                .padding(.vertical, 5)
                .tag(section)
        }
    }
}

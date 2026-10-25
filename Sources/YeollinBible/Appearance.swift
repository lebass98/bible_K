import AppKit
import SwiftUI

/// 화면 모양: 시스템 설정 따르기 · 라이트 · 다크
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "시스템 설정 따르기"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var shortTitle: String {
        switch self {
        case .system: return "자동"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// SwiftUI의 preferredColorScheme(nil)은 맥에서 시스템 설정으로 잘 돌아오지 않아서 앱 전체 모양을 직접 바꿈
    func apply() {
        switch self {
        case .system: NSApp?.appearance = nil
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// 모양 고르기 (세 칸 단추)
struct AppearancePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Picker("모양", selection: $model.appearance) {
            ForEach(AppAppearance.allCases) { item in
                Label(item.shortTitle, systemImage: item.icon).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
}

extension View {
    /// 이 뷰의 너비를 재서 넘겨 줌 (창 크기에 따라 배치를 바꿀 때 씀)
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { width.wrappedValue = geo.size.width }
                    .onChange(of: geo.size.width) { _, value in width.wrappedValue = value }
            }
        )
    }
}

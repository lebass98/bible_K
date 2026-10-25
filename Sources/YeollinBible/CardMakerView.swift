import AppKit
import BibleCore
import SwiftUI
import UniformTypeIdentifiers

/// 말씀 카드 (그림으로 저장하거나 복사)
struct CardMakerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let verses: [VerseRow]

    @Local private var theme = CardTheme.all[0]
    @Local private var shape = CardShape.square
    @Local private var textScale = 1.0
    @Local private var centered = true
    @Local private var message: String?

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            canvas(width: previewWidth)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 6)
                .frame(width: previewWidth, height: previewWidth * shape.ratio)

            VStack(alignment: .leading, spacing: 14) {
                Text("말씀 카드").font(.title3.bold())
                Text("배경").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 5), spacing: 8) {
                    ForEach(CardTheme.all) { item in
                        Button { theme = item } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: theme.id == item.id ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Picker("모양", selection: $shape) {
                    ForEach(CardShape.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("글자")
                    Slider(value: $textScale, in: 0.6...1.6)
                }
                Toggle("가운데 맞춤", isOn: $centered)
                Spacer()
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button("복사", action: copyImage)
                    Button("저장…", action: saveImage).buttonStyle(.borderedProminent)
                }
                Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .frame(width: 230)
        }
        .padding(20)
    }

    private var previewWidth: CGFloat { shape == .story ? 290 : 400 }

    private func cardFont(size: CGFloat) -> Font {
        model.textFont(language: model.primary?.language ?? "ko", size: size)
    }

    private var reference: String {
        guard let first = verses.first?.ref, let last = verses.last?.ref else { return "" }
        return first == last ? first.label : "\(first.label)-\(last.verse)"
    }

    private func canvas(width: CGFloat) -> some View {
        let unit = width / 1080
        let text = verses.map(\.text).joined(separator: " ")
        let length = Double(text.count)
        // 글이 길수록 글자를 줄임
        let base = max(34, min(72, 72 - (length - 60) * 0.12)) * textScale
        return ZStack {
            LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: centered ? .center : .leading, spacing: 40 * unit) {
                Text(text)
                    .font(cardFont(size: base * unit))
                    .lineSpacing(base * unit * 0.45)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .minimumScaleFactor(0.5)
                Text("\(reference) · \(model.primary?.short ?? "")")
                    .font(.system(size: 30 * unit, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(theme.text)
            .padding(110 * unit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centered ? .center : .leading)
        }
        .frame(width: width, height: width * shape.ratio)
    }

    private func render() -> NSImage? {
        let renderer = ImageRenderer(content: canvas(width: 1080).environment(model))
        renderer.scale = 1
        return renderer.nsImage
    }

    private func copyImage() {
        guard let image = render() else { message = "그림을 만들지 못했어요."; return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        message = "그림을 복사했어요. 메신저 등에 붙여 넣으세요."
    }

    private func saveImage() {
        guard let image = render(), let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            message = "그림을 만들지 못했어요."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(reference.replacingOccurrences(of: ":", with: "_")).png"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try png.write(to: url)
                message = "저장했어요: \(url.lastPathComponent)"
            } catch {
                message = "저장하지 못했어요: \(error.localizedDescription)"
            }
        }
    }
}

struct CardTheme: Identifiable {
    let id: Int
    let colors: [Color]
    let text: Color

    static let all: [CardTheme] = [
        CardTheme(id: 0, colors: [Color(red: 0.98, green: 0.95, blue: 0.88), Color(red: 0.93, green: 0.86, blue: 0.74)], text: Color(red: 0.25, green: 0.2, blue: 0.15)),
        CardTheme(id: 1, colors: [Color(red: 0.12, green: 0.18, blue: 0.35), Color(red: 0.3, green: 0.22, blue: 0.5)], text: .white),
        CardTheme(id: 2, colors: [Color(red: 0.98, green: 0.78, blue: 0.62), Color(red: 0.93, green: 0.45, blue: 0.5)], text: .white),
        CardTheme(id: 3, colors: [Color(red: 0.75, green: 0.9, blue: 0.82), Color(red: 0.36, green: 0.66, blue: 0.6)], text: Color(red: 0.08, green: 0.2, blue: 0.18)),
        CardTheme(id: 4, colors: [Color(red: 0.86, green: 0.92, blue: 1.0), Color(red: 0.55, green: 0.7, blue: 0.95)], text: Color(red: 0.08, green: 0.15, blue: 0.3)),
        CardTheme(id: 5, colors: [.white, Color(white: 0.92)], text: Color(white: 0.15)),
        CardTheme(id: 6, colors: [Color(white: 0.15), Color(white: 0.05)], text: Color(white: 0.95)),
        CardTheme(id: 7, colors: [Color(red: 0.95, green: 0.88, blue: 0.96), Color(red: 0.72, green: 0.62, blue: 0.9)], text: Color(red: 0.2, green: 0.12, blue: 0.3)),
        CardTheme(id: 8, colors: [Color(red: 1.0, green: 0.93, blue: 0.6), Color(red: 1.0, green: 0.72, blue: 0.35)], text: Color(red: 0.3, green: 0.18, blue: 0.05)),
        CardTheme(id: 9, colors: [Color(red: 0.2, green: 0.35, blue: 0.25), Color(red: 0.08, green: 0.2, blue: 0.15)], text: Color(red: 0.95, green: 0.93, blue: 0.85)),
    ]
}

enum CardShape: String, CaseIterable, Identifiable {
    case square, portrait, story
    var id: String { rawValue }
    var title: String {
        switch self {
        case .square: return "정사각형"
        case .portrait: return "세로 (4:5)"
        case .story: return "스토리 (9:16)"
        }
    }
    var ratio: CGFloat {
        switch self {
        case .square: return 1
        case .portrait: return 1.25
        case .story: return 16.0 / 9.0
        }
    }
}

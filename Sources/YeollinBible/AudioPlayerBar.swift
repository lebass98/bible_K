import BibleCore
import SwiftUI

/// 읽기 화면 아래의 오디오 성경 재생 막대
struct AudioPlayerBar: View {
    @Environment(AppModel.self) private var model
    var compact = false

    var body: some View {
        let audio = model.audio
        VStack(spacing: 6) {
            HStack(spacing: compact ? 10 : 14) {
                if let chapter = audio.chapter {
                    // 다른 장을 보고 있으면 듣는 장으로 돌아가는 단추
                    Button {
                        if let verse = audio.currentVerse { model.open(verse, select: false) } else { model.open(chapter) }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(audio.currentVerse.map { "\($0.chapter):\($0.verse)" } ?? chapter.label)
                                .font(.caption.monospacedDigit().weight(.semibold))
                            if !compact {
                                Text(chapter.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help("듣는 곳으로 가기")
                }
                if let prefix = audio.prefix, let chapter = audio.chapter {
                    setMenu(prefix, chapter)
                }
                Spacer(minLength: 0)
                Group {
                    Button { audio.step(verses: -1) } label: { Image(systemName: "backward.end.fill") }
                        .help("이전 절")
                    Button { audio.togglePause() } label: {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                    }
                    .help(audio.isPlaying ? "잠시 멈춤" : "계속 듣기")
                    Button { audio.step(verses: 1) } label: { Image(systemName: "forward.end.fill") }
                        .help("다음 절")
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                rateMenu
                Button { model.audio.stop() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("듣기 끝내기")
            }
            HStack(spacing: 8) {
                Text(timeText(audio.currentTime)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Slider(value: Binding(get: { audio.currentTime }, set: { audio.seek(to: $0) }),
                       in: 0...max(audio.duration, 1))
                    .controlSize(.small)
                Text(timeText(audio.duration)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let error = audio.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    /// 이 장에 있는 다른 음원으로 바꾸기
    private func setMenu(_ prefix: String, _ chapter: ChapterRef) -> some View {
        let audio = model.audio
        return Menu {
            ForEach(audio.availablePrefixes(for: chapter), id: \.self) { key in
                Button {
                    model.audio.chosenSet[model.primaryID] = key
                    let verse = audio.currentVerse?.verse
                    model.audio.play(chapter, prefix: key, from: verse)
                } label: {
                    if key == prefix { Label(audio.sets[key]?.name ?? key, systemImage: "checkmark") } else { Text(audio.sets[key]?.name ?? key) }
                }
            }
        } label: {
            Text(audio.sets[prefix]?.name ?? prefix).font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("음원 바꾸기")
    }

    private var rateMenu: some View {
        Menu {
            ForEach([0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 2.0], id: \.self) { value in
                Button(String(format: "%.2g배", value)) { model.audio.rate = value }
            }
        } label: {
            Text(String(format: "%.2g×", model.audio.rate)).font(.caption.monospacedDigit())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("빠르기")
    }

    private func timeText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

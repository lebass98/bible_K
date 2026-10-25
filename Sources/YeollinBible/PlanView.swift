import BibleCore
import SwiftUI

/// 통독 계획 (장 길이를 절 수로 재서 날마다 읽을 양을 고르게 나눔)
struct ReadingPlan: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String

    static let all: [ReadingPlan] = [
        ReadingPlan(id: "bible365", title: "성경 1년 통독", detail: "창세기부터 요한계시록까지 365일", icon: "book"),
        ReadingPlan(id: "parallel365", title: "구약·신약 함께 1년", detail: "날마다 구약과 신약을 함께 365일", icon: "rectangle.split.2x1"),
        ReadingPlan(id: "bible90", title: "90일 통독", detail: "성경 전체를 90일에", icon: "hare"),
        ReadingPlan(id: "nt90", title: "신약 90일", detail: "마태복음부터 요한계시록까지 90일", icon: "cross"),
        ReadingPlan(id: "psalmsProverbs", title: "시편·잠언 한 달", detail: "날마다 시편 몇 편과 잠언 한 장, 31일", icon: "music.note"),
    ]

    static func find(_ id: String) -> ReadingPlan? { all.first { $0.id == id } }

    /// 날마다 읽을 장 목록
    func days(verseCounts: [ChapterRef: Int]) -> [[ChapterRef]] {
        func chapters(_ books: ClosedRange<Int>) -> [ChapterRef] {
            books.flatMap { book in (1...(Bible.book(book)?.chapters ?? 1)).map { ChapterRef(book: book, chapter: $0) } }
        }
        let weight: (ChapterRef) -> Double = { Double(verseCounts[$0] ?? 25) }
        switch id {
        case "parallel365":
            let old = Self.split(chapters(1...39), days: 365, weight: weight)
            let new = Self.split(chapters(40...66), days: 365, weight: weight)
            return zip(old, new).map { $0 + $1 }
        case "bible90": return Self.split(chapters(1...66), days: 90, weight: weight)
        case "nt90": return Self.split(chapters(40...66), days: 90, weight: weight)
        case "psalmsProverbs":
            let psalms = Self.split(chapters(19...19), days: 31, weight: weight)
            return psalms.enumerated().map { $1 + [ChapterRef(book: 20, chapter: $0 + 1)] }
        default: return Self.split(chapters(1...66), days: 365, weight: weight)
        }
    }

    /// 남은 양을 남은 날 수로 나눠 가며 채움 (빈 날이 생기지 않게)
    static func split(_ chapters: [ChapterRef], days: Int, weight: (ChapterRef) -> Double) -> [[ChapterRef]] {
        var result: [[ChapterRef]] = []
        var index = 0
        var remaining = chapters.reduce(0) { $0 + weight($1) }
        for day in 0..<days {
            let daysLeft = days - day
            let target = remaining / Double(daysLeft)
            var today: [ChapterRef] = []
            var amount = 0.0
            while index < chapters.count {
                let w = weight(chapters[index])
                let chaptersLeft = chapters.count - index
                let mustLeave = chaptersLeft <= daysLeft - 1 && !today.isEmpty   // 뒤의 날에 한 장씩은 남김
                if !today.isEmpty && (amount + w / 2 > target || mustLeave) { break }
                today.append(chapters[index])
                amount += w
                index += 1
            }
            if day == days - 1 { while index < chapters.count { today.append(chapters[index]); index += 1 } }
            remaining -= amount
            result.append(today)
        }
        return result
    }

    /// "창 1–3장 · 마 1장"
    static func label(_ chapters: [ChapterRef]) -> String {
        var parts: [String] = []
        var i = 0
        while i < chapters.count {
            let book = chapters[i].book
            var j = i
            while j + 1 < chapters.count, chapters[j + 1].book == book, chapters[j + 1].chapter == chapters[j].chapter + 1 { j += 1 }
            let name = Bible.book(book)?.short ?? ""
            let unit = book == 19 ? "편" : "장"
            parts.append(i == j ? "\(name) \(chapters[i].chapter)\(unit)" : "\(name) \(chapters[i].chapter)–\(chapters[j].chapter)\(unit)")
            i = j + 1
        }
        return parts.joined(separator: " · ")
    }
}

extension AppModel {
    var planDays: [[ChapterRef]] {
        guard let progress = user.data.plan, let plan = ReadingPlan.find(progress.planID) else { return [] }
        return plan.days(verseCounts: bundled?.verseCounts("kjv") ?? [:])
    }

    /// 계획 시작일부터 오늘이 몇 번째 날인지 (0부터)
    var planTodayIndex: Int {
        guard let start = user.data.plan?.start else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, days)
    }
}

struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Local private var confirmStop = false
    @Local private var starting: ReadingPlan?

    var body: some View {
        Group {
            if let progress = model.user.data.plan, let plan = ReadingPlan.find(progress.planID) {
                active(plan, progress)
            } else {
                chooser
            }
        }
        .sheet(item: $starting) { plan in
            PlanStartSheet(plan: plan) { start in
                model.user.data.plan = PlanProgress(planID: plan.id, start: Calendar.current.startOfDay(for: start))
                Reminders.reschedule(model: model)
                starting = nil
            }
        }
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("통독 계획을 골라 시작하세요").font(.title2.bold())
                Text("장마다 길이가 달라서, 절 수를 재서 날마다 읽을 양을 고르게 나눴어요.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    ForEach(ReadingPlan.all) { plan in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: plan.icon).font(.title2).foregroundStyle(Color.accentColor)
                            Text(plan.title).font(.headline)
                            Text(plan.detail).font(.callout).foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Button("이 계획으로 시작") { starting = plan }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                        .background(BibleStyle.canvas, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(BibleStyle.rule, lineWidth: 1) }
                    }
                }
            }
            .padding(24)
        }
    }

    private func active(_ plan: ReadingPlan, _ progress: PlanProgress) -> some View {
        let days = model.planDays
        let today = min(model.planTodayIndex, max(days.count - 1, 0))
        let behind = (0..<today).filter { !progress.done.contains($0) }.count
        let doneCount = progress.done.count

        return ScrollViewReader { proxy in
            List {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(plan.title).font(.title2.bold())
                        Spacer()
                        Text("\(doneCount) / \(days.count)일").foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(doneCount), total: Double(max(days.count, 1)))
                    if !days.isEmpty {
                        todayCard(day: today, chapters: days[today], done: progress.done.contains(today))
                    }
                    HStack(spacing: 14) {
                        if behind > 0 {
                            Label("밀린 날 \(behind)일", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                        } else {
                            Label("밀린 날 없음", systemImage: "checkmark.seal").foregroundStyle(.green)
                        }
                        Spacer()
                        ReminderToggle(kind: .plan)
                    }
                    .font(.callout)
                }
                .padding(.vertical, 8)

                SwiftUI.Section("전체 일정") {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, chapters in
                        dayRow(index, chapters, progress: progress, isToday: index == today)
                            .id(index)
                    }
                }
            }
            .onAppear { if today > 3 { proxy.scrollTo(today - 2, anchor: .top) } }
        }
        .toolbar {
            Menu {
                Button("오늘부터 다시 시작 (체크 기록 지움)") {
                    model.user.data.plan = PlanProgress(planID: plan.id, start: Calendar.current.startOfDay(for: Date()))
                }
                Button("통독 그만두기", role: .destructive) { confirmStop = true }
            } label: { Label("계획", systemImage: "ellipsis.circle") }
        }
        .confirmationDialog("통독 계획을 그만둘까요? 체크한 기록도 지워져요.", isPresented: $confirmStop) {
            Button("그만두기", role: .destructive) {
                model.user.data.plan = nil
                Reminders.reschedule(model: model)
            }
        }
    }

    private func todayCard(day: Int, chapters: [ChapterRef], done: Bool) -> some View {
        let title = VStack(alignment: .leading, spacing: 4) {
            Text("오늘 · \(day + 1)일째").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(ReadingPlan.label(chapters)).font(.title3.weight(.semibold))
            if let cheer = Extras.daily(Extras.phrases.plan) {
                Text(cheer).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        let buttons = HStack {
            if let first = chapters.first {
                Button("읽으러 가기") { model.open(first) }.buttonStyle(.bordered)
            }
            Button(done ? "다 읽음 ✓" : "다 읽음") { toggle(day) }
                .buttonStyle(.borderedProminent)
                .tint(done ? .green : .accentColor)
        }
        .fixedSize()
        // 창이 좁으면 단추를 아래 줄로
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                title.fixedSize()
                Spacer()
                buttons
            }
            VStack(alignment: .leading, spacing: 10) {
                title
                buttons
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
    }

    private func dayRow(_ index: Int, _ chapters: [ChapterRef], progress: PlanProgress, isToday: Bool) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: index, to: progress.start) ?? progress.start
        let done = progress.done.contains(index)
        return HStack(spacing: 12) {
            Button { toggle(index) } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            Text("\(index + 1)일").monospacedDigit().frame(width: 48, alignment: .leading).foregroundStyle(.secondary)
            Text(date, format: .dateTime.month().day()).frame(width: 60, alignment: .leading).foregroundStyle(.secondary)
            Text(ReadingPlan.label(chapters)).fontWeight(isToday ? .bold : .regular)
            Spacer()
            if isToday { Text("오늘").font(.caption.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Color.accentColor.opacity(0.2))) }
            if let first = chapters.first {
                Button { model.open(first) } label: { Image(systemName: "book") }.buttonStyle(.borderless).help("읽으러 가기")
            }
        }
    }

    private func toggle(_ day: Int) {
        guard model.user.data.plan != nil else { return }
        if model.user.data.plan!.done.contains(day) {
            model.user.data.plan!.done.remove(day)
        } else {
            model.user.data.plan!.done.insert(day)
        }
    }
}


/// 시작 날짜를 확인한 뒤에만 실제 계획을 만든다.
private struct PlanStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Local private var start = Date()
    let plan: ReadingPlan
    let onStart: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("통독 계획 시작").font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 7) {
                Text(plan.title).font(.headline).foregroundStyle(BibleStyle.accent)
                Text(plan.detail).font(.callout).foregroundStyle(.secondary)
            }
            DatePicker("시작일", selection: $start, displayedComponents: .date)
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("계획 시작하기") { onStart(start) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 430)
        .background(BibleStyle.paper).tint(BibleStyle.accent)
    }
}

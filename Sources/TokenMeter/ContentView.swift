import SwiftUI

struct ContentView: View {
    @Environment(UsageService.self) private var usage

    var body: some View {
        // Re-evaluate the expected pace every minute.
        TimelineView(.everyMinute) { timeline in
            let expected = PaceCalculator.expectedPercent(at: timeline.date)
            VStack(spacing: 6) {
                GaugeView(
                    actual: usage.modelPercent,
                    expected: expected,
                    session: usage.sessionPercent,
                    title: "\(UsageService.modelName) weekly",
                    subtitle: "pace \(Int(expected.rounded()))%" + resetText(usage.modelResetsAt, prefix: " · resets "),
                    sessionLabel: sessionLabel,
                    dimmed: usage.errorMessage != nil
                )
                .animation(.spring(duration: 0.8, bounce: 0.3), value: usage.modelPercent)
                .animation(.spring(duration: 0.8, bounce: 0.3), value: usage.sessionPercent)
                .animation(.easeInOut(duration: 0.8), value: expected)

                statusLine
            }
            .padding(12)
        }
        .frame(minWidth: 240, idealWidth: 300, minHeight: 270, idealHeight: 330)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { usage.refresh() }
        .help("Double-click or ⌘R to refresh")
        .onAppear { usage.start() }
    }

    private var sessionLabel: String {
        let percent = usage.sessionPercent.map { "\(Int($0.rounded()))%" } ?? "--"
        return "Session \(percent)" + resetText(usage.sessionResetsAt, prefix: " · ")
    }

    @ViewBuilder private var statusLine: some View {
        Group {
            if let error = usage.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                let all = usage.weeklyAllPercent.map { "Weekly (all) \(Int($0.rounded()))%" } ?? "Weekly (all) --"
                let updated = usage.lastUpdated.map { " · updated \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
                Text(usage.isLoading && usage.lastUpdated == nil ? "Loading…" : all + updated)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private func resetText(_ date: Date?, prefix: String) -> String {
        guard let date else { return "" }
        let sameDay = Calendar.current.isDateInToday(date)
        let style = sameDay
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return prefix + style
    }
}

import Foundation
import TrafficLightCore

let store = CodexSessionStore()
if CommandLine.arguments.contains("--debug-running") {
    for command in RunningProcessCommands.snapshot()
        where command.contains("status-dump") || command.contains("swift run") || command.contains("core-self-test") {
        print(command)
    }
    exit(0)
}

if let benchmarkIndex = CommandLine.arguments.firstIndex(of: "--benchmark-sessions"),
   CommandLine.arguments.indices.contains(benchmarkIndex + 1),
   let iterations = Int(CommandLine.arguments[benchmarkIndex + 1]),
   iterations > 0 {
    let start = Date()
    var sessionCount = 0
    for _ in 0..<iterations {
        sessionCount = store.loadSessions().count
    }
    let elapsed = Date().timeIntervalSince(start)
    let averageMilliseconds = elapsed / Double(iterations) * 1_000
    print("sessions=\(sessionCount) iterations=\(iterations) avg_ms=\(String(format: "%.1f", averageMilliseconds))")
    exit(0)
}

let sessions = store.loadSessions()
let tokenUsage = CommandLine.arguments.contains("--sessions-only") ? .empty : store.loadTokenUsage()
let summary = SessionAggregator.aggregate(sessions, tokenUsage: tokenUsage)
let weekPercent = summary.tokenUsage.totalRemainingPercent.map { "\(Int($0.rounded()))%" } ?? "--"
let todayPercent = summary.tokenUsage.todayUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--"
print("status=\(summary.status.rawValue) label=\(summary.status.label) sessions=\(summary.sessions.count) week_left=\(weekPercent) week_tokens=\(summary.tokenUsage.totalTokens) today=\(todayPercent) today_tokens=\(summary.tokenUsage.todayTokens)")
for session in summary.sessions {
    print("\(session.status.rawValue)\t\(session.displayName)\t\(session.summary)")
}

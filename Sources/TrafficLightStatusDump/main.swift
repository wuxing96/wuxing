import Foundation
import TrafficLightCore

let store = AISessionStore()
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
let tokenUsage = CommandLine.arguments.contains("--sessions-only") ? AgentTokenUsageSummary() : store.loadAgentTokenUsage()
let summary = SessionAggregator.aggregate(
    sessions,
    tokenUsage: tokenUsage.codex,
    claudeTokenUsage: tokenUsage.claude
)
let weekPercent = summary.tokenUsage.totalRemainingPercent.map { "\(Int($0.rounded()))%" } ?? "--"
let todayPercent = summary.tokenUsage.todayUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--"
print("status=\(summary.status.rawValue) label=\(summary.status.label) sessions=\(summary.sessions.count) codex_week_left=\(weekPercent) codex_week_tokens=\(summary.tokenUsage.totalTokens) codex_today=\(todayPercent) codex_today_tokens=\(summary.tokenUsage.todayTokens) claude_week_tokens=\(summary.claudeTokenUsage.totalTokens) claude_today_tokens=\(summary.claudeTokenUsage.todayTokens)")
for session in summary.sessions {
    print("\(session.status.rawValue)\t\(session.source.rawValue)\t\(session.displayName)\t\(session.summary)")
}

import Foundation
import TrafficLightCore

let store = CodexSessionStore()
let summary = SessionAggregator.aggregate(store.loadSessions(), tokenUsage: store.loadTokenUsage())
let weekPercent = summary.tokenUsage.totalUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--"
let todayPercent = summary.tokenUsage.todayUsedPercent.map { "\(Int($0.rounded()))%" } ?? "--"
print("status=\(summary.status.rawValue) label=\(summary.status.label) sessions=\(summary.sessions.count) week=\(weekPercent) week_tokens=\(summary.tokenUsage.totalTokens) today=\(todayPercent) today_tokens=\(summary.tokenUsage.todayTokens)")
for session in summary.sessions {
    print("\(session.status.rawValue)\t\(session.displayName)\t\(session.summary)")
}

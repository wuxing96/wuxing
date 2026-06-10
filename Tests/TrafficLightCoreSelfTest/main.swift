import Foundation
import TrafficLightCore

try pendingToolCallIsWorking()
try pendingExecCommandShowsCommandSummary()
try escalatedToolCallStartsAsWaitingForApproval()
try parallelEscalatedToolCallsWaitForApproval()
try waitingApprovalOutranksRunningApproval()
try escalatedToolCallWithRunningProcessIsWorking()
try installLoginAgentRunningTextIsWorking()
try escalatedToolCallStillWaitsForApprovalAfterLongDelay()
try requestUserInputIsWaitingForUser()
try functionCallOutputWithoutAssistantReplyIsWorking()
try pendingCommandSummarySurvivesOtherToolOutput()
try functionCallOutputThenAssistantReplyIsCompleted()
try webSearchCallIsWorking()
try webSearchThenAssistantReplyIsCompleted()
try reasoningItemIsWorking()
try assistantCommentaryIsWorking()
try customToolCallIsWorking()
try pendingApplyPatchWaitsForEditApproval()
try approvedApplyPatchIsWorkingUntilFinalReply()
try customToolCallOutputWithoutFinalReplyIsWorking()
try turnAbortedIsCompleted()
try assistantMessageIsCompleted()
try oldSessionIsInactive()
try userMessageStartsWorkingTurn()
try aggregatorUsesHighestPriorityStatus()
try duplicateProjectNamesGetDisplayNumbers()
try codexProcessSnapshotCountsNativeCodexCWDs()
try sessionStoreDropsSessionsWithoutLiveCodexProcess()
try sessionStoreKeepsOnlyLatestSessionsForLiveProcessCount()
try tokenUsageSumsLocalTodayAndLatestRateLimit()
try tokenUsageReportsWeekAndTodayPercentWithTokens()

print("core-self-test: passed")

func pendingToolCallIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(name: "exec_command", callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .working, "pending tool call should be working")
    try expect(session.projectName == "tsailun", "project name should use cwd basename")
    try expect(session.pendingToolCalls == 1, "pending call count should be 1")
}

func pendingExecCommandShowsCommandSummary() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"npm run dev"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .working, "pending exec command should be working")
    try expect(session.summary == "npm run dev", "pending exec command should show command summary")
}

func escalatedToolCallStartsAsWaitingForApproval() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"npm install","sandbox_permissions":"require_escalated"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:12Z")
    )

    try expect(session.status == .waiting, "fresh escalated call should wait for approval")
    try expect(session.summary == "Waiting for approval", "fresh escalated call should explain approval wait")
}

func parallelEscalatedToolCallsWaitForApproval() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/ai-traffic-light"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"swift run core-self-test","sandbox_permissions":"require_escalated"}"#
            ),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-2",
                arguments: #"{"cmd":"swift build","sandbox_permissions":"require_escalated"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:12Z")
    )

    try expect(session.status == .waiting, "parallel escalated calls should show waiting before approval")
    try expect(session.summary == "Waiting for approval", "parallel escalated calls should explain approval wait")
}

func waitingApprovalOutranksRunningApproval() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/ai-traffic-light"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"swift build","sandbox_permissions":"require_escalated"}"#
            ),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-2",
                arguments: #"{"cmd":"swift run core-self-test","sandbox_permissions":"require_escalated"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:12Z"),
        runningProcessCommands: ["swift build"]
    )

    try expect(session.status == .waiting, "unapproved command should stay yellow even if another command is running")
    try expect(session.summary == "Waiting for approval", "mixed running/waiting approvals should explain approval wait")
}

func escalatedToolCallWithRunningProcessIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"scripts/install-login-agent.sh","sandbox_permissions":"require_escalated"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:12Z"),
        runningProcessCommands: ["/bin/sh scripts/install-login-agent.sh"]
    )

    try expect(session.status == .working, "escalated call should be working once command process is running")
}

func installLoginAgentRunningTextIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/ai-traffic-light"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"scripts/install-login-agent.sh","workdir":"/Users/wuxing/ai-traffic-light","yield_time_ms":30000,"sandbox_permissions":"require_escalated","login":false}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:12Z"),
        runningProcessCommands: ["Running scripts/install-login-agent.sh"]
    )

    try expect(session.status == .working, "visible Running install-login-agent text should be working")
    try expect(session.summary == "scripts/install-login-agent.sh", "running install-login-agent should show the command")
}

func escalatedToolCallStillWaitsForApprovalAfterLongDelay() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"npm install","sandbox_permissions":"require_escalated"}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:35:00Z")
    )

    try expect(session.status == .waiting, "approval prompt should stay yellow until the command process is running")
}

func requestUserInputIsWaitingForUser() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "request_user_input",
                callID: "call-1",
                arguments: #"{"questions":[{"question":"Pick one"}]}"#
            )
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .waiting, "request_user_input should wait for user")
}

func functionCallOutputWithoutAssistantReplyIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(name: "exec_command", callID: "call-1"),
            responseFunctionCallOutput(callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "tool output should remain working until assistant reply")
}

func pendingCommandSummarySurvivesOtherToolOutput() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"sleep 20"}"#
            ),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-2",
                arguments: #"{"cmd":"swift run status-dump"}"#
            ),
            responseFunctionCallOutput(callID: "call-2")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "remaining pending command should keep the session working")
    try expect(session.summary == "sleep 20", "remaining pending command should be the visible summary")
}

func functionCallOutputThenAssistantReplyIsCompleted() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseFunctionCall(name: "exec_command", callID: "call-1"),
            responseFunctionCallOutput(callID: "call-1"),
            responseAssistantMessage("done")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:25Z")
    )

    try expect(session.status == .completed, "assistant reply after tool output should be completed")
}

func webSearchCallIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseWebSearchCall()
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "web search should show working")
}

func webSearchThenAssistantReplyIsCompleted() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseWebSearchCall(),
            responseAssistantMessage("done")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:25Z")
    )

    try expect(session.status == .completed, "assistant reply after web search should be completed")
}

func reasoningItemIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseReasoning()
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "reasoning should show working")
}

func assistantCommentaryIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseAssistantCommentary("I am editing files")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "assistant commentary should show working")
}

func customToolCallIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseCustomToolCall(name: "browser_click", callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "custom tool call should show working")
    try expect(session.summary == "browser_click", "custom tool call should show tool summary")
}

func pendingApplyPatchWaitsForEditApproval() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseCustomToolCall(name: "apply_patch", callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .waiting, "pending apply_patch should wait for edit approval")
    try expect(session.summary == "Waiting for edit approval", "pending apply_patch should explain edit approval wait")
}

func approvedApplyPatchIsWorkingUntilFinalReply() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseCustomToolCall(name: "apply_patch", callID: "call-1"),
            patchApplyEnd(callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "approved apply_patch should become working after patch_apply_end")
    try expect(session.summary == "Editing files", "approved apply_patch should show editing summary")
}

func customToolCallOutputWithoutFinalReplyIsWorking() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            responseAssistantCommentary("I am editing files"),
            responseCustomToolCall(name: "apply_patch", callID: "call-1"),
            patchApplyEnd(callID: "call-1"),
            responseCustomToolCallOutput(callID: "call-1")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .working, "custom tool output should remain working until final reply")
}

func turnAbortedIsCompleted() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
            userMessage("start"),
            responseReasoning(),
            turnAborted()
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:20:20Z")
    )

    try expect(session.status == .completed, "aborted turn should return to completed")
    try expect(session.pendingToolCalls == 0, "aborted turn should clear pending calls")
}

func assistantMessageIsCompleted() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing"),
            responseAssistantMessage("done")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .completed, "assistant message should be completed")
}

func oldSessionIsInactive() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing"),
            responseAssistantMessage("done")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T17:00:00Z")
    )

    try expect(session.status == .inactive, "old session should be inactive")
}

func userMessageStartsWorkingTurn() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing"),
            userMessage("start")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .working, "user message should start a working turn")
}

func aggregatorUsesHighestPriorityStatus() throws {
    let sessions = [
        AIAgentSession.stub(id: "s1", projectName: "api", status: .completed),
        AIAgentSession.stub(id: "s2", projectName: "web", status: .working),
        AIAgentSession.stub(id: "s3", projectName: "ops", status: .waiting)
    ]

    let summary = SessionAggregator.aggregate(sessions)

    try expect(summary.status == .waiting, "summary should show user action as the highest priority")
    try expect(summary.sessions.map(\.status) == [.waiting, .working, .completed], "sessions should sort waiting before running work and completed")
}

func duplicateProjectNamesGetDisplayNumbers() throws {
    let sessions = [
        AIAgentSession.stub(id: "s1", projectName: "tsailun", status: .working, lastActivity: date("2026-06-09T08:29:00Z")),
        AIAgentSession.stub(id: "s2", projectName: "tsailun", status: .completed, lastActivity: date("2026-06-09T08:28:00Z")),
        AIAgentSession.stub(id: "s3", projectName: "design-anything", status: .completed, lastActivity: date("2026-06-09T08:27:00Z"))
    ]

    let summary = SessionAggregator.aggregate(sessions)

    try expect(summary.sessions.map(\.displayName) == ["tsailun #1", "tsailun #2", "design-anything"], "duplicate projects should get display numbers")
}

func codexProcessSnapshotCountsNativeCodexCWDs() throws {
    let counts = RunningCodexProcesses.activeSessionCounts(
        psOutput: """
          PID COMMAND
          101 node /Users/wuxing/.local/state/fnm_multishells/101/bin/codex
          102 /Users/wuxing/.local/share/fnm/node-versions/v24.15.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex
          201 node /Users/wuxing/.local/state/fnm_multishells/201/bin/codex
          202 /Users/wuxing/.local/share/fnm/node-versions/v24.15.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex
        """,
        lsofOutput: """
        COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
        node    101 wuxing cwd DIR 1,17 2400 31796 /Users/wuxing
        codex   102 wuxing cwd DIR 1,17 608 15187469 /Users/wuxing/IdeaProjects/tsailun
        node    201 wuxing cwd DIR 1,17 2400 31796 /Users/wuxing
        codex   202 wuxing cwd DIR 1,17 608 15187470 /Users/wuxing/IdeaProjects/tsailun
        """
    )

    try expect(counts == ["/Users/wuxing/IdeaProjects/tsailun": 2], "native codex child processes should be counted by cwd without node parent duplicates")
}

func sessionStoreDropsSessionsWithoutLiveCodexProcess() throws {
    let sessions = [
        AIAgentSession.stub(id: "s1", projectName: "lich-dms", status: .completed, lastActivity: date("2026-06-09T08:29:00Z"), cwd: "/Users/wuxing/IdeaProjects/lich-dms"),
        AIAgentSession.stub(id: "s2", projectName: "tsailun", status: .working, lastActivity: date("2026-06-09T08:28:00Z"), cwd: "/Users/wuxing/IdeaProjects/tsailun")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessionCountsByCWD: ["/Users/wuxing/IdeaProjects/tsailun": 1]
    )

    try expect(filtered.map(\.id) == ["s2"], "sessions without a live codex process cwd should be dropped")
}

func sessionStoreKeepsOnlyLatestSessionsForLiveProcessCount() throws {
    let sessions = [
        AIAgentSession.stub(id: "old", projectName: "~", status: .completed, lastActivity: date("2026-06-09T08:20:00Z"), cwd: "/Users/wuxing"),
        AIAgentSession.stub(id: "new", projectName: "~", status: .working, lastActivity: date("2026-06-09T08:29:00Z"), cwd: "/Users/wuxing")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessionCountsByCWD: ["/Users/wuxing": 1]
    )

    try expect(filtered.map(\.id) == ["new"], "one live codex process should keep only the newest session for that cwd")
}

func tokenUsageSumsLocalTodayAndLatestRateLimit() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!

    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(timestamp: "2026-06-09T15:30:00.000Z", totalTokens: 100, primaryUsedPercent: 9, secondaryUsedPercent: 20),
            tokenCountLine(timestamp: "2026-06-09T16:10:00.000Z", totalTokens: 125, primaryUsedPercent: 10, secondaryUsedPercent: 30),
            tokenCountLine(timestamp: "2026-06-10T03:20:00.000Z", totalTokens: 275, primaryUsedPercent: 22, secondaryUsedPercent: 44)
        ],
        now: date("2026-06-10T04:00:00Z"),
        calendar: calendar
    )

    try expect(summary.todayTokens == 400, "token usage should sum events in the local day")
    try expect(summary.primaryUsedPercent == 22, "token usage should keep the newest primary limit")
    try expect(summary.primaryRemainingPercent == 78, "token usage should expose remaining primary quota")
    try expect(summary.secondaryUsedPercent == 44, "token usage should keep the newest secondary limit")
}

func tokenUsageReportsWeekAndTodayPercentWithTokens() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!

    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-06-05T10:00:00.000Z",
                totalTokens: 900,
                primaryUsedPercent: 18,
                secondaryUsedPercent: 35,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-10T05:00:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-11T00:00:00Z"
            ),
            tokenCountLine(
                timestamp: "2026-06-09T15:30:00.000Z",
                totalTokens: 1_000,
                primaryUsedPercent: 18,
                secondaryUsedPercent: 40,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-10T05:00:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-11T00:00:00Z"
            ),
            tokenCountLine(
                timestamp: "2026-06-09T16:10:00.000Z",
                totalTokens: 125,
                primaryUsedPercent: 19,
                secondaryUsedPercent: 40,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-10T05:00:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-11T00:00:00Z"
            ),
            tokenCountLine(
                timestamp: "2026-06-10T03:20:00.000Z",
                totalTokens: 275,
                primaryUsedPercent: 20,
                secondaryUsedPercent: 40,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-10T05:00:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-11T00:00:00Z"
            )
        ],
        now: date("2026-06-10T04:00:00Z"),
        calendar: calendar
    )

    try expect(summary.totalTokens == 1_400, "week tokens should sum only the current local week")
    try expect(abs((summary.totalUsedPercent ?? 0) - 24.35) < 0.01, "week percent should estimate current-week usage from the latest secondary capacity")
    try expect(summary.todayTokens == 400, "today tokens should include only local-day token_count events")
    try expect(abs((summary.todayUsedPercent ?? 0) - 6.96) < 0.01, "today percent should be estimated from the secondary token capacity")
}

func expect(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw TestFailure(message)
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

func sessionMeta(id: String, cwd: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:00.000Z","type":"session_meta","payload":{"id":"\(id)","cwd":"\(cwd)","originator":"codex-tui"}}
    """
}

func responseFunctionCall(
    name: String,
    callID: String,
    arguments: String = #"{"cmd":"pwd"}"#
) -> String {
    """
    {"timestamp":"2026-06-09T08:20:10.000Z","type":"response_item","payload":{"type":"function_call","name":"\(name)","arguments":\(jsonString(arguments)),"call_id":"\(callID)"}}
    """
}

func responseFunctionCallOutput(callID: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:15.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"\(callID)","output":"ok"}}
    """
}

func responseWebSearchCall() -> String {
    """
    {"timestamp":"2026-06-09T08:20:15.000Z","type":"response_item","payload":{"type":"web_search_call","id":"ws-1","status":"completed","query":"test"}}
    """
}

func responseReasoning() -> String {
    """
    {"timestamp":"2026-06-09T08:20:15.000Z","type":"response_item","payload":{"type":"reasoning","id":"rs-1","summary":[]}}
    """
}

func responseAssistantMessage(_ text: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:20.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":\(jsonString(text))}],"phase":"final_answer"}}
    """
}

func responseAssistantCommentary(_ text: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:20.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":\(jsonString(text))}],"phase":"commentary"}}
    """
}

func responseCustomToolCall(name: String, callID: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:15.000Z","type":"response_item","payload":{"type":"custom_tool_call","status":"completed","call_id":"\(callID)","name":"\(name)","input":"*** Begin Patch\\n*** End Patch\\n"}}
    """
}

func responseCustomToolCallOutput(callID: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:17.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"\(callID)","output":"Exit code: 0\\nOutput:\\nSuccess"}}
    """
}

func userMessage(_ text: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:30.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":\(jsonString(text))}]}}
    """
}

func turnAborted() -> String {
    """
    {"timestamp":"2026-06-09T08:20:18.000Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","reason":"interrupted","completed_at":1780993218,"duration_ms":2000}}
    """
}

func patchApplyEnd(callID: String) -> String {
    """
    {"timestamp":"2026-06-09T08:20:16.000Z","type":"event_msg","payload":{"type":"patch_apply_end","call_id":"\(callID)","stdout":"Success","stderr":"","success":true,"status":"completed"}}
    """
}

func tokenCountLine(
    timestamp: String,
    totalTokens: Int,
    primaryUsedPercent: Double,
    secondaryUsedPercent: Double,
    primaryWindowMinutes: Int = 300,
    primaryResetAt: String = "2026-06-10T05:00:00Z",
    secondaryWindowMinutes: Int = 10080,
    secondaryResetAt: String = "2026-06-11T00:00:00Z"
) -> String {
    let primaryResetEpoch = Int(date(primaryResetAt).timeIntervalSince1970)
    let secondaryResetEpoch = Int(date(secondaryResetAt).timeIntervalSince1970)
    return """
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":\(totalTokens)}},"rate_limits":{"primary":{"used_percent":\(primaryUsedPercent),"window_minutes":\(primaryWindowMinutes),"resets_at":\(primaryResetEpoch)},"secondary":{"used_percent":\(secondaryUsedPercent),"window_minutes":\(secondaryWindowMinutes),"resets_at":\(secondaryResetEpoch)}}}}
    """
}

func jsonString(_ value: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    return String(data: data, encoding: .utf8)!
}

func date(_ value: String) -> Date {
    ISO8601DateFormatter.withFractionalSeconds.date(from: value)
        ?? ISO8601DateFormatter.basic.date(from: value)!
}

extension AIAgentSession {
    static func stub(
        id: String,
        projectName: String,
        status: SessionStatus,
        lastActivity: Date = date("2026-06-09T08:20:00Z"),
        cwd: String? = nil
    ) -> AIAgentSession {
        AIAgentSession(
            id: id,
            source: .codex,
            projectName: projectName,
            displayName: projectName,
            cwd: cwd ?? "/Users/wuxing/\(projectName)",
            status: status,
            lastActivity: lastActivity,
            pendingToolCalls: status == .working ? 1 : 0,
            summary: status.label
        )
    }
}

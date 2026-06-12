import Foundation
import CoreGraphics
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
try userMessageClearsStaleApprovalWait()
try sessionFileStatusReaderUsesHeadAndTail()
try sessionFileReaderPreservesOversizedSessionMetaCWD()
try aggregatorUsesHighestPriorityStatus()
try aggregatorSortsByAttentionThenRecentActivity()
try duplicateProjectNamesGetDisplayNumbers()
try codexProcessSnapshotCountsNativeCodexCWDs()
try codexProcessSnapshotExtractsTerminalTitleHints()
try sessionStoreDropsSessionsWithoutLiveCodexProcess()
try sessionStoreKeepsRecentlyEndedSessionsBriefly()
try sessionStoreDropsExpiredEndedSessions()
try sessionStoreShowsInactiveLiveSessionsAsIdle()
try sessionStoreRecentWindowCoversIdleWorkweek()
try sessionStoreKeepsOnlyLatestSessionsForLiveProcessCount()
try sessionStoreAssignsTerminalHintsByCWDRecency()
try sessionStoreAssignsCodexProcessIDsByCWDRecency()
try codexProcessOwnerPIDResolvesTerminalAncestor()
try tokenUsageSumsLocalTodayAndLatestRateLimit()
try tokenUsageReportsWeekAndTodayPercentWithTokens()
try tokenUsageReportsWeeklyQuotaLeftFromCodexLimits()
try tokenUsageIgnoresModelSpecificZeroLimitForWeeklyQuota()
try tokenUsageIgnoresModelSpecificNonzeroLimitForWeeklyQuota()
try tokenUsageIgnoresExpiredWeeklyQuota()
try tokenUsageUsesNewestBillingModeWhenAPIRecordFollowsWeeklyQuota()
try tokenUsageReportsTotalRemainingCreditsForAPIUsage()
try productIdentityUsesMushiSignal()
try statusRefreshPolicyIsSubsecond()
try sessionFileReaderUsesSmallTailWindow()
try expandedHeaderShowsProcessCount()
try expandedHeaderUsesMushiStatusAsset()
try collapsedStatusUsesThreeMushiSlots()
try panelClickRulesAvoidAccidentalCollapse()
try windowControlsUseCompactVisualsWithLargeHitTargets()
try expandedListLayoutCapsRowsAndClampsScroll()
try expandedListPreservesScrollAnchorAcrossRefresh()
try sessionRowLayoutSeparatesStatusAndTime()
try sessionRowLayoutExposesSeparateOpenAndStopActions()
try panelResizeRulesUseBottomRightGrip()
try workspaceWindowMatcherPrefersCodexTerminalThenIDE()
try workspaceWindowMatcherUsesTerminalHintBeforeHomeDirectory()
try workspaceWindowMatcherSupportsLocalizedTerminalAppName()
try workspaceWindowMatcherSupportsJetBrainsAndTrae()

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

func userMessageClearsStaleApprovalWait() throws {
    let session = try CodexSessionParser.parse(
        lines: [
            sessionMeta(id: "s1", cwd: "/Users/wuxing/ai-traffic-light"),
            responseFunctionCall(
                name: "exec_command",
                callID: "call-1",
                arguments: #"{"cmd":"swift run core-self-test","sandbox_permissions":"require_escalated"}"#
            ),
            userMessage("continue with a different task")
        ],
        filePath: "/tmp/rollout-s1.jsonl",
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(session.status == .working, "new user input should start working instead of inheriting the previous approval wait")
    try expect(session.pendingToolCalls == 0, "new user input should clear stale pending approval calls")
    try expect(session.summary == "New request", "new user input should show the current request summary")
}

func sessionFileStatusReaderUsesHeadAndTail() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("mushi-session-reader-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("rollout-large.jsonl")
    let oldBody = String(repeating: responseReasoning() + "\n", count: 256)
    let contents = [
        sessionMeta(id: "large", cwd: "/Users/wuxing/IdeaProjects/tsailun"),
        oldBody,
        userMessage("new work"),
        responseFunctionCall(
            name: "exec_command",
            callID: "call-tail",
            arguments: #"{"cmd":"npm run dev"}"#
        )
    ].joined(separator: "\n")
    try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let lines = CodexSessionFileReader.statusLines(
        fileURL: fileURL,
        headByteLimit: 512,
        tailByteLimit: 2_048
    )
    let session = try CodexSessionParser.parse(
        lines: lines,
        filePath: fileURL.path,
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(lines.count < 40, "live status reader should not return the entire session body")
    try expect(session.cwd == "/Users/wuxing/IdeaProjects/tsailun", "status reader should preserve cwd from the file head")
    try expect(session.status == .working, "status reader should use the latest tail event")
    try expect(session.summary == "npm run dev", "status reader should preserve the latest command summary")
}

func sessionFileReaderPreservesOversizedSessionMetaCWD() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("traffic-light-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("rollout-large-meta.jsonl")
    let largeInstructions = String(repeating: "x", count: 8_192)
    let oversizedSessionMeta = """
    {"timestamp":"2026-06-09T08:20:00.000Z","type":"session_meta","payload":{"id":"large-meta","cwd":"/Users/wuxing/IdeaProjects/tsailun","originator":"codex-tui","base_instructions":{"text":\(jsonString(largeInstructions))}}}
    """
    let oldBody = String(repeating: responseReasoning() + "\n", count: 128)
    let contents = [
        oversizedSessionMeta,
        oldBody,
        userMessage("new work"),
        responseFunctionCall(
            name: "exec_command",
            callID: "call-tail",
            arguments: #"{"cmd":"mvn test"}"#
        )
    ].joined(separator: "\n")
    try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let lines = CodexSessionFileReader.statusLines(
        fileURL: fileURL,
        headByteLimit: 512,
        tailByteLimit: 2_048
    )
    let session = try CodexSessionParser.parse(
        lines: lines,
        filePath: fileURL.path,
        now: date("2026-06-09T08:30:00Z")
    )

    try expect(lines.count < 40, "oversized metadata reader should still avoid returning the full session body")
    try expect(session.cwd == "/Users/wuxing/IdeaProjects/tsailun", "status reader should preserve cwd from oversized session metadata")
    try expect(session.displayName == "tsailun", "display name should use the oversized metadata cwd basename")
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
    try expect(SessionStatus.waiting.label == "Waiting", "yellow status label should fit in the row status pill")
}

func aggregatorSortsByAttentionThenRecentActivity() throws {
    let summary = SessionAggregator.aggregate([
        AIAgentSession.stub(id: "ready-new", projectName: "ready-new", status: .completed, lastActivity: date("2026-06-09T08:35:00Z")),
        AIAgentSession.stub(id: "working-old", projectName: "working-old", status: .working, lastActivity: date("2026-06-09T08:30:00Z")),
        AIAgentSession.stub(id: "waiting-old", projectName: "waiting-old", status: .waiting, lastActivity: date("2026-06-09T08:20:00Z")),
        AIAgentSession.stub(id: "waiting-new", projectName: "waiting-new", status: .waiting, lastActivity: date("2026-06-09T08:40:00Z")),
        AIAgentSession.stub(id: "working-new", projectName: "working-new", status: .working, lastActivity: date("2026-06-09T08:38:00Z"))
    ])

    try expect(
        summary.sessions.map(\.id) == ["waiting-new", "waiting-old", "working-new", "working-old", "ready-new"],
        "sessions should sort by attention first, then newest activity inside each status group"
    )
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

func codexProcessSnapshotExtractsTerminalTitleHints() throws {
    let sessions = RunningCodexProcesses.activeSessions(
        psOutput: """
          PID  PPID COMMAND
          101     1 node /Users/wuxing/.local/state/fnm_multishells/12534_1781085967351/bin/codex
          102   101 /Users/wuxing/.local/share/fnm/node-versions/v24.15.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex
          201     1 node /Users/wuxing/.local/state/fnm_multishells/12844_1781085992565/bin/codex
          202   201 /Users/wuxing/.local/share/fnm/node-versions/v24.15.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex
        """,
        lsofOutput: """
        COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
        codex   102 wuxing cwd DIR 1,17 2400 31796 /Users/wuxing
        codex   202 wuxing cwd DIR 1,17 2400 31796 /Users/wuxing
        """
    )

    try expect(sessions.map(\.pid) == [102, 202], "active sessions should include native codex child pids")
    try expect(sessions.map(\.cwd) == ["/Users/wuxing", "/Users/wuxing"], "active sessions should include the native codex cwd")
    try expect(sessions.map(\.windowTitleHints) == [["12534_1781085967351"], ["12844_1781085992565"]], "active sessions should expose fnm multishell ids as terminal title hints")
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

func sessionStoreKeepsRecentlyEndedSessionsBriefly() throws {
    let sessions = [
        AIAgentSession.stub(id: "ended", projectName: "lich-dms", status: .completed, lastActivity: date("2026-06-09T08:29:20Z"), cwd: "/Users/wuxing/IdeaProjects/lich-dms"),
        AIAgentSession.stub(id: "live", projectName: "tsailun", status: .working, lastActivity: date("2026-06-09T08:29:10Z"), cwd: "/Users/wuxing/IdeaProjects/tsailun")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessions: [
            RunningCodexProcess(pid: 102, cwd: "/Users/wuxing/IdeaProjects/tsailun")
        ],
        now: date("2026-06-09T08:39:20Z")
    )

    try expect(CodexSessionStore.defaultEndedRetention == 30 * 60, "ended sessions should remain visible long enough to notice after task completion")
    try expect(filtered.map(\.id) == ["live", "ended"], "recently ended sessions should remain briefly after the codex process exits")
    try expect(filtered[1].status == .ended, "recently ended sessions should be marked as ended")
    try expect(filtered[1].codexProcessID == nil, "ended sessions should not expose a stale process id")
}

func sessionStoreDropsExpiredEndedSessions() throws {
    let sessions = [
        AIAgentSession.stub(id: "expired", projectName: "lich-dms", status: .completed, lastActivity: date("2026-06-09T08:27:00Z"), cwd: "/Users/wuxing/IdeaProjects/lich-dms"),
        AIAgentSession.stub(id: "live", projectName: "tsailun", status: .working, lastActivity: date("2026-06-09T08:29:10Z"), cwd: "/Users/wuxing/IdeaProjects/tsailun")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessions: [
            RunningCodexProcess(pid: 102, cwd: "/Users/wuxing/IdeaProjects/tsailun")
        ],
        now: date("2026-06-09T09:00:00Z")
    )

    try expect(filtered.map(\.id) == ["live"], "ended sessions should be removed after the short retention window")
}

func sessionStoreShowsInactiveLiveSessionsAsIdle() throws {
    let sessions = [
        AIAgentSession.stub(
            id: "idle-live",
            projectName: "tsailun",
            status: .inactive,
            lastActivity: date("2026-06-09T00:20:00Z"),
            cwd: "/Users/wuxing/IdeaProjects/tsailun"
        )
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessions: [
            RunningCodexProcess(pid: 102, cwd: "/Users/wuxing/IdeaProjects/tsailun")
        ],
        now: date("2026-06-09T09:00:00Z")
    )

    try expect(filtered.map(\.id) == ["idle-live"], "live Codex processes should stay visible even when their transcript is idle")
    try expect(filtered[0].status == .completed, "idle live sessions should display as green instead of disappearing")
    try expect(filtered[0].summary == "Idle", "idle live sessions should explain that the process is idle")
    try expect(filtered[0].codexProcessID == 102, "idle live sessions should keep their live process id")
}

func sessionStoreRecentWindowCoversIdleWorkweek() throws {
    try expect(CodexSessionStore.defaultRecentWindow == 7 * 24 * 60 * 60, "session scan window should keep idle live processes visible across multiple days")
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

func sessionStoreAssignsTerminalHintsByCWDRecency() throws {
    let sessions = [
        AIAgentSession.stub(id: "old", projectName: "~", status: .completed, lastActivity: date("2026-06-09T08:20:00Z"), cwd: "/Users/wuxing"),
        AIAgentSession.stub(id: "new", projectName: "~", status: .working, lastActivity: date("2026-06-09T08:29:00Z"), cwd: "/Users/wuxing")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessions: [
            RunningCodexProcess(pid: 202, cwd: "/Users/wuxing", windowTitleHints: ["12844_1781085992565"]),
            RunningCodexProcess(pid: 102, cwd: "/Users/wuxing", windowTitleHints: ["12534_1781085967351"])
        ]
    )

    try expect(filtered.map(\.id) == ["new", "old"], "active process hints should keep sessions in recency order")
    try expect(filtered.map(\.windowTitleHints) == [["12844_1781085992565"], ["12534_1781085967351"]], "active process hints should be assigned by cwd recency")
}

func sessionStoreAssignsCodexProcessIDsByCWDRecency() throws {
    let sessions = [
        AIAgentSession.stub(id: "old", projectName: "~", status: .completed, lastActivity: date("2026-06-09T08:20:00Z"), cwd: "/Users/wuxing"),
        AIAgentSession.stub(id: "new", projectName: "~", status: .working, lastActivity: date("2026-06-09T08:29:00Z"), cwd: "/Users/wuxing")
    ]

    let filtered = CodexSessionStore.filterLiveSessions(
        sessions,
        activeSessions: [
            RunningCodexProcess(pid: 202, cwd: "/Users/wuxing", windowTitleHints: ["12844_1781085992565"]),
            RunningCodexProcess(pid: 102, cwd: "/Users/wuxing", windowTitleHints: ["12534_1781085967351"])
        ]
    )

    try expect(filtered.map(\.codexProcessID) == [202, 102], "active process pid should be assigned to the matching session")
}

func codexProcessOwnerPIDResolvesTerminalAncestor() throws {
    let psOutput = """
      PID  PPID COMMAND
    61419     1 /System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
    61421 61419 -zsh
    99503 61421 node /Users/wuxing/.local/state/fnm_multishells/61429_1780995698425/bin/codex
    99506 99503 /Users/wuxing/.local/share/fnm/node-versions/v24.15.0/installation/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex
    """

    try expect(
        RunningCodexProcesses.nearestAncestorPID(
            from: 99506,
            candidatePIDs: [61419],
            psOutput: psOutput
        ) == 61419,
        "native Codex process should resolve its owning terminal app ancestor"
    )
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
    try expect(summary.secondaryRemainingPercent == 56, "token usage should expose remaining secondary quota")
    try expect(summary.totalRemainingPercent == 56, "weekly quota should prefer remaining secondary quota")
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
    try expect(summary.totalUsedPercent == 40, "week used percent should mirror the latest Codex weekly limit")
    try expect(summary.totalRemainingPercent == 60, "week remaining percent should mirror the latest Codex weekly limit left")
    try expect(summary.todayTokens == 400, "today tokens should include only local-day token_count events")
    try expect(abs((summary.todayUsedPercent ?? 0) - 6.96) < 0.01, "today percent should be estimated from the secondary token capacity")
}

func tokenUsageReportsWeeklyQuotaLeftFromCodexLimits() throws {
    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-06-11T01:00:00.000Z",
                totalTokens: 26_700,
                primaryUsedPercent: 25,
                secondaryUsedPercent: 1,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T01:46:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-18T00:40:00Z"
            )
        ],
        now: date("2026-06-11T01:20:00Z")
    )

    try expect(summary.primaryRemainingPercent == 75, "5h limit should expose 75 percent left")
    try expect(summary.secondaryRemainingPercent == 99, "weekly limit should expose 99 percent left")
    try expect(summary.totalRemainingPercent == 99, "week display should use weekly quota left")
}

func tokenUsageIgnoresModelSpecificZeroLimitForWeeklyQuota() throws {
    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-06-11T01:00:00.000Z",
                totalTokens: 26_700,
                primaryUsedPercent: 25,
                secondaryUsedPercent: 1,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T01:46:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-18T00:40:00Z",
                limitID: "codex"
            ),
            tokenCountLine(
                timestamp: "2026-06-11T07:20:00.000Z",
                totalTokens: 160_000,
                primaryUsedPercent: 0,
                secondaryUsedPercent: 0,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T08:20:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-16T20:40:00Z",
                limitID: "codex_bengalfox"
            )
        ],
        now: date("2026-06-11T07:30:00Z")
    )

    try expect(summary.primaryUsedPercent == 25, "model-specific zero primary limit should not replace global primary quota")
    try expect(summary.secondaryUsedPercent == 1, "model-specific zero weekly limit should not replace global weekly quota")
    try expect(summary.totalRemainingPercent == 99, "weekly display should keep global quota left instead of showing 100 percent")
}

func tokenUsageIgnoresModelSpecificNonzeroLimitForWeeklyQuota() throws {
    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-06-11T01:00:00.000Z",
                totalTokens: 26_700,
                primaryUsedPercent: 25,
                secondaryUsedPercent: 1,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T01:46:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-18T00:40:00Z",
                limitID: "codex"
            ),
            tokenCountLine(
                timestamp: "2026-06-11T07:20:00.000Z",
                totalTokens: 160_000,
                primaryUsedPercent: 60,
                secondaryUsedPercent: 22,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T08:20:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-16T20:40:00Z",
                limitID: "codex_bengalfox"
            )
        ],
        now: date("2026-06-11T07:30:00Z")
    )

    try expect(summary.primaryUsedPercent == 25, "model-specific primary limit should not replace the global account quota")
    try expect(summary.secondaryUsedPercent == 1, "model-specific weekly limit should not replace the global account quota")
    try expect(summary.totalRemainingPercent == 99, "weekly display should keep the global account quota instead of a model quota")
}

func tokenUsageIgnoresExpiredWeeklyQuota() throws {
    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-05-28T08:00:00.000Z",
                totalTokens: 100_000,
                primaryUsedPercent: 2,
                secondaryUsedPercent: 13,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-05-28T10:00:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-05-31T00:00:00Z",
                limitID: "codex"
            ),
            tokenCountLine(
                timestamp: "2026-06-11T07:20:00.000Z",
                totalTokens: 160_000,
                primaryUsedPercent: 0,
                secondaryUsedPercent: 0,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T08:20:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-16T20:40:00Z",
                limitID: "codex_bengalfox"
            )
        ],
        now: date("2026-06-11T07:30:00Z")
    )

    try expect(summary.totalRemainingPercent == nil, "expired weekly quota should not be displayed as current account balance")
}

func tokenUsageUsesNewestBillingModeWhenAPIRecordFollowsWeeklyQuota() throws {
    let summary = CodexTokenUsageParser.parse(
        lines: [
            tokenCountLine(
                timestamp: "2026-06-11T01:00:00.000Z",
                totalTokens: 26_700,
                primaryUsedPercent: 25,
                secondaryUsedPercent: 1,
                primaryWindowMinutes: 300,
                primaryResetAt: "2026-06-11T01:46:00Z",
                secondaryWindowMinutes: 10080,
                secondaryResetAt: "2026-06-18T00:40:00Z",
                limitID: "codex"
            ),
            apiCreditTokenCountLine(
                timestamp: "2026-06-11T07:20:00.000Z",
                totalTokens: 160_000,
                remainingCredits: 7.25,
                totalCredits: 20,
                currency: "USD"
            )
        ],
        now: date("2026-06-11T07:30:00Z")
    )

    let weekly = TrafficLightTokenDisplay.weekly(summary)

    try expect(summary.totalRemainingPercent == nil, "newer API billing record should suppress older weekly quota")
    try expect(summary.todayUsedPercent == nil, "API billing mode should not estimate today percent from an older weekly quota")
    try expect(weekly.label == "API balance", "newer API billing record should switch the weekly chip to API balance")
    try expect(weekly.primary == "$7.25 left", "API billing mode should show remaining API balance")
    try expect(TrafficLightTokenDisplay.compactWeekly(summary) == "API $7.25 left", "collapsed API billing mode should show API balance")
}

func tokenUsageReportsTotalRemainingCreditsForAPIUsage() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!

    let summary = CodexTokenUsageParser.parse(
        lines: [
            apiCreditTokenCountLine(
                timestamp: "2026-06-08T10:00:00.000Z",
                totalTokens: 1_000_000,
                remainingCredits: 18.20,
                totalCredits: 20,
                currency: "USD"
            ),
            apiCreditTokenCountLine(
                timestamp: "2026-06-11T02:00:00.000Z",
                totalTokens: 53_000_000,
                remainingCredits: 16.41,
                totalCredits: 20,
                currency: "USD"
            )
        ],
        now: date("2026-06-11T04:00:00Z"),
        calendar: calendar
    )

    let weekly = TrafficLightTokenDisplay.weekly(summary)
    let today = TrafficLightTokenDisplay.today(summary)

    try expect(summary.totalTokens == 54_000_000, "API-only logs should still sum weekly token usage")
    try expect(summary.totalRemainingPercent == nil, "API-only logs should not invent a quota percentage")
    try expect(summary.creditBalance?.remaining == 16.41, "API credit parser should keep the latest remaining balance")
    try expect(weekly.label == "API balance", "API credit chip should identify API billing mode")
    try expect(weekly.primary == "$16.41 left", "API credit chip should show total remaining balance")
    try expect(weekly.secondary == nil, "API credit chip should stay focused on remaining balance")
    try expect(today.primary == "53M tok", "API-only today chip should show today's token usage when no percent exists")
    try expect(today.secondary == nil, "API-only today chip should not show a missing percent beside token usage")
    try expect(TrafficLightTokenDisplay.compactWeekly(summary) == "API $16.41 left", "collapsed API display should show total remaining balance")
    try expect(TrafficLightTokenDisplay.compactToday(summary) == "Today 53M tok", "collapsed API display should show today's token usage")
}

func productIdentityUsesMushiSignal() throws {
    try expect(TrafficLightProduct.displayName == "Mushi Signal", "product display name should use the chosen app name")
}

func statusRefreshPolicyIsSubsecond() throws {
    try expect(TrafficLightRefreshPolicy.statusInterval <= 0.05, "status refresh should target 50ms-level status pickup")
    try expect(TrafficLightRefreshPolicy.tokenUsageInterval >= 20, "token usage refresh should stay lower frequency than live status")
}

func sessionFileReaderUsesSmallTailWindow() throws {
    try expect(CodexSessionFileReader.defaultHeadByteLimit <= 16 * 1_024, "live status reader should keep the default head window small")
    try expect(CodexSessionFileReader.defaultTailByteLimit <= 256 * 1_024, "live status reader should keep the default tail window small")
}

func expandedHeaderShowsProcessCount() throws {
    try expect(TrafficLightExpandedHeader.title == "AI SESSIONS", "expanded header should keep the AI sessions label")
    try expect(TrafficLightExpandedHeader.iconHeight == TrafficLightExpandedHeader.titleLineHeight, "mushi icon should match the title line height")
    try expect(TrafficLightExpandedHeader.countFontSize == TrafficLightExpandedHeader.titleFontSize, "process count should use the same size as the AI sessions label")
    try expect(TrafficLightExpandedHeader.countText(sessionCount: 0) == "0", "expanded header count should handle zero processes")
    try expect(TrafficLightExpandedHeader.countText(sessionCount: 4) == "4", "expanded header count should show current process count")
}

func expandedHeaderUsesMushiStatusAsset() throws {
    try expect(TrafficLightExpandedHeader.iconAssetName == "mushi-status-header", "header should use the neutral Mushi status asset")
}

func collapsedStatusUsesThreeMushiSlots() throws {
    let bounds = CGRect(x: 0, y: 0, width: 214, height: 44)
    let slots = TrafficLightCollapsedStatusLayout.statuses.enumerated().map { index, _ in
        TrafficLightCollapsedStatusLayout.iconRect(index: index, in: bounds)
    }

    try expect(TrafficLightCollapsedStatusLayout.statuses == [.working, .waiting, .completed], "collapsed status order should be red, yellow, green")
    try expect(TrafficLightCollapsedStatusLayout.assetName(for: .working, count: 1) == "mushi-status-working", "working slot should use the red Mushi asset when active")
    try expect(TrafficLightCollapsedStatusLayout.assetName(for: .waiting, count: 1) == "mushi-status-waiting", "waiting slot should use the yellow Mushi asset when active")
    try expect(TrafficLightCollapsedStatusLayout.assetName(for: .completed, count: 1) == "mushi-status-done", "done slot should use the green Mushi asset when active")
    try expect(TrafficLightCollapsedStatusLayout.assetName(for: .working, count: 0) == "mushi-status-idle", "inactive collapsed slots should use the gray hanging-up Mushi asset")
    try expect(slots.allSatisfy { $0.width == TrafficLightCollapsedStatusLayout.iconSize && $0.height == TrafficLightCollapsedStatusLayout.iconSize }, "collapsed Mushi slots should use stable icon dimensions")
    try expect(!slots[0].intersects(slots[1]) && !slots[1].intersects(slots[2]), "collapsed Mushi slots should not overlap")
    try expect(slots[2].maxX <= 96, "collapsed Mushi group should leave room for compact quota text")
}

func panelClickRulesAvoidAccidentalCollapse() throws {
    let bounds = CGRect(x: 0, y: 0, width: 370, height: 266)

    try expect(
        TrafficLightPanelInteraction.clickAction(
            mode: .collapsed,
            mouseDown: CGPoint(x: 80, y: 20),
            mouseUp: CGPoint(x: 80, y: 20),
            bounds: bounds,
            movedDuringDrag: false
        ) == .expand,
        "collapsed panel click should expand"
    )

    try expect(
        TrafficLightPanelInteraction.clickAction(
            mode: .expanded,
            mouseDown: CGPoint(x: 180, y: 120),
            mouseUp: CGPoint(x: 180, y: 120),
            bounds: bounds,
            movedDuringDrag: false
        ) == .none,
        "expanded content click should not collapse the panel"
    )

    try expect(
        TrafficLightPanelInteraction.clickAction(
            mode: .expanded,
            mouseDown: CGPoint(x: 281, y: 241),
            mouseUp: CGPoint(x: 281, y: 241),
            bounds: bounds,
            movedDuringDrag: false
        ) == .none,
        "expanded panel should not expose a zoom button"
    )

    try expect(
        TrafficLightPanelInteraction.clickAction(
            mode: .expanded,
            mouseDown: CGPoint(x: 313, y: 241),
            mouseUp: CGPoint(x: 313, y: 241),
            bounds: bounds,
            movedDuringDrag: false
        ) == .collapse,
        "expanded minus button click should collapse the panel"
    )

    try expect(
        TrafficLightPanelInteraction.clickAction(
            mode: .expanded,
            mouseDown: CGPoint(x: 345, y: 241),
            mouseUp: CGPoint(x: 345, y: 241),
            bounds: bounds,
            movedDuringDrag: false
        ) == .requestClose,
        "expanded x button click should request app close confirmation"
    )

    try expect(
        TrafficLightPanelInteraction.canStartDrag(
            mode: .expanded,
            point: CGPoint(x: 48, y: 241),
            bounds: bounds
        ),
        "expanded title area should remain draggable"
    )

    try expect(
        !TrafficLightPanelInteraction.canStartDrag(
            mode: .expanded,
            point: CGPoint(x: 180, y: 120),
            bounds: bounds
        ),
        "expanded content rows should not start a window drag"
    )
}

func windowControlsUseCompactVisualsWithLargeHitTargets() throws {
    try expect(TrafficLightPanelInteraction.expandedCloseButtonSize >= 22, "window controls should keep a forgiving hit target")
    try expect(TrafficLightPanelInteraction.expandedWindowButtonSpacing <= 5, "minus and close controls should use macOS-style compact spacing")
    try expect(TrafficLightPanelInteraction.collapseButtonRect(in: CGRect(x: 0, y: 0, width: 370, height: 266)).maxX < TrafficLightPanelInteraction.closeButtonRect(in: CGRect(x: 0, y: 0, width: 370, height: 266)).minX, "minus button should sit beside close control")
    try expect(TrafficLightWindowControlStyle.visualDiameter <= 13, "window control visual should stay compact")
    try expect(TrafficLightWindowControlStyle.visualDiameter < TrafficLightPanelInteraction.expandedCloseButtonSize, "visual control should be smaller than hit target")
}

func expandedListLayoutCapsRowsAndClampsScroll() throws {
    try expect(TrafficLightExpandedListLayout.defaultVisibleRows == 3, "expanded panel should default to three visible tasks")
    try expect(TrafficLightExpandedListLayout.visibleRowCount(sessionCount: 12, preferredVisibleRows: 3) == 3, "expanded list should use the default three rows")
    try expect(TrafficLightExpandedListLayout.visibleRowCount(sessionCount: 12, preferredVisibleRows: 7) == 7, "expanded list should grow when the user resizes the panel")
    try expect(TrafficLightExpandedListLayout.visibleRowCount(sessionCount: 2) == 2, "expanded list should shrink for small lists")
    try expect(TrafficLightExpandedListLayout.maxScrollOffset(sessionCount: 12, visibleRows: 5, rowHeight: 46) == 322, "pixel scroll offset should allow the list to reach the last row")
    try expect(TrafficLightExpandedListLayout.clampedScrollOffset(999, sessionCount: 12, visibleRows: 5, rowHeight: 46) == 322, "pixel scroll offset should clamp to the list end")
    try expect(TrafficLightExpandedListLayout.clampedScrollOffset(-3, sessionCount: 12, visibleRows: 5, rowHeight: 46) == 0, "pixel scroll offset should not go below zero")
    try expect(TrafficLightExpandedListLayout.visibleRange(sessionCount: 12, visibleRows: 5, scrollOffset: 23, rowHeight: 46) == 0..<6, "partial pixel scroll should render one extra row for smooth clipping")
    try expect(TrafficLightExpandedListLayout.visibleRange(sessionCount: 12, visibleRows: 5, scrollOffset: 138, rowHeight: 46) == 3..<9, "visible range should follow pixel scroll offset")
}

func expandedListPreservesScrollAnchorAcrossRefresh() throws {
    let offset = TrafficLightExpandedListLayout.scrollOffsetPreservingAnchor(
        oldIDs: ["a", "b", "c", "d", "e"],
        newIDs: ["x", "a", "b", "c", "d", "e"],
        currentOffset: 46,
        visibleRows: 3,
        rowHeight: 46
    )
    try expect(offset == 92, "refresh should keep the same top row visible when new rows are inserted above it")

    let clamped = TrafficLightExpandedListLayout.scrollOffsetPreservingAnchor(
        oldIDs: ["a", "b", "c", "d"],
        newIDs: ["a", "b"],
        currentOffset: 92,
        visibleRows: 1,
        rowHeight: 46
    )
    try expect(clamped == 46, "preserved scroll anchor should still clamp to the new list end")
}

func sessionRowLayoutSeparatesStatusAndTime() throws {
    let row = CGRect(x: 14, y: 12, width: 342, height: 39)
    try expect(
        TrafficLightSessionRowLayout.verticalGapBetweenTimeAndStatus(in: row) >= 3,
        "status pill and relative time should not touch or overlap"
    )
}

func sessionRowLayoutExposesSeparateOpenAndStopActions() throws {
    let row = CGRect(x: 14, y: 12, width: 342, height: 39)
    let openRect = TrafficLightSessionRowLayout.openButtonRect(in: row)
    let openVisualRect = TrafficLightSessionRowLayout.openButtonVisualRect(in: row)
    let stopRect = TrafficLightSessionRowLayout.stopButtonRect(in: row)
    let stopVisualRect = TrafficLightSessionRowLayout.stopButtonVisualRect(in: row)
    let statusRect = TrafficLightSessionRowLayout.statusPillRect(in: row)

    try expect(TrafficLightSessionRowLayout.actionFontSize == TrafficLightSessionRowLayout.statusFontSize, "open and kill labels should match the status pill font size")
    try expect(openRect.width >= 22 && openRect.height >= 22, "open button should keep a usable hit target")
    try expect(openVisualRect.width == statusRect.width, "open button should match the status pill width")
    try expect(openVisualRect.minY == statusRect.minY && openVisualRect.height == statusRect.height, "open button visual should align with status on the first row")
    try expect(openVisualRect.minY >= row.minY + 18, "open button visual should not cover the summary row")
    try expect(stopRect.width >= 22 && stopRect.height >= 22, "stop button should keep a usable hit target")
    try expect(stopVisualRect.width == statusRect.width, "kill button should match the status pill width")
    try expect(stopVisualRect.midY == statusRect.midY, "stop button visual should align vertically with status on the first row")
    try expect(stopVisualRect.minY >= row.minY + 18, "stop button visual should not cover the summary row")
    try expect(openRect.maxX < statusRect.minX, "open action should sit to the left of the status pill")
    try expect(stopRect.maxX < openRect.minX, "stop action should sit to the left of the open action")
    try expect(row.minX + 40 + TrafficLightSessionRowLayout.contentTextWidth(in: row) < stopRect.minX, "row text should end before stop and open actions")
    try expect(!openRect.intersects(stopRect), "open and stop buttons should not overlap")
    try expect(
        TrafficLightSessionRowLayout.action(at: CGPoint(x: openRect.midX, y: openRect.midY), in: row, canStop: true) == .open,
        "open button hit should resolve to open action"
    )
    try expect(
        TrafficLightSessionRowLayout.action(at: CGPoint(x: stopRect.midX, y: stopRect.midY), in: row, canStop: true) == .stop,
        "stop button hit should resolve to stop action"
    )
    try expect(
        TrafficLightSessionRowLayout.action(at: CGPoint(x: stopRect.midX, y: stopRect.midY), in: row, canStop: false) == nil,
        "stop action should be disabled when no live process id exists"
    )
}

func panelResizeRulesUseBottomRightGrip() throws {
    let bounds = CGRect(x: 0, y: 0, width: 370, height: 244)
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 4, y: 122),
            bounds: bounds
        ) == .resizeLeftEdge,
        "left edge should start resize"
    )
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 366, y: 122),
            bounds: bounds
        ) == .resizeRightEdge,
        "right edge should start resize"
    )
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 185, y: 240),
            bounds: bounds
        ) == .resizeTopEdge,
        "top edge should start resize"
    )
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 185, y: 4),
            bounds: bounds
        ) == .resizeBottomEdge,
        "bottom edge should start resize"
    )
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 4, y: 240),
            bounds: bounds
        ) == .resizeTopLeftCorner,
        "top-left corner should start resize"
    )
    try expect(
        TrafficLightPanelInteraction.hitRegion(
            mode: .expanded,
            point: CGPoint(x: 360, y: 8),
            bounds: bounds
        ) == .resizeBottomRightCorner,
        "bottom-right corner should start resize"
    )
    try expect(TrafficLightPanelHitRegion.resizeTopEdge.isResizeRegion, "top edge should be a resize region")
    try expect(TrafficLightPanelHitRegion.resizeBottomRightCorner.resizesRight, "bottom-right should resize the right edge")
    try expect(TrafficLightPanelHitRegion.resizeBottomRightCorner.resizesBottom, "bottom-right should resize the bottom edge")
    try expect(
        !TrafficLightPanelInteraction.canStartDrag(
            mode: .expanded,
            point: CGPoint(x: 360, y: 8),
            bounds: bounds
        ),
        "resize handle should not drag the panel"
    )
    try expect(
        TrafficLightPanelResize.clampedSize(
            CGSize(width: 200, height: 120),
            minSize: CGSize(width: 380, height: 244),
            maxSize: CGSize(width: 900, height: 700)
        ) == CGSize(width: 380, height: 244),
        "resize should not go below minimum size"
    )
    try expect(
        TrafficLightPanelResize.clampedSize(
            CGSize(width: 1200, height: 900),
            minSize: CGSize(width: 380, height: 244),
            maxSize: CGSize(width: 900, height: 700)
        ) == CGSize(width: 900, height: 700),
        "resize should not exceed screen bounds"
    )
}

func workspaceWindowMatcherPrefersCodexTerminalThenIDE() throws {
    let session = AIAgentSession.stub(
        id: "s1",
        projectName: "tsailun",
        status: .working,
        cwd: "/Users/wuxing/IdeaProjects/tsailun"
    )

    let terminalMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "Cursor", title: "tsailun - Cursor"),
            AgentWorkspaceWindowSnapshot(appName: "iTerm2", title: "codex tsailun")
        ]
    )
    try expect(terminalMatch?.kind == .codexTerminal, "codex terminal should be preferred over IDE window")
    try expect(terminalMatch?.window.appName == "iTerm2", "terminal match should return the terminal window")

    let ideMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "Cursor", title: "tsailun - Cursor"),
            AgentWorkspaceWindowSnapshot(appName: "Safari", title: "unrelated")
        ]
    )
    try expect(ideMatch?.kind == .ide, "IDE window should be used when no codex terminal window matches")
    try expect(ideMatch?.window.appName == "Cursor", "IDE match should return the matching editor window")

    let noMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "Safari", title: "unrelated")
        ]
    )
    try expect(noMatch == nil, "unrelated windows should not match a project")
}

func workspaceWindowMatcherUsesTerminalHintBeforeHomeDirectory() throws {
    let session = AIAgentSession.stub(
        id: "s1",
        projectName: "~",
        status: .working,
        cwd: "/Users/wuxing",
        windowTitleHints: ["12844_1781085992565"]
    )

    let match = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "Terminal", title: "wuxing — wuxing — codex ◂ node ~/.local/state/fnm_multishells/12534_1781085967351/bin/codex — 120x30"),
            AgentWorkspaceWindowSnapshot(appName: "Terminal", title: "wuxing — wuxing — codex ◂ node ~/.local/state/fnm_multishells/12844_1781085992565/bin/codex — 120x30")
        ]
    )
    try expect(match?.window.title.contains("12844_1781085992565") == true, "terminal title hint should choose the matching codex terminal")

    let noHintSession = AIAgentSession.stub(
        id: "s2",
        projectName: "~",
        status: .working,
        cwd: "/Users/wuxing"
    )
    let broadHomeMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: noHintSession,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "Terminal", title: "wuxing — wuxing — codex")
        ]
    )
    try expect(broadHomeMatch == nil, "home-directory sessions should not match every terminal by username")
}

func workspaceWindowMatcherSupportsLocalizedTerminalAppName() throws {
    let session = AIAgentSession.stub(
        id: "s1",
        projectName: "~",
        status: .working,
        cwd: "/Users/wuxing",
        windowTitleHints: ["61429_1780995698425"]
    )

    let match = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "终端", title: "wuxing — ⠼ wuxing — codex ◂ node ~/.local/state/fnm_multishells/61429_1780995698425/bin/codex — 102x43")
        ]
    )

    try expect(match?.kind == .codexTerminal, "localized Terminal app names should match Codex terminal title hints")
}

func workspaceWindowMatcherSupportsJetBrainsAndTrae() throws {
    let session = AIAgentSession.stub(
        id: "s1",
        projectName: "tsailun",
        status: .working,
        cwd: "/Users/wuxing/IdeaProjects/tsailun"
    )

    let jetBrainsMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "IntelliJ IDEA", title: "tsailun - pom.xml")
        ]
    )
    try expect(jetBrainsMatch?.kind == .ide, "JetBrains IDE windows should match by project title")

    let traeMatch = AgentWorkspaceWindowMatcher.bestMatch(
        for: session,
        windows: [
            AgentWorkspaceWindowSnapshot(appName: "TRAE CN", title: "tsailun - TRAE CN")
        ]
    )
    try expect(traeMatch?.kind == .ide, "Trae windows should match by project title")
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
    secondaryResetAt: String = "2026-06-11T00:00:00Z",
    limitID: String = "codex"
) -> String {
    let primaryResetEpoch = Int(date(primaryResetAt).timeIntervalSince1970)
    let secondaryResetEpoch = Int(date(secondaryResetAt).timeIntervalSince1970)
    return """
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":\(totalTokens)}},"rate_limits":{"limit_id":"\(limitID)","primary":{"used_percent":\(primaryUsedPercent),"window_minutes":\(primaryWindowMinutes),"resets_at":\(primaryResetEpoch)},"secondary":{"used_percent":\(secondaryUsedPercent),"window_minutes":\(secondaryWindowMinutes),"resets_at":\(secondaryResetEpoch)}}}}
    """
}

func apiCreditTokenCountLine(
    timestamp: String,
    totalTokens: Int,
    remainingCredits: Double,
    totalCredits: Double,
    currency: String
) -> String {
    """
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":\(totalTokens)}},"rate_limits":{"plan_type":"api","credits":{"remaining":\(remainingCredits),"total":\(totalCredits),"currency":"\(currency)"}}}}
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
        cwd: String? = nil,
        windowTitleHints: [String] = []
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
        summary: status.label,
            windowTitleHints: windowTitleHints,
            codexProcessID: nil
        )
    }
}

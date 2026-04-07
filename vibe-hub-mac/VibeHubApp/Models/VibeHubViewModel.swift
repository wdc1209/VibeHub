import Foundation
import SwiftUI

@MainActor
final class VibeHubViewModel: ObservableObject {
    enum ActiveEditor {
        case none
        case body
        case rawInput
    }

    private static let appSendAuditURL = URL(fileURLWithPath: "/tmp/vibe-hub-app-send.log")

    @Published var bodyText: String = ""
    @Published var rawInput: String = ""
    @Published var inputTerminal: String = "微信"
    @Published var bridgeConnected: Bool = false
    @Published var selectedTarget: String = "codex"
    @Published var codexConnected: Bool = false
    @Published var installedApps: [BridgeApp] = []
    @Published var statusText: String = "待发送"
    @Published var feedbackText: String = ""
    @Published var tokenSessionUpdatedAt: String = ""
    @Published var appBuildLabel: String = "native-swiftui"
    @Published var lastSendCommand: String = ""
    @Published var showStatusPanel: Bool = false
    @Published var showHistoryPanel: Bool = false
    @Published var showHelpPanel: Bool = false
    @Published var rawInputExpanded: Bool = false
    @Published var bridgeInstalledAppCount: Int = 0
    @Published var inputSources: [BridgeConnectionRow] = []
    @Published var agentConnections: [BridgeConnectionRow] = []
    @Published var outputTerminals: [BridgeOutputTerminal] = []
    @Published var outputWebsites: [BridgeOutputTerminal] = []
    @Published var selectedWindowId: String = ""
    @Published var localTutorialUrl: String = ""
    @Published var llmSettings: BridgeLLMSettings?
    @Published var lifecycleHint: String = "等待输入"
    @Published var needsRewriteAfterMerge: Bool = false
    @Published var llmActionRunning: Bool = false
    @Published var isSending: Bool = false
    @Published var voiceCaptureState: VoiceCaptureState = .idle
    @Published var voiceCaptureHint: String = "点一下开始录音，再点一下结束并并入 Vibe Hub 原始输入"
    @Published var voiceTranscriptPreview: String = ""
    @Published var voiceProcessingIndicatorActive: Bool = false
    @Published private(set) var historyCount: Int = 0
    @Published private(set) var historyEntries: [SendHistoryEntry] = []
    @Published private(set) var recentHistory: [SendHistoryEntry] = []
    @Published private(set) var availableOutputCount: Int = 5

    private let historyStore = SendHistoryStore()
    private let voiceInputService = VoiceInputService()
    private let voiceRecognitionSettings = VoiceRecognitionSettingsStore.shared
    private var lastMergedRawInput: String = ""
    private var lastIntegratedMergedRawInput: String = ""
    private var lastCompletedRewriteSignature: String = ""
    private var pendingAutoRewrite = false
    private var voiceAutoRewritePending = false
    private var suppressBodyEditTracking = false
    private var suppressRawInputEditTracking = false
    private(set) var hasUserEditedBody = false
    private(set) var hasUserEditedRawInput = false
    private var lastSentBodySignature: String = ""
    private var lastSendAttemptAt: Date?
    private var lastSuccessfulSentBodySignature: String = ""
    private var finishVoiceCaptureWhenReady = false
    private var currentTokenSessionId: String?
    private var selectedWindowIdsByTarget: [String: String] = [:]
    private var activeEditor: ActiveEditor = .none
    private var pendingMergedRawInput: String?
    private var pendingRewriteResult: PendingRewriteResult?

    private struct PendingRewriteResult {
        let output: String
        let feedbackText: String
        let lifecycleHint: String
        let completionSignature: String?
        let integratedMergedRawInput: String?
    }

    init() {
        historyEntries = historyStore.entries
        historyCount = historyStore.entries.count
        recentHistory = Array(historyStore.entries.prefix(3))
        appBuildLabel = Self.readBuildLabel()
    }

    var selectedTargetLabel: String {
        outputTerminals.first(where: { $0.id == selectedTarget })?.label ?? selectedTarget
    }

    var currentTargetWindows: [BridgeTargetWindow] {
        outputTerminals.first(where: { $0.id == selectedTarget })?.windows ?? []
    }

    var selectedWindowLabel: String {
        currentTargetWindows.first(where: { $0.id == selectedWindowId })?.label
            ?? currentTargetWindows.first?.label
            ?? "当前窗口"
    }

    var selectedWindowTitle: String? {
        currentTargetWindows.first(where: { $0.id == selectedWindowId })?.title
            ?? currentTargetWindows.first?.title
    }

    func refresh() async {
        do {
            async let status = BridgeClient.shared.fetchStatus()
            let statusResult = try await status
            let sessionResult = try await BridgeClient.shared.fetchTokenSession(
                sessionId: statusResult.activeTokenSessionId
            )
            bridgeConnected = true
            inputTerminal = statusResult.inputTerminal ?? "微信"
            installedApps = statusResult.apps ?? []
            bridgeInstalledAppCount = statusResult.installedAppCount
            inputSources = statusResult.inputSources ?? []
            agentConnections = statusResult.agentConnections ?? []
            outputTerminals = statusResult.outputTerminals ?? []
            outputWebsites = statusResult.outputWebsites ?? []
            syncSelectedTargetAndWindow()
            localTutorialUrl = statusResult.localTutorialUrl ?? ""
            llmSettings = statusResult.llm
            codexConnected = statusResult.codex?.connected ?? false
            currentTokenSessionId = sessionResult.tokenSession?.sessionId
                ?? statusResult.activeTokenSessionId
            tokenSessionUpdatedAt = sessionResult.tokenSession?.updatedAt
                ?? statusResult.activeTokenSessionUpdatedAt
                ?? ""
            if let merged = sessionResult.tokenSession?.mergedText, !merged.isEmpty {
                if activeEditor == .none {
                    applyIncomingRawInput(merged)
                } else {
                    pendingMergedRawInput = merged
                }
            }
        } catch {
            bridgeConnected = false
            feedbackText = error.localizedDescription
        }
    }

    func rewriteBody() async {
        let draft = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty || !raw.isEmpty else { return }
        await runRewrite(
            rawInput: raw,
            draftText: draft,
            feedbackWhileRunning: "正在调用 LLM 整理当前内容...",
            lifecycleWhileRunning: "正在根据原始输入和当前整理稿生成新版内容",
            lifecycleOnSuccess: "已按当前整理内容重组，可直接发送或继续编辑",
            lifecycleOnFailure: "整理失败，请继续编辑或稍后再试",
            markPendingOnFailure: true
        )
    }

    func compressBody() async {
        let draft = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }

        llmActionRunning = true
        statusText = "压缩中"
        feedbackText = "正在调用 LLM 压缩当前内容..."
        lifecycleHint = "正在生成更短的可发送版本"

        defer { llmActionRunning = false }

        do {
            let result = try await BridgeClient.shared.compressDraft(
                draftText: draft,
                target: selectedTargetLabel
            )
            let output = (result.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else {
                throw NSError(domain: "VibeHubLLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM 未返回有效压缩结果"])
            }

            setBodyText(output)
            statusText = "已压缩"
            feedbackText = "已用 \(result.provider ?? "LLM") / \(result.model ?? "model") 压缩"
            lifecycleHint = "已压缩当前整理内容，可直接发送或继续编辑"
            needsRewriteAfterMerge = false
            hasUserEditedBody = false
        } catch {
            statusText = "压缩失败"
            feedbackText = error.localizedDescription
            lifecycleHint = "压缩失败，请继续编辑或稍后再试"
        }
    }

    func clearCurrentRound() async {
        if let sessionId = currentTokenSessionId {
            try? await BridgeClient.shared.clearTokenSession(sessionId: sessionId)
        } else {
            try? await BridgeClient.shared.clearTokenSession(sessionId: nil)
        }
        currentTokenSessionId = nil
        resetForNewRound()
        statusText = "待发送"
        feedbackText = "已清空本轮原始输入与整理内容"
        lifecycleHint = "已从 0 开始新一轮，可继续输入"
    }

    func setActiveEditor(_ editor: ActiveEditor) {
        activeEditor = editor
        guard editor == .none else { return }
        applyDeferredExternalUpdates()
    }

    func userEditedBody(_ value: String) {
        guard !suppressBodyEditTracking else { return }
        bodyText = value
        let signature = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if signature != lastSuccessfulSentBodySignature {
            lastSuccessfulSentBodySignature = ""
        }
        hasUserEditedBody = true
        if statusText == "待发送" {
            statusText = "编辑中"
        }
        lifecycleHint = needsRewriteAfterMerge
            ? "你正在编辑当前整理稿；有新的原始输入待重新整理"
            : "你正在编辑当前整理内容，可直接发送或继续改写"
    }

    func userEditedRawInput(_ value: String) {
        guard !suppressRawInputEditTracking else { return }
        rawInput = value
        hasUserEditedRawInput = true
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            statusText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "待发送" : statusText
            lifecycleHint = "原始输入已清空，可继续手动编辑或等待新的输入"
            return
        }
        if !llmActionRunning {
            statusText = "编辑中"
        }
        lifecycleHint = "你正在编辑原始输入；新的外部输入会按增量并入，不会覆盖当前修改"
    }

    func startVoiceCapture() {
        guard voiceCaptureState != .recording, voiceCaptureState != .processing else { return }
        finishVoiceCaptureWhenReady = false
        voiceCaptureState = .requestingPermission
        voiceCaptureHint = "正在准备语音输入"
        feedbackText = "请求麦克风与语音识别权限..."

        Task {
            do {
                try await voiceInputService.startRecording(backend: voiceRecognitionSettings.selectedBackend) { [weak self] partial in
                    guard let self else { return }
                    self.voiceTranscriptPreview = partial
                    self.voiceCaptureState = .recording
                    self.voiceCaptureHint = partial.isEmpty
                        ? "正在听你说话..."
                        : "正在转写语音，可松开发送"
                    self.feedbackText = partial.isEmpty
                        ? "录音中"
                        : "语音转写中"
                }
                if voiceCaptureState == .requestingPermission {
                    voiceCaptureState = .recording
                    voiceCaptureHint = "正在听你说话..."
                    feedbackText = "录音中"
                }
                if finishVoiceCaptureWhenReady {
                    finishVoiceCaptureWhenReady = false
                    self.finishVoiceCapture()
                }
            } catch {
                voiceCaptureState = .failed
                voiceCaptureHint = error.localizedDescription
                feedbackText = error.localizedDescription
            }
        }
    }

    func finishVoiceCapture() {
        guard voiceCaptureState == .recording || voiceCaptureState == .requestingPermission else { return }
        if voiceCaptureState == .requestingPermission {
            finishVoiceCaptureWhenReady = true
            voiceCaptureHint = "松开已记录，权限完成后会立即结束录音"
            feedbackText = "等待语音权限完成"
            return
        }

        voiceCaptureState = .processing
        voiceProcessingIndicatorActive = true
        voiceCaptureHint = "正在结束录音并写入 Vibe Hub"
        feedbackText = "语音处理中..."

        Task {
            do {
                let transcript = try await voiceInputService.stopRecording(backend: voiceRecognitionSettings.selectedBackend)
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    voiceCaptureState = .idle
                    voiceProcessingIndicatorActive = false
                    voiceCaptureHint = "没有识别到可用语音，可再试一次"
                    feedbackText = "未捕获到可用语音"
                    return
                }

                voiceTranscriptPreview = trimmed
                voiceAutoRewritePending = true
                do {
                    let result = try await BridgeClient.shared.submitVoiceInput(text: trimmed)
                    if let merged = result.tokenSession?.mergedText, !merged.isEmpty {
                        applyIncomingRawInput(merged)
                    } else {
                        applyIncomingRawInput(trimmed)
                    }
                    feedbackText = result.message ?? "语音已收进 Vibe Hub"
                    voiceCaptureState = .idle
                    voiceCaptureHint = "语音已收进 Vibe Hub，可继续按住补充"
                } catch {
                    let existingRaw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    let localMerged = existingRaw.isEmpty ? trimmed : "\(existingRaw)\n\n\(trimmed)"
                    applyIncomingRawInput(localMerged)
                    voiceCaptureState = .failed
                    voiceCaptureHint = "bridge 断开，已先保留本地转写"
                    feedbackText = "语音已转写，但写入 bridge 失败：\(error.localizedDescription)"
                }
            } catch {
                voiceCaptureState = .failed
                voiceProcessingIndicatorActive = false
                voiceCaptureHint = error.localizedDescription
                feedbackText = error.localizedDescription
            }
        }
    }

    func toggleVoiceCapture() {
        switch voiceCaptureState {
        case .idle, .failed:
            startVoiceCapture()
        case .requestingPermission, .recording:
            finishVoiceCapture()
        case .processing:
            break
        }
    }

    func cancelVoiceCapture() {
        finishVoiceCaptureWhenReady = false
        voiceInputService.cancelRecording()
        voiceCaptureState = .idle
        voiceProcessingIndicatorActive = false
        voiceAutoRewritePending = false
        voiceCaptureHint = "已取消本次语音输入"
        feedbackText = "语音输入已取消"
    }

    private func applyIncomingRawInput(_ merged: String) {
        if activeEditor != .none {
            pendingMergedRawInput = merged
            return
        }
        guard merged != lastMergedRawInput else { return }
        let previousMerged = lastMergedRawInput
        lastMergedRawInput = merged
        let incomingRaw = merged.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw: String
        if hasUserEditedRawInput {
            raw = mergeIncomingRawInput(existing: rawInput, previousMerged: previousMerged, incomingMerged: merged)
            setRawInput(raw, preserveUserEditState: true)
        } else {
            raw = incomingRaw
            setRawInput(merged, preserveUserEditState: false)
        }
        guard !raw.isEmpty else { return }

        let draft = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        statusText = "整理中"
        feedbackText = draft.isEmpty
            ? "已收到原始输入，正在调用 LLM 生成整理稿"
            : "已收到新输入，正在基于当前整理稿重新整理"
        lifecycleHint = draft.isEmpty
            ? "原始输入已进入 Vibe Hub，主编辑区只显示整理后的内容"
            : "正在按 A/B/C 生命周期把当前整理稿与新原始输入重新整理"
        needsRewriteAfterMerge = llmActionRunning

        requestAutomaticRewrite(mergedRawInput: raw)
    }

    private func setBodyText(_ value: String) {
        let signature = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if signature != lastSuccessfulSentBodySignature {
            lastSuccessfulSentBodySignature = ""
        }
        suppressBodyEditTracking = true
        bodyText = value
        suppressBodyEditTracking = false
    }

    private func setRawInput(_ value: String, preserveUserEditState: Bool) {
        suppressRawInputEditTracking = true
        rawInput = value
        suppressRawInputEditTracking = false
        hasUserEditedRawInput = preserveUserEditState
    }

    private func mergeIncomingRawInput(existing: String, previousMerged: String, incomingMerged: String) -> String {
        let existingTrimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTrimmed = previousMerged.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingTrimmed = incomingMerged.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !incomingTrimmed.isEmpty else { return existingTrimmed }
        guard !existingTrimmed.isEmpty else { return incomingTrimmed }

        if !previousTrimmed.isEmpty, incomingTrimmed.hasPrefix(previousTrimmed) {
            let delta = String(incomingTrimmed.dropFirst(previousTrimmed.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !delta.isEmpty {
                return "\(existingTrimmed)\n\n\(delta)"
            }
        }

        if existingTrimmed.contains(incomingTrimmed) {
            return existingTrimmed
        }

        return "\(existingTrimmed)\n\n\(incomingTrimmed)"
    }

    private func requestAutomaticRewrite(mergedRawInput: String) {
        let mergedRaw = mergedRawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mergedRaw.isEmpty else { return }

        let incrementalRawInput: String
        if draftText.isEmpty || lastIntegratedMergedRawInput.isEmpty {
            incrementalRawInput = mergedRaw
        } else if mergedRaw.hasPrefix(lastIntegratedMergedRawInput) {
            let delta = String(mergedRaw.dropFirst(lastIntegratedMergedRawInput.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            incrementalRawInput = delta.isEmpty ? mergedRaw : delta
        } else {
            incrementalRawInput = mergedRaw
        }

        let signature = automaticRewriteSignature(rawInput: mergedRaw, draftText: draftText)
        guard signature != lastCompletedRewriteSignature else { return }

        if llmActionRunning {
            pendingAutoRewrite = true
            needsRewriteAfterMerge = true
            return
        }

        let isVoiceTriggeredRewrite = voiceAutoRewritePending
        voiceAutoRewritePending = false

        Task {
            await runRewrite(
                rawInput: incrementalRawInput,
                draftText: draftText,
                feedbackWhileRunning: draftText.isEmpty
                    ? "正在根据原始输入生成整理稿..."
                    : "正在把当前整理稿与新原始输入重新整理...",
                lifecycleWhileRunning: draftText.isEmpty
                    ? "正在根据原始输入生成整理稿"
                    : "正在按 A/B/C 生命周期重新整理",
                lifecycleOnSuccess: "主编辑区已更新为 LLM 整理后的内容，可继续编辑或发送",
                lifecycleOnFailure: "自动整理失败，请手动点“整理”重试",
                markPendingOnFailure: true,
                completionSignature: signature,
                integratedMergedRawInput: mergedRaw,
                keepVoiceIndicatorDuringRun: isVoiceTriggeredRewrite
            )
        }
    }

    private func automaticRewriteSignature(rawInput: String, draftText: String) -> String {
        "\(rawInput.trimmingCharacters(in: .whitespacesAndNewlines))\n---draft---\n\(draftText.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func runRewrite(
        rawInput: String,
        draftText: String,
        feedbackWhileRunning: String,
        lifecycleWhileRunning: String,
        lifecycleOnSuccess: String,
        lifecycleOnFailure: String,
        markPendingOnFailure: Bool,
        completionSignature: String? = nil,
        integratedMergedRawInput: String? = nil,
        keepVoiceIndicatorDuringRun: Bool = false
    ) async {
        llmActionRunning = true
        if keepVoiceIndicatorDuringRun {
            voiceProcessingIndicatorActive = true
        }
        statusText = "整理中"
        feedbackText = feedbackWhileRunning
        lifecycleHint = lifecycleWhileRunning

        defer {
            llmActionRunning = false
            if keepVoiceIndicatorDuringRun {
                voiceProcessingIndicatorActive = false
            }
            if pendingAutoRewrite {
                pendingAutoRewrite = false
                let latestRaw = self.rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !latestRaw.isEmpty {
                    requestAutomaticRewrite(mergedRawInput: latestRaw)
                }
            }
        }

        do {
            let result = try await BridgeClient.shared.rewriteDraft(
                rawInput: rawInput,
                draftText: draftText,
                target: selectedTargetLabel
            )
            let output = (result.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else {
                throw NSError(domain: "VibeHubLLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "LLM 未返回有效整理结果"])
            }

            if activeEditor != .none {
                pendingRewriteResult = PendingRewriteResult(
                    output: output,
                    feedbackText: "已完成整理，结束当前输入后会自动更新",
                    lifecycleHint: "你正在输入，已暂停写回；结束输入后会应用最新整理稿",
                    completionSignature: completionSignature,
                    integratedMergedRawInput: integratedMergedRawInput
                )
                statusText = "待应用"
                feedbackText = "已完成整理，结束当前输入后会自动更新"
                lifecycleHint = "你正在输入，已暂停写回；结束输入后会应用最新整理稿"
                needsRewriteAfterMerge = false
                return
            }

            setBodyText(output)
            statusText = "已整理"
            feedbackText = "已用 \(result.provider ?? "LLM") / \(result.model ?? "model") 整理"
            lifecycleHint = lifecycleOnSuccess
            needsRewriteAfterMerge = false
            hasUserEditedBody = false
            if let integratedMergedRawInput {
                lastIntegratedMergedRawInput = integratedMergedRawInput
            }
            if let completionSignature {
                lastCompletedRewriteSignature = completionSignature
            } else {
                lastCompletedRewriteSignature = automaticRewriteSignature(rawInput: rawInput, draftText: draftText)
            }
        } catch {
            statusText = "整理失败"
            feedbackText = error.localizedDescription
            lifecycleHint = lifecycleOnFailure
            needsRewriteAfterMerge = markPendingOnFailure
        }
    }

    private static func readBuildLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let path = URL(fileURLWithPath: CommandLine.arguments[0]).path
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let modified = attrs[.modificationDate] as? Date {
            return "build \(formatter.string(from: modified))"
        }
        return "native-swiftui"
    }

    private func resetAfterSuccessfulSend() {
        lastSuccessfulSentBodySignature = ""
        lastSentBodySignature = ""
        lastSendAttemptAt = nil
        resetForNewRound()
        lifecycleHint = "上一轮已完成，等待新的原始输入"
    }

    private func resetForNewRound() {
        setBodyText("")
        setRawInput("", preserveUserEditState: false)
        voiceTranscriptPreview = ""
        voiceProcessingIndicatorActive = false
        voiceAutoRewritePending = false
        tokenSessionUpdatedAt = ""
        lastMergedRawInput = ""
        lastIntegratedMergedRawInput = ""
        lastCompletedRewriteSignature = ""
        pendingAutoRewrite = false
        suppressBodyEditTracking = false
        hasUserEditedBody = false
        hasUserEditedRawInput = false
        needsRewriteAfterMerge = false
        finishVoiceCaptureWhenReady = false
        voiceCaptureState = .idle
        voiceCaptureHint = "点一下开始录音，再点一下结束并并入 Vibe Hub 原始输入"
        pendingMergedRawInput = nil
        pendingRewriteResult = nil
        activeEditor = .none
    }

    func send() async {
        let text = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let target = selectedTarget
        let targetLabel = selectedTargetLabel
        let windowTitle = selectedWindowTitle
        let windowLabel = selectedWindowTitle == nil ? nil : selectedWindowLabel
        let signature = text
        let now = Date()
        appendAppSendAudit(event: "tap", text: text, target: targetLabel)
        if lastSuccessfulSentBodySignature == signature {
            statusText = "已拦截重复发送"
            feedbackText = "当前整理稿已经发送过。请先修改内容，再次发送。"
            lifecycleHint = "同一份整理稿只会发送一次；编辑后可再次发送"
            appendAppSendAudit(event: "blocked_same_successful_signature", text: text, target: targetLabel)
            return
        }
        if lastSentBodySignature == signature,
           let lastSendAttemptAt,
           now.timeIntervalSince(lastSendAttemptAt) < 2 {
            statusText = "已拦截重复发送"
            feedbackText = "检测到 2 秒内同内容重复发送，已忽略本次点击"
            lifecycleHint = "重复点击已拦截，可继续编辑或稍后再发"
            appendAppSendAudit(event: "blocked_recent_duplicate", text: text, target: targetLabel)
            return
        }
        lastSentBodySignature = signature
        lastSendAttemptAt = now
        isSending = true
        statusText = "发送中"
        feedbackText = "正在发送到 \(targetLabel)..."
        appendAppSendAudit(event: "request_bridge", text: text, target: targetLabel)
        defer { isSending = false }
        do {
            let result = try await BridgeClient.shared.sendToTarget(text: text, target: target, windowTitle: windowTitle)
            let ok = result.ok ?? false
            statusText = ok ? "已发送" : "发送失败"
            let feedbackParts = [result.target, ok ? result.output : result.error]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            feedbackText = feedbackParts.isEmpty ? targetLabel : feedbackParts.joined(separator: " · ")
            lifecycleHint = ok ? "已发送当前整理内容" : "发送失败，请检查连接或继续编辑"
            needsRewriteAfterMerge = false
            if ok {
                lastSuccessfulSentBodySignature = signature
            }
            lastSendCommand = result.command ?? ""
            appendAppSendAudit(event: ok ? "bridge_success" : "bridge_failure_response", text: text, target: targetLabel)
            let destination = [result.target ?? targetLabel, windowLabel].compactMap { $0 }.joined(separator: " / ")
            let historySummary = ok
                ? "已发送到 \(destination)"
                : (result.error ?? "发送失败")
            historyStore.append(target: destination.isEmpty ? (result.target ?? targetLabel) : destination, text: text, status: statusText, summary: historySummary)
            historyEntries = historyStore.entries
            historyCount = historyStore.entries.count
            recentHistory = Array(historyStore.entries.prefix(3))
            if ok {
                let sentSessionId = result.sessionId?.trimmingCharacters(in: .whitespacesAndNewlines)
                let sessionIdsToClear = Array(
                    Set([currentTokenSessionId, sentSessionId].compactMap { sessionId in
                        let trimmed = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmed.isEmpty ? nil : trimmed
                    })
                )
                for sessionId in sessionIdsToClear {
                    try? await BridgeClient.shared.clearTokenSession(sessionId: sessionId)
                }
                currentTokenSessionId = nil
                resetAfterSuccessfulSend()
            }
        } catch {
            statusText = "发送失败"
            feedbackText = error.localizedDescription
            lifecycleHint = "发送失败，请检查连接或继续编辑"
            appendAppSendAudit(event: "bridge_throw", text: text, target: targetLabel, details: error.localizedDescription)
            historyStore.append(target: targetLabel, text: text, status: statusText, summary: error.localizedDescription)
            historyEntries = historyStore.entries
            historyCount = historyStore.entries.count
            recentHistory = Array(historyStore.entries.prefix(3))
        }
    }

    func selectPreviousTarget() {
        cycleTarget(step: -1)
    }

    func selectNextTarget() {
        cycleTarget(step: 1)
    }

    private func cycleTarget(step: Int) {
        guard !outputTerminals.isEmpty else { return }
        let ids = outputTerminals.map(\.id)
        guard !ids.isEmpty else { return }
        let currentIndex = ids.firstIndex(of: selectedTarget) ?? 0
        let nextIndex = (currentIndex + step + ids.count) % ids.count
        selectedWindowIdsByTarget[selectedTarget] = selectedWindowId
        selectedTarget = ids[nextIndex]
        syncSelectedWindow()
        feedbackText = "当前目标已切换到 \(selectedTargetLabel)"
    }

    func selectPreviousWindow() {
        cycleWindow(step: -1)
    }

    func selectNextWindow() {
        cycleWindow(step: 1)
    }

    func userSelectedWindow(_ windowId: String) {
        selectedWindowId = windowId
        selectedWindowIdsByTarget[selectedTarget] = windowId
        guard let window = currentTargetWindows.first(where: { $0.id == windowId }) else {
            return
        }
        Task {
            try? await BridgeClient.shared.selectTargetWindow(
                target: selectedTarget,
                windowTitle: window.title
            )
        }
    }

    func selectedTargetDidChange() {
        syncSelectedWindow()
    }

    private func cycleWindow(step: Int) {
        let windows = currentTargetWindows
        guard windows.count > 1 else { return }
        let ids = windows.map(\.id)
        let currentIndex = ids.firstIndex(of: selectedWindowId) ?? 0
        let nextIndex = (currentIndex + step + ids.count) % ids.count
        let nextId = ids[nextIndex]
        userSelectedWindow(nextId)
        feedbackText = "当前窗口已切换到 \(selectedWindowLabel)"
    }

    private func syncSelectedTargetAndWindow() {
        if !outputTerminals.contains(where: { $0.id == selectedTarget }), let first = outputTerminals.first {
            selectedTarget = first.id
        }
        syncSelectedWindow()
    }

    private func syncSelectedWindow() {
        let windows = currentTargetWindows
        guard !windows.isEmpty else {
            selectedWindowId = ""
            return
        }
        let restored = selectedWindowIdsByTarget[selectedTarget]
        let resolved = windows.contains(where: { $0.id == restored }) ? restored! : windows[0].id
        selectedWindowId = resolved
        selectedWindowIdsByTarget[selectedTarget] = resolved
    }

    private func appendAppSendAudit(event: String, text: String, target: String? = nil, details: String? = nil) {
        let payload: [String: String] = [
            "at": ISO8601DateFormatter().string(from: Date()),
            "event": event,
            "text": text,
            "target": target ?? "",
            "details": details ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              var line = String(data: data, encoding: .utf8) else { return }
        line.append("\n")
        if let handle = try? FileHandle(forWritingTo: Self.appSendAuditURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: Self.appSendAuditURL, atomically: true, encoding: .utf8)
        }
    }

    private func applyDeferredExternalUpdates() {
        if let merged = pendingMergedRawInput {
            pendingMergedRawInput = nil
            pendingRewriteResult = nil
            applyIncomingRawInput(merged)
            return
        }

        guard let pendingRewriteResult else { return }
        self.pendingRewriteResult = nil
        setBodyText(pendingRewriteResult.output)
        statusText = "已整理"
        feedbackText = pendingRewriteResult.feedbackText
        lifecycleHint = pendingRewriteResult.lifecycleHint
        needsRewriteAfterMerge = false
        hasUserEditedBody = false
        if let integratedMergedRawInput = pendingRewriteResult.integratedMergedRawInput {
            lastIntegratedMergedRawInput = integratedMergedRawInput
        }
        if let completionSignature = pendingRewriteResult.completionSignature {
            lastCompletedRewriteSignature = completionSignature
        }
    }
}

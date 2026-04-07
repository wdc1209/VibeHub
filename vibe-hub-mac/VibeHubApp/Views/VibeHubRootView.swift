import AppKit
import SwiftUI

private struct VibeHubGlowLayer: View {
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct VibeHubRootView: View {
    private enum FocusField: Hashable {
        case bodyEditor
        case rawInputEditor
    }

    @StateObject private var viewModel = VibeHubViewModel()
    @ObservedObject private var shortcutSettings = ShortcutSettingsStore.shared
    @State private var keyDownMonitor: Any?
    @State private var keyUpMonitor: Any?
    @State private var flagsChangedMonitor: Any?
    @State private var voiceShortcutPressing = false
    @State private var voiceStatePulse = false
    @State private var voicePulseTask: Task<Void, Never>?
    @AppStorage("vibeHub.windowPinned") private var windowPinned = false
    @AppStorage("vibeHub.compactMode") private var compactMode = false
    @AppStorage("vibeHub.rawInputExpanded") private var rawInputExpandedPreference = false
    @FocusState private var focusedField: FocusField?
    private let cardOuterInset: CGFloat = 14
    private let backgroundOutset: CGFloat = 500
    private let glowTop: CGFloat = 20
    private let glowLeading: CGFloat = 20
    private let glowBottom: CGFloat = 20
    private let glowTrailing: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                backgroundLayer
                mainCard
                    .frame(width: proxy.size.width - (cardOuterInset * 2), alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(minWidth: compactMode ? 760 : 980, minHeight: compactMode ? 210 : 620)
        .task {
            await viewModel.refresh()
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(5))
                guard focusedField == nil else { continue }
                await viewModel.refresh()
            }
        }
        .onAppear(perform: installKeyboardMonitors)
        .onDisappear(perform: removeKeyboardMonitors)
        .onChange(of: focusedField) { _, newValue in
            switch newValue {
            case .bodyEditor:
                viewModel.setActiveEditor(.body)
            case .rawInputEditor:
                viewModel.setActiveEditor(.rawInput)
            case nil:
                viewModel.setActiveEditor(.none)
            }
        }
        .onAppear {
            updateVoicePulseLoop()
        }
        .onChange(of: viewModel.voiceProcessingIndicatorActive) { _, _ in
            updateVoicePulseLoop()
        }
        .onChange(of: viewModel.voiceCaptureState) { _, _ in
            updateVoicePulseLoop()
        }
        .onDisappear {
            voicePulseTask?.cancel()
            voicePulseTask = nil
            voiceStatePulse = false
        }
    }

    private var backgroundLayer: some View {
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
    }

    private var mainCard: some View {
        let cornerRadius: CGFloat = 26
        let cardShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return VStack(spacing: 16) {
            if compactMode {
                compactContent
            } else {
                headerSection
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 16) {
                        editorSection
                        voiceInputSection
                        rawInputSection
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                footerSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: compactMode ? 150 : nil, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(cardOuterInset)
        .background {
            ZStack {
                Color.clear
                VibeHubGlowLayer()
                cardShape.fill(.white.opacity(0.10))
                cardShape.fill(.ultraThinMaterial.opacity(0.78))
            }
        }
        .overlay(
            cardShape
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .compositingGroup()
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            compactHeaderSection
            compactWorkbenchSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    private var compactHeaderSection: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                VibeHubLogoView()
                HStack(spacing: 10) {
                    Text("Vibe Hub")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    currentTargetStatusBadge
                }
            }

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Text("目标")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $viewModel.selectedTarget) {
                    ForEach(pickerTargets) { terminal in
                        Text(terminal.label).tag(terminal.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("目标")
                .frame(width: 126)
                .onChange(of: viewModel.selectedTarget) { _, _ in
                    viewModel.selectedTargetDidChange()
                }
            }

            if !viewModel.currentTargetWindows.isEmpty {
                HStack(spacing: 6) {
                    Text(viewModel.selectedTarget == "codex" ? "线程" : "窗口")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.selectedWindowId },
                        set: { value in viewModel.userSelectedWindow(value) }
                    )) {
                        ForEach(viewModel.currentTargetWindows) { window in
                            Text(window.label).tag(window.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("窗口")
                    .frame(width: 138)
                }
            }

            Button {
                windowPinned.toggle()
                NotificationCenter.default.post(name: .tokenCardPinnedChanged, object: nil, userInfo: ["pinned": windowPinned])
            } label: {
                Image(systemName: windowPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            Button {
                compactMode.toggle()
                NotificationCenter.default.post(name: .tokenCardCompactModeChanged, object: nil, userInfo: ["compact": compactMode])
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
    }

    private var compactWorkbenchSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                Text("整理后的内容")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(viewModel.lifecycleHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    TextEditor(text: Binding(
                        get: { viewModel.bodyText },
                        set: { value in viewModel.userEditedBody(value) }
                    ))
                    .focused($focusedField, equals: .bodyEditor)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .frame(height: 182)
                    .textSelection(.enabled)

                    HStack(alignment: .center, spacing: 6) {
                        Text(viewModel.feedbackText.isEmpty ? "等待 bridge 数据" : viewModel.feedbackText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let recent = viewModel.recentHistory.first {
                            Text("· 最近记录：\(recent.target) / \(recent.status)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(viewModel.statusText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                VStack(spacing: 6) {
                    voicePressSurface
                        .frame(width: 112)

                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 6) {
                            compactActionButton("重写", tint: viewModel.needsRewriteAfterMerge ? .orange : nil, prominent: viewModel.needsRewriteAfterMerge) {
                                focusedField = nil
                                Task { await viewModel.rewriteBody() }
                            }

                            compactActionButton("压缩") {
                                focusedField = nil
                                Task { await viewModel.compressBody() }
                            }

                            compactActionButton("清空") {
                                focusedField = nil
                                Task { await viewModel.clearCurrentRound() }
                            }
                        }

                        Button {
                            focusedField = nil
                            Task { await viewModel.send() }
                        } label: {
                            Text("发送")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 102)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color.blue)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                                )
                            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.blue.opacity(0.10), radius: 4, y: 1)
                        .disabled(viewModel.llmActionRunning || viewModel.isSending)
                    }
                    .frame(width: 112, alignment: .leading)
                }
                .frame(width: 112, alignment: .top)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                VibeHubLogoView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vibe Hub")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.bridgeConnected ? Color.green : Color.red)
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.85), lineWidth: 1)
                            )
                        Text(viewModel.bridgeConnected ? "bridge 已连接" : "bridge 未连接")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(viewModel.bridgeConnected ? Color.green : Color.red)
                    }
                    Text(viewModel.appBuildLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("目标", selection: $viewModel.selectedTarget) {
                ForEach(pickerTargets) { terminal in
                    Text(terminal.label).tag(terminal.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: compactMode ? 130 : 140)
            .onChange(of: viewModel.selectedTarget) { _, _ in
                viewModel.selectedTargetDidChange()
            }

            if !viewModel.currentTargetWindows.isEmpty {
                Picker(viewModel.selectedTarget == "codex" ? "线程" : "窗口", selection: Binding(
                    get: { viewModel.selectedWindowId },
                    set: { value in viewModel.userSelectedWindow(value) }
                )) {
                    ForEach(viewModel.currentTargetWindows) { window in
                        Text(window.label).tag(window.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: compactMode ? 190 : 250)
            }

            if !compactMode {
                Button {
                    NotificationCenter.default.post(name: .tokenCardToggleStatusWindow, object: nil)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)

                Button {
                    NotificationCenter.default.post(name: .tokenCardToggleHistoryWindow, object: nil)
                } label: {
                    Image(systemName: "clock")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
            }

            Button {
                windowPinned.toggle()
                NotificationCenter.default.post(name: .tokenCardPinnedChanged, object: nil, userInfo: ["pinned": windowPinned])
            } label: {
                Image(systemName: windowPinned ? "pin.fill" : "pin")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)

            Button {
                compactMode.toggle()
                NotificationCenter.default.post(name: .tokenCardCompactModeChanged, object: nil, userInfo: ["compact": compactMode])
            } label: {
                Image(systemName: compactMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)

            currentTargetStatusBadge
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("整理后的内容")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(viewModel.lifecycleHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                if viewModel.needsRewriteAfterMerge {
                    Text("建议整理后再发送")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.16), in: Capsule())
                }
            }

            TextEditor(text: Binding(
                get: { viewModel.bodyText },
                set: { value in viewModel.userEditedBody(value) }
            ))
            .focused($focusedField, equals: .bodyEditor)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 220, maxHeight: 280)
            .textSelection(.enabled)
        }
        .contentShape(Rectangle())
    }

    private var rawInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.rawInputExpanded.toggle()
                    rawInputExpandedPreference = viewModel.rawInputExpanded
                }
                NotificationCenter.default.post(
                    name: .tokenCardRawInputExpansionChanged,
                    object: nil,
                    userInfo: ["expanded": viewModel.rawInputExpanded]
                )
            } label: {
                HStack {
                    Image(systemName: viewModel.rawInputExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("原始输入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.tokenSessionUpdatedAt.isEmpty {
                        Text(viewModel.tokenSessionUpdatedAt)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if viewModel.rawInputExpanded {
                TextEditor(text: Binding(
                    get: { viewModel.rawInput },
                    set: { value in viewModel.userEditedRawInput(value) }
                ))
                    .focused($focusedField, equals: .rawInputEditor)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(height: 140)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                EmptyView()
            }
        }
        .contentShape(Rectangle())
    }

    private var voiceInputSection: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("语音输入")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(voiceStateLabel)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(voiceStateColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(voiceStateColor)
                }

                Text(viewModel.voiceTranscriptPreview.isEmpty ? viewModel.voiceCaptureHint : viewModel.voiceTranscriptPreview)
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.voiceTranscriptPreview.isEmpty ? .secondary : .primary)
                    .lineLimit(3)

                if viewModel.voiceTranscriptPreview.isEmpty {
                    Text("点击右侧按钮开始，再次点击结束。识别出的文字会先显示在这里，然后并入原始输入。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            voicePressSurface
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    private var voicePressSurface: some View {
        return Button {
            focusedField = nil
            viewModel.toggleVoiceCapture()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(voiceOrbFillColor)
                        .frame(width: 60, height: 60)
                    Image(systemName: voiceButtonIconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(voiceIconColor)
                }
                Text(voiceButtonTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 112, height: 91)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(voiceButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(voiceButtonStrokeColor.opacity(voiceButtonStrokeOpacity), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("语音输入")
    }

    @ViewBuilder
    private func compactActionButton(_ title: String, tint: Color? = nil, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        let fillColor = prominent ? (tint ?? .orange) : Color.white.opacity(0.94)
        let textColor = prominent ? Color.white : Color.primary
        let strokeColor = prominent ? fillColor.opacity(0.18) : Color.black.opacity(0.05)
        let shadowColor = prominent ? fillColor.opacity(0.14) : Color.black.opacity(0.06)

        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
                .frame(width: 52, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: shadowColor, radius: 3, y: 1)
        .opacity(viewModel.llmActionRunning || viewModel.isSending ? 0.55 : 1)
        .allowsHitTesting(!(viewModel.llmActionRunning || viewModel.isSending))
    }

    private func standardActionButton(_ title: String, tint: Color? = nil, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        let fillColor = prominent ? (tint ?? .orange) : Color.white.opacity(0.94)
        let textColor = prominent ? Color.white : Color.primary
        let strokeColor = prominent ? fillColor.opacity(0.18) : Color.black.opacity(0.05)
        let shadowColor = prominent ? fillColor.opacity(0.14) : Color.black.opacity(0.06)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
                .frame(width: 52, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: shadowColor, radius: 3, y: 1)
        .opacity(viewModel.llmActionRunning || viewModel.isSending ? 0.55 : 1)
        .allowsHitTesting(!(viewModel.llmActionRunning || viewModel.isSending))
    }


    private var voiceButtonIconName: String {
        switch effectiveVoiceVisualState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "sparkles"
        }
    }

    private var voiceStateLabel: String {
        switch effectiveVoiceVisualState {
        case .idle:
            return "待机"
        case .recording:
            return "录音中"
        case .processing:
            return "整理中"
        }
    }

    private var voiceStateColor: Color {
        switch effectiveVoiceVisualState {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .processing:
            return .green
        }
    }

    private var voiceButtonTitle: String {
        switch effectiveVoiceVisualState {
        case .recording:
            return "再次点击结束"
        case .processing:
            return "正在整理"
        case .idle:
            return "点击开始"
        }
    }

    private var voiceButtonBackground: Color {
        return .white.opacity(0.08)
    }

    private var voiceButtonStrokeColor: Color {
        switch effectiveVoiceVisualState {
        case .idle:
            return Color.gray
        case .recording:
            return Color.red
        case .processing:
            return Color.green
        }
    }

    private var voiceButtonStrokeOpacity: Double {
        switch effectiveVoiceVisualState {
        case .idle:
            return 0.3
        case .recording, .processing:
            return voiceStatePulse ? 0.98 : 0.25
        }
    }

    private var voiceOrbFillColor: Color {
        switch effectiveVoiceVisualState {
        case .idle:
            return Color.gray.opacity(0.18)
        case .recording:
            return Color.red.opacity(0.22)
        case .processing:
            return Color.green.opacity(0.22)
        }
    }

    private var voiceIconColor: Color {
        switch effectiveVoiceVisualState {
        case .idle:
            return Color(red: 0.28, green: 0.28, blue: 0.30)
        case .recording:
            return .red
        case .processing:
            return .green
        }
    }

    private enum VoiceVisualState {
        case idle
        case recording
        case processing
    }

    private var effectiveVoiceVisualState: VoiceVisualState {
        if viewModel.voiceProcessingIndicatorActive || viewModel.voiceCaptureState == .processing {
            return .processing
        }
        switch viewModel.voiceCaptureState {
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .idle, .requestingPermission, .failed:
            return .idle
        }
    }

    private func updateVoicePulseLoop() {
        let shouldPulse = effectiveVoiceVisualState == .recording || effectiveVoiceVisualState == .processing
        voicePulseTask?.cancel()
        voicePulseTask = nil
        guard shouldPulse else {
            voiceStatePulse = false
            return
        }
        voiceStatePulse = false
        voicePulseTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.36)) {
                        voiceStatePulse.toggle()
                    }
                }
                try? await Task.sleep(for: .milliseconds(360))
            }
        }
    }

    private var currentTargetTerminal: BridgeOutputTerminal? {
        return viewModel.outputTerminals.first { terminal in
            terminal.id == viewModel.selectedTarget
        }
    }

    private var pickerTargets: [BridgeOutputTerminal] {
        if viewModel.outputTerminals.isEmpty {
            return [BridgeOutputTerminal(id: viewModel.selectedTarget, label: viewModel.selectedTargetLabel, status: "未接入", connectAction: nil, windows: [])]
        }
        if viewModel.outputTerminals.contains(where: { $0.id == viewModel.selectedTarget }) {
            return viewModel.outputTerminals
        }
        return viewModel.outputTerminals + [
            BridgeOutputTerminal(id: viewModel.selectedTarget, label: viewModel.selectedTargetLabel, status: "未接入", connectAction: nil, windows: [])
        ]
    }

    private var currentTargetStatusText: String {
        if let terminal = currentTargetTerminal {
            return "\(terminal.label) \(terminal.status)"
        }
        return "\(viewModel.selectedTargetLabel) 未接入"
    }

    private var currentTargetStatusColor: Color {
        guard let terminal = currentTargetTerminal else { return .red }
        switch terminal.status {
        case "已连接":
            return .green
        case "可连接":
            return .orange
        default:
            return .red
        }
    }

    @ViewBuilder
    private var currentTargetStatusBadge: some View {
        if let action = currentTargetTerminal?.connectAction,
           currentTargetTerminal?.status == "可连接" {
            Button {
                Task {
                    try? await BridgeClient.shared.connectTerminal(action: action)
                    await viewModel.refresh()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentTargetStatusColor)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.85), lineWidth: 1)
                        )
                    Text(currentTargetStatusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(currentTargetStatusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    currentTargetStatusColor
                        .opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            currentTargetStatusColor
                                .opacity(0.35),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Circle()
                    .fill(currentTargetStatusColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.85), lineWidth: 1)
                    )
                Text(currentTargetStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(currentTargetStatusColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                currentTargetStatusColor
                    .opacity(0.12),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        currentTargetStatusColor
                            .opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(viewModel.feedbackText.isEmpty ? "等待 bridge 数据" : viewModel.feedbackText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let recent = viewModel.recentHistory.first {
                    Text("· 最近记录：\(recent.target) / \(recent.status)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Group {
                    if viewModel.needsRewriteAfterMerge {
                        standardActionButton("整理", tint: .orange, prominent: true) {
                            focusedField = nil
                            Task { await viewModel.rewriteBody() }
                        }
                    } else {
                        standardActionButton("重写") {
                            focusedField = nil
                            Task { await viewModel.rewriteBody() }
                        }
                    }
                }

                standardActionButton("压缩") {
                    focusedField = nil
                    Task { await viewModel.compressBody() }
                }
                standardActionButton("清空") {
                    focusedField = nil
                    Task { await viewModel.clearCurrentRound() }
                }
                .keyboardShortcut(.escape, modifiers: [])
                standardActionButton("发送", tint: .blue, prominent: true) {
                    focusedField = nil
                    Task { await viewModel.send() }
                }
            }

            if !compactMode {
                Text("发送：\(shortcutSettings.sendShortcutLabel) · 语音：\(shortcutSettings.voiceShortcutLabel) · 上一目标：\(shortcutSettings.previousTargetShortcutLabel) · 下一目标：\(shortcutSettings.nextTargetShortcutLabel) · 上一窗口：\(shortcutSettings.previousWindowShortcutLabel) · 下一窗口：\(shortcutSettings.nextWindowShortcutLabel)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !compactMode, !viewModel.lastSendCommand.isEmpty {
                Text(viewModel.lastSendCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }

    private func installKeyboardMonitors() {
        removeKeyboardMonitors()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if shortcutSettings.matches(event, action: .send) {
                Task { await viewModel.send() }
                return nil
            }

            if shortcutSettings.matches(event, action: .voice) {
                guard !voiceShortcutPressing else { return nil }
                voiceShortcutPressing = true
                viewModel.startVoiceCapture()
                return nil
            }

            guard focusedField == nil else {
                return event
            }

            if shortcutSettings.matches(event, action: .previousTarget) {
                viewModel.selectPreviousTarget()
                return nil
            }

            if shortcutSettings.matches(event, action: .nextTarget) {
                viewModel.selectNextTarget()
                return nil
            }

            if shortcutSettings.matches(event, action: .previousWindow) {
                viewModel.selectPreviousWindow()
                return nil
            }

            if shortcutSettings.matches(event, action: .nextWindow) {
                viewModel.selectNextWindow()
                return nil
            }

            return event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { event in
            guard voiceShortcutPressing else { return event }
            if shortcutSettings.shouldFinishVoice(for: event) {
                voiceShortcutPressing = false
                viewModel.finishVoiceCapture()
                return nil
            }
            return event
        }

        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            guard voiceShortcutPressing else { return event }
            if shortcutSettings.shouldFinishVoice(for: event) {
                voiceShortcutPressing = false
                viewModel.finishVoiceCapture()
            }
            return event
        }
    }

    private func removeKeyboardMonitors() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }
        if let flagsChangedMonitor {
            NSEvent.removeMonitor(flagsChangedMonitor)
            self.flagsChangedMonitor = nil
        }
        voiceShortcutPressing = false
    }
}

import AppKit
import Foundation
import SwiftUI

struct StatusPanelView: View {
    let selectedTarget: String
    let codexConnected: Bool
    let inputSources: [BridgeConnectionRow]
    let agentConnections: [BridgeConnectionRow]
    let outputTerminals: [BridgeOutputTerminal]
    let outputWebsites: [BridgeOutputTerminal]
    let localTutorialUrl: String
    let llmSettings: BridgeLLMSettings?
    @ObservedObject var shortcutSettings: ShortcutSettingsStore
    @ObservedObject var voiceRecognitionSettings: VoiceRecognitionSettingsStore
    let connectionFeedback: String
    let onConnectTerminal: (String) async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vibe Hub 状态面板")
                            .font(.system(size: 14, weight: .semibold))
                        Text("真实连接状态")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if !connectionFeedback.isEmpty {
                    statusCard {
                        Text("连接反馈")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(connectionFeedback)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                statusCard {
                    Text("总状态")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(codexConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(codexConnected ? "Codex 已连接" : "Codex 待连接")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    kvRow("当前目标", selectedTarget)
                    kvRow("输出终端连接情况", terminalConnectionSummary)
                    kvRow("输出网站连接情况", websiteConnectionSummary)
                }

                if !filteredInputSources.isEmpty || true {
                    statusCard {
                        Text("输入方式")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(filteredInputSources) { source in
                            connectionRow(source.label, inputBadge(for: source), source.current == true || source.connected == true)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("语音识别")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Picker(
                                "",
                                selection: Binding(
                                    get: { voiceRecognitionSettings.selectedBackendRaw },
                                    set: { voiceRecognitionSettings.setSelectedBackend(rawValue: $0) }
                                )
                            ) {
                                ForEach(VoiceRecognitionBackend.allCases) { backend in
                                    Text(backend.displayLabel).tag(backend.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if !agentConnections.isEmpty {
                    statusCard {
                        Text("可调用 Vibe Hub 的 Agent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(agentConnections) { agent in
                            connectionRow(agent.label, agent.connected == true ? "已连接" : "可用", agent.connected ?? false)
                        }
                    }
                }

                if !outputTerminals.isEmpty {
                    statusCard {
                        Text("输出终端")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(outputTerminals) { terminal in
                            HStack {
                                Text(terminal.label)
                                    .font(.system(size: 12))
                                Spacer()
                                if terminal.status == "可连接", let action = terminal.connectAction {
                                    Button("连接") {
                                        Task { await onConnectTerminal(action) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .controlSize(.small)
                                } else {
                                    Text(terminal.status)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusBackground(for: terminal.status), in: Capsule())
                                }
                            }
                        }
                    }
                }

                if !outputWebsites.isEmpty {
                    statusCard {
                        Text("输出网站")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(outputWebsites) { website in
                            HStack {
                                Text(website.label)
                                    .font(.system(size: 12))
                                Spacer()
                                if website.status == "可连接", let action = website.connectAction {
                                    Button("连接") {
                                        Task { await onConnectTerminal(action) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .controlSize(.small)
                                } else {
                                    Text(website.status)
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusBackground(for: website.status), in: Capsule())
                                }
                            }
                        }
                    }
                }

                if let llmSettings {
                    statusCard {
                        Text("LLM 设置")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        kvRow("Provider", llmSettings.provider ?? "未配置")
                        kvRow("Base URL", llmSettings.baseURL ?? "未配置")
                        kvRow("Rewrite 模型", llmSettings.modelRewrite ?? "未配置")
                        kvRow("Compress 模型", llmSettings.modelCompress ?? "未配置")
                        kvRow("Route 模型", llmSettings.modelRoute ?? "未配置")
                        kvRow("API Key", (llmSettings.apiKeyConfigured ?? false) ? "已通过环境变量接入" : "未配置")
                        kvRow("Key 来源", llmSettings.apiKeySource ?? "missing")
                        kvRow("Env Var", llmSettings.apiKeyEnvVar ?? "VIBE_HUB_LLM_API_KEY")
                        if let configPath = llmSettings.configPath, !configPath.isEmpty {
                            Text(configPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                statusCard {
                    Text("快捷键设置")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        shortcutField(
                            title: "发送快捷键",
                            text: Binding(
                                get: { shortcutSettings.sendShortcutInput },
                                set: { shortcutSettings.sendShortcutInput = $0 }
                            ),
                            placeholder: "control+enter",
                            error: shortcutSettings.sendShortcutError,
                            current: shortcutSettings.sendShortcutLabel,
                            onSave: { shortcutSettings.saveSendShortcut() }
                        )

                        shortcutField(
                            title: "语音快捷键",
                            text: Binding(
                                get: { shortcutSettings.voiceShortcutInput },
                                set: { shortcutSettings.voiceShortcutInput = $0 }
                            ),
                            placeholder: "control+m",
                            error: shortcutSettings.voiceShortcutError,
                            current: shortcutSettings.voiceShortcutLabel,
                            onSave: { shortcutSettings.saveVoiceShortcut() }
                        )

                        shortcutField(
                            title: "上一目标快捷键",
                            text: Binding(
                                get: { shortcutSettings.previousTargetShortcutInput },
                                set: { shortcutSettings.previousTargetShortcutInput = $0 }
                            ),
                            placeholder: "shift+up",
                            error: shortcutSettings.previousTargetShortcutError,
                            current: shortcutSettings.previousTargetShortcutLabel,
                            onSave: { shortcutSettings.savePreviousTargetShortcut() }
                        )

                        shortcutField(
                            title: "下一目标快捷键",
                            text: Binding(
                                get: { shortcutSettings.nextTargetShortcutInput },
                                set: { shortcutSettings.nextTargetShortcutInput = $0 }
                            ),
                            placeholder: "shift+down",
                            error: shortcutSettings.nextTargetShortcutError,
                            current: shortcutSettings.nextTargetShortcutLabel,
                            onSave: { shortcutSettings.saveNextTargetShortcut() }
                        )

                        shortcutField(
                            title: "上一窗口快捷键",
                            text: Binding(
                                get: { shortcutSettings.previousWindowShortcutInput },
                                set: { shortcutSettings.previousWindowShortcutInput = $0 }
                            ),
                            placeholder: "shift+left",
                            error: shortcutSettings.previousWindowShortcutError,
                            current: shortcutSettings.previousWindowShortcutLabel,
                            onSave: { shortcutSettings.savePreviousWindowShortcut() }
                        )

                        shortcutField(
                            title: "下一窗口快捷键",
                            text: Binding(
                                get: { shortcutSettings.nextWindowShortcutInput },
                                set: { shortcutSettings.nextWindowShortcutInput = $0 }
                            ),
                            placeholder: "shift+right",
                            error: shortcutSettings.nextWindowShortcutError,
                            current: shortcutSettings.nextWindowShortcutLabel,
                            onSave: { shortcutSettings.saveNextWindowShortcut() }
                        )
                    }
                }

                statusCard {
                    Text("本地教程")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if !localTutorialUrl.isEmpty {
                        Button("打开 Vibe Hub 本地教程网页") {
                            openLocalTutorial()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    } else {
                        Text("本地教程暂不可用")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
        .scrollIndicators(.visible)
        .frame(minWidth: 500, minHeight: 680)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
    }

    private var terminalConnectionSummary: String {
        guard !outputTerminals.isEmpty else { return "暂无输出终端" }
        let connected = outputTerminals.filter { $0.status == "已连接" }.count
        let connectable = outputTerminals.count
        return "\(connected) 个已连接 / \(connectable) 个可连接"
    }

    private var websiteConnectionSummary: String {
        guard !outputWebsites.isEmpty else { return "暂无输出网站" }
        let connected = outputWebsites.filter { $0.status == "已连接" || $0.status == "扩展已连接" }.count
        let connectable = outputWebsites.count
        return "\(connected) 个已连接 / \(connectable) 个可连接"
    }

    private var filteredInputSources: [BridgeConnectionRow] {
        inputSources.filter { source in
            let normalized = source.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized != "微信"
                && normalized != "book"
                && !normalized.contains("openclaw")
                && normalized != "webchat"
        }
    }

    private func statusCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kvRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }

    private func connectionRow(_ label: String, _ badge: String, _ connected: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text(badge)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((connected ? Color.green : Color.white).opacity(connected ? 0.18 : 0.08), in: Capsule())
        }
    }

    private func shortcutField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        error: String?,
        current: String,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Text("当前：\(current)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit(onSave)
                Button("保存", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(error != nil)
            }

            Text(error ?? "支持 control / command / option / shift + 单键，以及 enter / up / down / left / right。")
                .font(.system(size: 11))
                .foregroundStyle(error == nil ? Color.secondary : Color.red)
        }
    }

    private func inputBadge(for source: BridgeConnectionRow) -> String {
        if source.current == true {
            return "当前"
        }
        if source.connected == true {
            return "已接入"
        }
        return "未接入"
    }

    private func statusBackground(for status: String) -> Color {
        switch status {
        case "已连接":
            return .green.opacity(0.18)
        case "可连接":
            return .blue.opacity(0.18)
        default:
            return .white.opacity(0.08)
        }
    }

    private func openLocalTutorial() {
        guard let url = URL(string: localTutorialUrl) else { return }
        if url.isFileURL {
            let path = url.path
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [path]
            try? process.run()
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

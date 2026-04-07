import SwiftUI

struct StatusPanelHostView: View {
    @StateObject private var viewModel = VibeHubViewModel()
    @ObservedObject private var shortcutSettings = ShortcutSettingsStore.shared
    @ObservedObject private var voiceRecognitionSettings = VoiceRecognitionSettingsStore.shared
    @State private var connectionFeedback: String = ""
    @State private var lastConnectionTargetLabel: String?

    var body: some View {
        StatusPanelView(
            selectedTarget: viewModel.selectedTargetLabel,
            codexConnected: viewModel.codexConnected,
            inputSources: viewModel.inputSources,
            agentConnections: viewModel.agentConnections,
            outputTerminals: viewModel.outputTerminals,
            outputWebsites: viewModel.outputWebsites,
            localTutorialUrl: viewModel.localTutorialUrl,
            llmSettings: viewModel.llmSettings,
            shortcutSettings: shortcutSettings,
            voiceRecognitionSettings: voiceRecognitionSettings,
            connectionFeedback: connectionFeedback,
            onConnectTerminal: { action in
                do {
                    let result = try await BridgeClient.shared.connectTerminal(action: action)
                    lastConnectionTargetLabel = result.target
                    connectionFeedback = result.ok == true
                        ? ([result.target, result.output].compactMap { $0 }.joined(separator: " · "))
                        : (result.error ?? "连接失败")
                } catch {
                    connectionFeedback = error.localizedDescription
                }
                await viewModel.refresh()
                syncConnectionFeedbackWithLiveStatus()
            }
        )
        .padding(18)
        .background(Color.clear)
        .task {
            await viewModel.refresh()
            syncConnectionFeedbackWithLiveStatus()
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(5))
                await viewModel.refresh()
                syncConnectionFeedbackWithLiveStatus()
            }
        }
    }

    private func syncConnectionFeedbackWithLiveStatus() {
        guard let targetLabel = lastConnectionTargetLabel else { return }
        let terminal = viewModel.outputTerminals.first(where: { $0.label == targetLabel })
            ?? viewModel.outputWebsites.first(where: { $0.label == targetLabel })
        guard let terminal else { return }

        if terminal.status == "已连接" || terminal.status == "扩展已连接" {
            connectionFeedback = "\(terminal.label) · \(terminal.status)"
            return
        }

        if terminal.status == "可连接", connectionFeedback.contains("已连接") {
            connectionFeedback = "\(terminal.label) · 可连接"
        }
    }
}

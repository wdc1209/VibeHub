import Foundation

struct BridgeStatusResponse: Decodable {
    var inputTerminal: String?
    var apps: [BridgeApp]?
    var codex: BridgeCodexStatus?
    var antigravity: BridgeCodexStatus?
    var inputSources: [BridgeConnectionRow]?
    var agentConnections: [BridgeConnectionRow]?
    var outputTerminals: [BridgeOutputTerminal]?
    var outputWebsites: [BridgeOutputTerminal]?
    var localTutorialUrl: String?
    var activeTokenSessionId: String?
    var activeTokenSessionUpdatedAt: String?
    var llm: BridgeLLMSettings?

    var installedAppCount: Int {
        (apps ?? []).filter { $0.installed ?? false }.count
    }
}

struct BridgeApp: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let installed: Bool?

    var statusLabel: String {
        (installed ?? false) ? "已发现" : "未安装"
    }
}

struct BridgeConnectionRow: Decodable, Identifiable {
    let id: String
    let label: String
    let connected: Bool?
    let current: Bool?
}

struct BridgeOutputTerminal: Decodable, Identifiable {
    let id: String
    let label: String
    let status: String
    let connectAction: String?
    let windows: [BridgeTargetWindow]?
}

struct BridgeTargetWindow: Decodable, Identifiable, Equatable {
    let id: String
    let label: String
    let title: String
    let subtitle: String?
    let type: String?
}

struct BridgeCodexStatus: Decodable {
    let connected: Bool?
    let raw: String?
}

struct BridgeLLMSettings: Decodable {
    let provider: String?
    let baseURL: String?
    let apiKeyEnvVar: String?
    let apiKeyConfigured: Bool?
    let apiKeySource: String?
    let modelRewrite: String?
    let modelCompress: String?
    let modelRoute: String?
    let temperature: Double?
    let maxOutputTokens: Int?
    let configPath: String?
}

struct TokenSessionResponse: Decodable {
    let ok: Bool?
    let tokenSession: TokenSession?
}

struct TokenSession: Decodable {
    let id: String?
    let sessionId: String?
    let chunks: [String]?
    let mergedText: String?
    let updatedAt: String?
    let lastInputSource: String?
}

struct SendTargetResponse: Decodable {
    let ok: Bool?
    let target: String?
    let command: String?
    let output: String?
    let error: String?
    let sessionId: String?
}

struct ConnectTerminalResponse: Decodable {
    let ok: Bool?
    let target: String?
    let command: String?
    let output: String?
    let error: String?
}

struct VoiceInputResponse: Decodable {
    let ok: Bool?
    let message: String?
    let suggestedAction: String?
    let voiceInput: VoiceInputRecord?
    let tokenSession: TokenSession?
}

struct VoiceInputRecord: Decodable {
    let text: String?
    let source: String?
    let recordedAt: String?
}

struct LLMActionResponse: Decodable {
    let ok: Bool?
    let action: String?
    let output: String?
    let model: String?
    let provider: String?
    let baseURL: String?
    let error: String?
}

enum VoiceCaptureState: String {
    case idle
    case requestingPermission
    case recording
    case processing
    case failed
}

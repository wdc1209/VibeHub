import Foundation

enum VoiceRecognitionBackend: String, CaseIterable, Identifiable {
    case appleSpeech
    case senseVoiceONNX

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .appleSpeech:
            return "苹果默认语音"
        case .senseVoiceONNX:
            return "SenseVoice ONNX（本地模型）"
        }
    }
}

@MainActor
final class VoiceRecognitionSettingsStore: ObservableObject {
    static let shared = VoiceRecognitionSettingsStore()

    @Published private(set) var selectedBackendRaw: String

    private let defaults = UserDefaults.standard
    private let selectedBackendKey = "vibeHub.voiceRecognitionBackend"

    private init() {
        let stored = defaults.string(forKey: selectedBackendKey) ?? VoiceRecognitionBackend.appleSpeech.rawValue
        selectedBackendRaw = VoiceRecognitionBackend(rawValue: stored)?.rawValue ?? VoiceRecognitionBackend.appleSpeech.rawValue
    }

    var selectedBackend: VoiceRecognitionBackend {
        VoiceRecognitionBackend(rawValue: selectedBackendRaw) ?? .appleSpeech
    }

    func setSelectedBackend(rawValue: String) {
        let backend = VoiceRecognitionBackend(rawValue: rawValue) ?? .appleSpeech
        guard selectedBackendRaw != backend.rawValue else { return }
        selectedBackendRaw = backend.rawValue
        defaults.set(backend.rawValue, forKey: selectedBackendKey)
    }
}

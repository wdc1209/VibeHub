import Foundation

@MainActor
final class BridgeClient {
    static let shared = BridgeClient()

    private let baseURL = URL(string: "http://127.0.0.1:4765")!
    private let requestTimeout: TimeInterval = 30
    private let defaultSessionId = "current-webchat"
    private let bridgeScript = "/Users/nethon/.openclaw/workspace-main/vibe-hub/bridge/src/server.js"
    private let bridgeLogPath = "/tmp/vibe-hub-bridge.log"
    private var bridgeStartTask: Task<Void, Error>?

    private struct BridgeErrorResponse: Decodable {
        let ok: Bool?
        let error: String?
    }

    private func fetchData(path: String) async throws -> Data {
        try await ensureBridgeRunning()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = requestTimeout
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            return data
        } catch {
            if shouldRetryAfterBridgeRestart(error) {
                try await startBridgeProcess()
                let (data, response) = try await URLSession.shared.data(for: request)
                try validate(response: response, data: data)
                return data
            }
            throw error
        }
    }

    private func sendRequest(_ request: URLRequest) async throws -> Data {
        try await ensureBridgeRunning()
        var request = request
        request.timeoutInterval = requestTimeout
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            return data
        } catch {
            if shouldRetryAfterBridgeRestart(error) {
                try await startBridgeProcess()
                let (data, response) = try await URLSession.shared.data(for: request)
                try validate(response: response, data: data)
                return data
            }
            throw error
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(BridgeErrorResponse.self, from: data)
            let message = decoded?.error?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "VibeHubBridge",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message?.isEmpty == false ? message! : "bridge http \(http.statusCode)"]
            )
        }
    }

    private func shouldRetryAfterBridgeRestart(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        return false
    }

    private func ensureBridgeRunning() async throws {
        if await isBridgeReachable() {
            return
        }
        try await startBridgeProcess()
    }

    private func isBridgeReachable() async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("health"))
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func startBridgeProcess() async throws {
        if let existingTask = bridgeStartTask {
            try await existingTask.value
            return
        }

        let task = Task<Void, Error> {
            if await isBridgeReachable() {
                return
            }

            if try isBridgePortOccupied() {
                let occupiedDeadline = Date().addingTimeInterval(5)
                while Date() < occupiedDeadline {
                    if await isBridgeReachable() {
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }

                let bridgeLog = (try? String(contentsOfFile: bridgeLogPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
                let message = bridgeLog?.isEmpty == false
                    ? bridgeLog!
                    : "bridge 端口 4765 已被占用，但健康检查未通过。请关闭旧实例后重试。"
                throw NSError(domain: "VibeHubBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [
                "-lc",
                "nohup node \(bridgeScript) >\(bridgeLogPath) 2>&1 < /dev/null &"
            ]
            try process.run()
            process.waitUntilExit()

            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if await isBridgeReachable() {
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }

            let bridgeLog = (try? String(contentsOfFile: bridgeLogPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            if bridgeLog?.contains("EADDRINUSE") == true {
                let portDeadline = Date().addingTimeInterval(3)
                while Date() < portDeadline {
                    if await isBridgeReachable() {
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            let message = bridgeLog?.isEmpty == false ? bridgeLog! : "bridge 启动失败"
            throw NSError(domain: "VibeHubBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        bridgeStartTask = task
        defer { bridgeStartTask = nil }
        try await task.value
    }

    private func isBridgePortOccupied() throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-lc",
            "lsof -nP -iTCP:4765 -sTCP:LISTEN >/dev/null 2>&1"
        ]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func fetchStatus() async throws -> BridgeStatusResponse {
        let data = try await fetchData(path: "status")
        return try JSONDecoder().decode(BridgeStatusResponse.self, from: data)
    }

    func fetchTokenSession(sessionId: String? = nil) async throws -> TokenSessionResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("token-session"), resolvingAgainstBaseURL: false)!
        let resolvedSessionId = sessionId ?? defaultSessionId
        components.queryItems = [URLQueryItem(name: "sessionId", value: resolvedSessionId)]
        try await ensureBridgeRunning()
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = requestTimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(TokenSessionResponse.self, from: data)
    }

    func sendToTarget(text: String, target: String, windowTitle: String? = nil) async throws -> SendTargetResponse {
        guard let normalizedTarget = normalizedTargetId(for: target) else {
            throw NSError(
                domain: "VibeHubBridge",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "\(target) 目前还没有正式接入发送链路"]
            )
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("send"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "text": text,
            "source": "vibe-hub-mac",
            "target": normalizedTarget,
        ]
        if let windowTitle, !windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["windowTitle"] = windowTitle
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let data = try await sendRequest(request)
        return try JSONDecoder().decode(SendTargetResponse.self, from: data)
    }

    func submitVoiceInput(text: String, source: String = "press-to-talk") async throws -> VoiceInputResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("voice/input"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "sessionId": defaultSessionId,
            "text": text,
            "source": source,
        ])
        let data = try await sendRequest(request)
        return try JSONDecoder().decode(VoiceInputResponse.self, from: data)
    }

    func rewriteDraft(rawInput: String, draftText: String, target: String) async throws -> LLMActionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("llm/rewrite"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "rawInput": rawInput,
            "draftText": draftText,
            "target": target,
        ])
        let data = try await sendRequest(request)
        return try JSONDecoder().decode(LLMActionResponse.self, from: data)
    }

    func compressDraft(draftText: String, target: String) async throws -> LLMActionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("llm/compress"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "draftText": draftText,
            "target": target,
        ])
        let data = try await sendRequest(request)
        return try JSONDecoder().decode(LLMActionResponse.self, from: data)
    }

    func connectTerminal(action: String) async throws -> ConnectTerminalResponse {
        guard let url = URL(string: action, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let data = try await sendRequest(request)
        return try JSONDecoder().decode(ConnectTerminalResponse.self, from: data)
    }

    func selectTargetWindow(target: String, windowTitle: String?) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("target-window/select"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "target": normalizedTargetId(for: target) ?? target,
            "windowTitle": windowTitle ?? ""
        ])
        _ = try await sendRequest(request)
    }

    func clearTokenSession(sessionId: String?) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("token-session/clear"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "sessionId": sessionId ?? ""
        ])
        _ = try await sendRequest(request)
    }

    private func normalizedTargetId(for target: String) -> String? {
        let normalized = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "clipboard", "剪贴板":
            return "clipboard"
        case "webchat", "openclaw web chat", "openclaw-web-chat", "openclaw-webchat":
            return "webchat"
        case "google-chrome", "chrome":
            return "google-chrome"
        case "antigravity":
            return "antigravity"
        case "codex":
            return "codex"
        default:
            return nil
        }
    }
}

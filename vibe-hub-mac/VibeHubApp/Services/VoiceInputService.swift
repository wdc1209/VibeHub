import AVFoundation
import Speech

enum VoiceInputServiceError: LocalizedError {
    case recognizerUnavailable
    case microphoneDenied
    case speechRecognitionDenied
    case audioEngineStartFailed(String)
    case senseVoiceUnavailable
    case senseVoiceTranscriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "当前系统语音识别不可用"
        case .microphoneDenied:
            return "麦克风权限未开启"
        case .speechRecognitionDenied:
            return "语音识别权限未开启"
        case .audioEngineStartFailed(let message):
            return "录音启动失败：\(message)"
        case .senseVoiceUnavailable:
            return "SenseVoice ONNX 未就绪，请先在本地安装模型"
        case .senseVoiceTranscriptionFailed(let message):
            return "SenseVoice 转写失败：\(message)"
        }
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()

    func appendStdout(_ data: Data) {
        lock.lock()
        stdout.append(data)
        lock.unlock()
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderr.append(data)
        lock.unlock()
    }

    func snapshot(stdoutTail: Data = Data(), stderrTail: Data = Data()) -> (stdout: Data, stderr: Data) {
        lock.lock()
        stdout.append(stdoutTail)
        stderr.append(stderrTail)
        let snapshot = (stdout, stderr)
        lock.unlock()
        return snapshot
    }
}

final class VoiceInputService: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private let localModelRoot = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".vibe-hub", isDirectory: true)
    private lazy var senseVoicePython = localModelRoot
        .appendingPathComponent("sensevoice-py311/bin/python")
        .path
    private lazy var senseVoiceScript = localModelRoot
        .appendingPathComponent("sensevoice_transcribe.py")
        .path
    private lazy var senseVoiceModelDirectory = localModelRoot
        .appendingPathComponent("sensevoice-model", isDirectory: true)
        .path
    private let recognizer: SFSpeechRecognizer? = (
        SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans")) ??
        SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) ??
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    )

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript: String = ""
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?

    func startRecording(
        backend: VoiceRecognitionBackend,
        onPartialResult: @escaping @MainActor (String) -> Void
    ) async throws {
        stopAudioPipeline(resetTranscript: true)

        let microphoneGranted = await requestMicrophoneAccess()
        guard microphoneGranted else {
            throw VoiceInputServiceError.microphoneDenied
        }

        latestTranscript = ""

        if backend == .appleSpeech {
            guard let recognizer, recognizer.isAvailable else {
                throw VoiceInputServiceError.recognizerUnavailable
            }

            let speechGranted = await requestSpeechAuthorization()
            guard speechGranted else {
                throw VoiceInputServiceError.speechRecognitionDenied
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    self.latestTranscript = transcript
                    Task { @MainActor in
                        onPartialResult(transcript)
                    }

                    if result.isFinal {
                        self.stopAudioPipeline(resetTranscript: false)
                    }
                }

                if error != nil {
                    self.stopAudioPipeline(resetTranscript: false)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-hub-voice-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        self.recordingURL = recordingURL
        recordingFile = try AVAudioFile(forWriting: recordingURL, settings: format.settings)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.recordingFile?.write(from: buffer)
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopAudioPipeline(resetTranscript: true)
            throw VoiceInputServiceError.audioEngineStartFailed(error.localizedDescription)
        }
    }

    func stopRecording(backend: VoiceRecognitionBackend) async throws -> String {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        if backend == .appleSpeech {
            let deadline = Date().addingTimeInterval(1.2)
            while recognitionTask != nil && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
            let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            stopAudioPipeline(resetTranscript: false)
            return transcript
        }

        let transcript = try await transcribeWithSenseVoice()
        stopAudioPipeline(resetTranscript: false)
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancelRecording() {
        stopAudioPipeline(resetTranscript: true)
    }

    private func stopAudioPipeline(resetTranscript: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recordingFile = nil
        if let recordingURL, resetTranscript {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        if resetTranscript {
            latestTranscript = ""
        }
    }

    private func transcribeWithSenseVoice() async throws -> String {
        guard FileManager.default.isReadableFile(atPath: senseVoicePython),
              FileManager.default.isReadableFile(atPath: senseVoiceScript),
              FileManager.default.fileExists(atPath: senseVoiceModelDirectory)
        else {
            throw VoiceInputServiceError.senseVoiceUnavailable
        }
        guard let recordingURL else {
            throw VoiceInputServiceError.senseVoiceTranscriptionFailed("未找到录音文件")
        }

        let convertedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-hub-sensevoice-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        try await convertAudioForSenseVoice(inputURL: recordingURL, outputURL: convertedURL)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: senseVoicePython)
            process.arguments = [
                senseVoiceScript,
                "--audio", convertedURL.path,
                "--model-dir", senseVoiceModelDirectory,
                "--language", "auto",
            ]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = stdoutPipe
            let outputBuffer = ProcessOutputBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                outputBuffer.appendStdout(data)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                outputBuffer.appendStderr(data)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let snapshot = outputBuffer.snapshot(stdoutTail: remainingStdout, stderrTail: remainingStderr)
                let stdoutData = snapshot.stdout
                let stderrData = snapshot.stderr

                let stdout = String(data: stdoutData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                defer {
                    try? FileManager.default.removeItem(at: recordingURL)
                    try? FileManager.default.removeItem(at: convertedURL)
                }

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: VoiceInputServiceError.senseVoiceTranscriptionFailed(stderr.isEmpty ? "命令执行失败" : stderr))
                    return
                }

                let transcript = self.sanitizeSenseVoiceTranscript(stdout)
                guard !transcript.isEmpty else {
                    continuation.resume(throwing: VoiceInputServiceError.senseVoiceTranscriptionFailed("未生成转写文本"))
                    return
                }
                continuation.resume(returning: transcript)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: VoiceInputServiceError.senseVoiceTranscriptionFailed(error.localizedDescription))
            }
        }
    }

    private func convertAudioForSenseVoice(inputURL: URL, outputURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = [
                "-f", "WAVE",
                "-d", "LEI16@16000",
                "-c", "1",
                inputURL.path,
                outputURL.path,
            ]

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.terminationHandler = { process in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: VoiceInputServiceError.senseVoiceTranscriptionFailed(stderr.isEmpty ? "音频转换失败" : stderr))
                    return
                }
                continuation.resume()
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: VoiceInputServiceError.senseVoiceTranscriptionFailed(error.localizedDescription))
            }
        }
    }

    private func sanitizeSenseVoiceTranscript(_ raw: String) -> String {
        let pattern = #"<\|[^>]+?\|>"#
        let cleaned = raw.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
        default:
            return false
        }
    }
}

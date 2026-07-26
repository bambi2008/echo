import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledAudioTap = false

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil

        guard await requestPermissions() else { return }
        guard let recognizer = SFSpeechRecognizer(locale: recognitionLocale),
              recognizer.isAvailable
        else {
            errorMessage = "Speech recognition is currently unavailable. Please try again later."
            return
        }

        stop()
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                errorMessage = "No microphone input is available on this device."
                stop()
                return
            }

            inputNode.installTap(
                onBus: 0,
                bufferSize: 1_024,
                format: recordingFormat
            ) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            hasInstalledAudioTap = true
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.stop()
                        }
                    }
                    if let error {
                        if self.transcript.isEmpty {
                            self.errorMessage = self.friendlyMessage(for: error)
                        }
                        self.stop()
                    }
                }
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private var recognitionLocale: Locale {
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return .current
        }
        return Locale(identifier: preferredLanguage)
    }

    private func requestPermissions() async -> Bool {
        let speechStatus = await speechAuthorizationStatus()
        guard speechStatus == .authorized else {
            errorMessage = speechPermissionMessage(for: speechStatus)
            return false
        }

        let microphoneGranted = await microphonePermissionGranted()
        guard microphoneGranted else {
            errorMessage = "Microphone access is off. Enable it in Settings to dictate a memory."
            return false
        }
        return true
    }

    private func speechAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func microphonePermissionGranted() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func speechPermissionMessage(
        for status: SFSpeechRecognizerAuthorizationStatus
    ) -> String {
        switch status {
        case .denied, .restricted:
            return "Speech recognition access is off. Enable it in Settings to dictate a memory."
        case .notDetermined:
            return "Speech recognition permission was not completed. Please try again."
        case .authorized:
            return ""
        @unknown default:
            return "Speech recognition is unavailable on this device."
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
            return "I couldn't hear any speech. Tap the microphone and try again."
        }
        return "Voice input stopped unexpectedly. Your typed text is still here."
    }
}

enum VoiceTranscriptComposer {
    static func combine(existing: String, spoken: String) -> String {
        let existing = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty { return spoken }
        if spoken.isEmpty { return existing }
        return "\(existing) \(spoken)"
    }
}

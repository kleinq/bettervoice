//
//  AppState.swift
//  BetterVoice
//
//  Global app state and workflow orchestration
//  ObservableObject for SwiftUI bindings
//

import Foundation
import Combine
import AVFoundation

// MARK: - App Status

enum AppStatus: Equatable {
    case ready
    case recording
    case transcribing
    case enhancing
    case pasting
    case error(String)
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    @Published var status: AppStatus = .ready
    @Published var isRecording: Bool = false
    @Published var currentTranscription: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var transcriptionProgress: Float = 0.0

    // MARK: - Services

    private let hotkeyManager = HotkeyManager.shared
    private let audioCaptureService = AudioCaptureService()
    private let whisperService = WhisperService()
    private let pasteService = PasteService.shared
    private let appDetectionService = AppDetectionService.shared
    private let permissionsManager = PermissionsManager.shared
    private let learningService = LearningService.shared
    private let preferencesStore = PreferencesStore.shared
    private let soundPlayer = SoundPlayer.shared

    // Classification services
    private let featureExtractor = FeatureExtractor()
    private let dominantCharacteristicAnalyzer = DominantCharacteristicAnalyzer()
    private lazy var classificationLogger: ClassificationLogger? = {
        guard let dbQueue = try? DatabaseManager.shared.getQueue() else {
            Logger.shared.error("Failed to get database queue for classification logger")
            return nil
        }
        return ClassificationLogger(dbQueue: dbQueue)
    }()
    private lazy var textClassificationService: TextClassificationService? = {
        guard let logger = classificationLogger else {
            Logger.shared.error("Classification logger not available")
            return nil
        }
        return TextClassificationService(
            modelManager: .shared,
            featureExtractor: featureExtractor,
            analyzer: dominantCharacteristicAnalyzer,
            logger: logger
        )
    }()
    private lazy var textEnhancementService: TextEnhancementService = {
        TextEnhancementService(classificationService: textClassificationService)
    }()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    private var learningObservationTask: Task<Void, Never>?
    private var currentHotkeyKeyCode: UInt32?
    private var currentHotkeyModifiers: UInt32?
    private var currentModelSize: WhisperModelSize?
    private var isLoadingModel = false

    // MARK: - Singleton

    static let shared = AppState()

    private init() {
        setupHotkey()
        setupAudioLevelMonitoring()

        // Load model at startup
        Task {
            await loadSelectedModel()
        }
    }

    // MARK: - Setup

    private func setupHotkey() {
        let preferences = preferencesStore.preferences

        hotkeyManager.onKeyPress = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPress()
            }
        }

        hotkeyManager.onKeyRelease = { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyRelease()
            }
        }

        // Register hotkey
        do {
            try hotkeyManager.register(
                keyCode: preferences.hotkeyKeyCode,
                modifiers: preferences.hotkeyModifiers
            )
            currentHotkeyKeyCode = preferences.hotkeyKeyCode
            currentHotkeyModifiers = preferences.hotkeyModifiers
            Logger.shared.info("Hotkey registered successfully")
        } catch {
            Logger.shared.error("Failed to register hotkey", error: error)
            status = .error("Failed to register hotkey")
        }

        // Observe preference changes to update hotkey and model
        // Use $preferences publisher which fires AFTER the change
        preferencesStore.$preferences.sink { [weak self] newPrefs in
            guard let self = self else { return }

            Logger.shared.debug("Preferences changed: selectedModelSize=\(newPrefs.selectedModelSize.rawValue), currentModelSize=\(self.currentModelSize?.rawValue ?? "nil")")

            // Only update if hotkey actually changed
            if newPrefs.hotkeyKeyCode != self.currentHotkeyKeyCode ||
               newPrefs.hotkeyModifiers != self.currentHotkeyModifiers {
                Task { @MainActor in
                    self.updateHotkey(keyCode: newPrefs.hotkeyKeyCode, modifiers: newPrefs.hotkeyModifiers)
                }
            }

            // Only reload model if selection changed
            if newPrefs.selectedModelSize != self.currentModelSize {
                Logger.shared.info("Model selection changed from \(self.currentModelSize?.rawValue ?? "nil") to \(newPrefs.selectedModelSize.rawValue)")
                Task { @MainActor in
                    await self.loadSelectedModel()
                }
            }
        }.store(in: &cancellables)
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        Logger.shared.info("Updating hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")

        // Unregister old hotkey
        hotkeyManager.unregister()

        // Register new hotkey
        do {
            try hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
            currentHotkeyKeyCode = keyCode
            currentHotkeyModifiers = modifiers

            // Clear any previous error status
            if case .error = status {
                status = .ready
            }

            Logger.shared.info("Hotkey updated successfully")
        } catch {
            Logger.shared.error("Failed to update hotkey", error: error)
            status = .error("Failed to update hotkey")
        }
    }

    private func setupAudioLevelMonitoring() {
        audioCaptureService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Control Methods

    /// Stop learning observation manually
    func stopLearning() async {
        guard learningObservationTask != nil else { return }

        learningObservationTask?.cancel()
        learningObservationTask = nil
        await ClipboardMonitor.shared.stopMonitoring()

        Logger.shared.info("Learning observation stopped manually")
    }

    // MARK: - Workflow Orchestration

    private func handleHotkeyPress() async {
        Logger.shared.info("Hotkey pressed")

        // Check microphone permission
        let micStatus = permissionsManager.checkPermission(.microphone)
        guard micStatus == .granted else {
            // Request permission if not granted
            if micStatus == .notDetermined {
                let granted = await withCheckedContinuation { continuation in
                    permissionsManager.requestMicrophonePermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                if granted {
                    await startRecording()
                } else {
                    status = .error("Microphone permission denied")
                }
                return
            }
            status = .error("Microphone permission required. Please enable in System Settings.")
            return
        }

        // Check accessibility permission (for pasting)
        let accessibilityStatus = permissionsManager.checkPermission(.accessibility)
        if accessibilityStatus != .granted {
            // Request accessibility permission
            Logger.shared.info("Requesting accessibility permission...")
            let granted = await withCheckedContinuation { continuation in
                permissionsManager.requestPermission(.accessibility) { status in
                    continuation.resume(returning: status == .granted)
                }
            }
            if !granted {
                Logger.shared.warning("Accessibility permission denied - pasting will be limited")
            }
        }

        // Start recording
        await startRecording()
    }

    private func handleHotkeyRelease() async {
        Logger.shared.info("Hotkey released")

        guard isRecording else { return }

        // Stop recording and process
        await stopRecordingAndProcess()
    }

    private func startRecording() async {
        guard status == .ready else {
            Logger.shared.warning("Cannot start recording, current status: \(status)")
            return
        }

        // Cancel any ongoing learning observation from previous paste
        if let task = learningObservationTask {
            task.cancel()
            learningObservationTask = nil
            Logger.shared.info("Cancelled previous learning observation")
        }

        do {
            let preferences = preferencesStore.preferences
            try audioCaptureService.startCapture(deviceUID: preferences.selectedAudioInputDeviceUID)

            status = .recording
            isRecording = true
            recordingStartTime = Date()

            // Play start sound
            soundPlayer.playEvent(.recordingStart, preferences: preferences)

            Logger.shared.info("Recording started")
        } catch {
            Logger.shared.error("Failed to start recording", error: error)
            status = .error("Failed to start recording")
            soundPlayer.playEvent(.error, preferences: preferencesStore.preferences)
        }
    }

    private func stopRecordingAndProcess() async {
        guard isRecording else { return }

        do {
            // Stop audio capture
            let audioData = try audioCaptureService.stopCapture()
            isRecording = false

            // Play stop sound
            let preferences = preferencesStore.preferences
            soundPlayer.playEvent(.recordingStop, preferences: preferences)

            let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
            Logger.shared.info("Recorded \(recordingDuration)s of audio, \(audioData.count) bytes")

            // Check for minimum audio data (0.5s of PCM16 @ 16kHz = 16000 bytes)
            guard audioData.count >= 16000 else {
                Logger.shared.info("Recording too short (\(String(format: "%.1f", recordingDuration))s), ignoring")
                status = .ready
                return
            }

            // Transcribe
            status = .transcribing
            let transcriptionResult = try await transcribe(audioData: audioData)

            // Check if transcription result is empty or just whitespace
            guard !transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Logger.shared.info("No speech detected in recording")
                status = .ready
                return
            }

            // Enhance
            status = .enhancing
            let enhancedText = try await enhance(text: transcriptionResult.text)

            // Paste
            status = .pasting
            try await paste(text: enhancedText)

            // Play completion sound
            soundPlayer.playEvent(.paste, preferences: preferences)

            // Learn from edits (run in background, don't block)
            if preferences.learningSystemEnabled {
                let context = appDetectionService.detectContext()
                let timeout = ClipboardMonitor.calculateTimeout(for: enhancedText)

                learningObservationTask = Task { [weak self] in
                    await self?.learningService.observe(
                        originalText: enhancedText,
                        documentType: context.documentType,
                        timeoutSeconds: Int(timeout)
                    )
                    self?.learningObservationTask = nil
                }

                Logger.shared.info("Learning observation started: \(Int(timeout))s timeout for \(enhancedText.count) chars")
            }

            // Reset to ready (don't wait for learning observation)
            status = .ready
            currentTranscription = enhancedText

            Logger.shared.info("Workflow completed successfully")

        } catch {
            Logger.shared.error("Workflow failed", error: error)
            status = .error(error.localizedDescription)
            isRecording = false

            // Play error sound
            let preferences = preferencesStore.preferences
            soundPlayer.playEvent(.error, preferences: preferences)

            // Reset to ready after error
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.status = .ready
            }
        }
    }

    private func transcribe(audioData: Data) async throws -> TranscriptionResult {
        Logger.shared.info("Starting transcription")

        // Wait for model to be ready (either still loading or needs to load)
        if !whisperService.isModelLoaded || isLoadingModel {
            if isLoadingModel {
                Logger.shared.info("Model currently loading, waiting...")
                // Wait for loading to complete
                while isLoadingModel {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                Logger.shared.info("Model loading completed, proceeding with transcription")
            } else {
                await loadSelectedModel()
            }
        }

        let result = try await whisperService.transcribe(audioData: audioData)

        Logger.shared.info("Transcription completed: \(result.text.prefix(50))...")

        return result
    }

    private func loadSelectedModel() async {
        // Prevent concurrent model loading
        guard !isLoadingModel else {
            Logger.shared.info("Model already loading, skipping concurrent load request")
            return
        }

        let preferences = preferencesStore.preferences
        let selectedSize = preferences.selectedModelSize

        Logger.shared.info("loadSelectedModel called: selectedSize=\(selectedSize.rawValue), currentModelSize=\(currentModelSize?.rawValue ?? "nil")")

        // Check if model file exists
        guard ModelStorage.shared.isModelDownloaded(selectedSize) else {
            Logger.shared.warning("Selected model \(selectedSize.rawValue) not downloaded, will prompt user")
            return
        }

        isLoadingModel = true
        defer { isLoadingModel = false }

        do {
            Logger.shared.info("Loading selected model: \(selectedSize.rawValue)...")
            let modelInfo = ModelStorage.shared.getModelInfo(selectedSize)
            try await whisperService.loadModel(modelInfo)
            currentModelSize = selectedSize
            Logger.shared.info("Successfully loaded model: \(selectedSize.rawValue)")
        } catch {
            Logger.shared.error("Failed to load model \(selectedSize.rawValue)", error: error)
        }
    }

    private func enhance(text: String) async throws -> String {
        Logger.shared.info("Starting enhancement")

        // Detect document context
        let context = appDetectionService.detectContext()
        Logger.shared.info("📄 Document Type: \(context.documentType.displayName) (confidence: \(String(format: "%.0f%%", context.confidence * 100)))")
        if let appName = context.appName {
            Logger.shared.debug("Detected app: \(appName)")
        }
        if let url = context.url {
            Logger.shared.debug("Detected URL: \(url)")
        }

        // Get preferences
        let preferences = preferencesStore.preferences

        // Enhance text
        let enhancedResult = try await textEnhancementService.enhance(
            text: text,
            documentType: context.documentType,
            applyLearning: preferences.learningSystemEnabled,
            useCloud: preferences.externalLLMEnabled
        )

        Logger.shared.info("Enhancement completed, applied \(enhancedResult.appliedRules.count) rules")
        Logger.shared.info("Enhanced text (\(enhancedResult.enhancedText.count) chars): \"\(enhancedResult.enhancedText)\"")

        return enhancedResult.enhancedText
    }

    private func paste(text: String) async throws {
        Logger.shared.info("Pasting text")

        try await pasteService.paste(text: text)

        Logger.shared.info("Paste completed")
    }

    // MARK: - Manual Controls

    func startManualRecording() async {
        await handleHotkeyPress()
    }

    func stopManualRecording() async {
        await handleHotkeyRelease()
    }

    // MARK: - Model Management

    func loadModel(_ model: WhisperModel) async throws {
        status = .transcribing // Show loading state
        try await whisperService.loadModel(model)
        status = .ready
        Logger.shared.info("Model loaded: \(model.size)")
    }

    // MARK: - Cleanup

    func cleanup() {
        hotkeyManager.unregister()
        if isRecording {
            _ = try? audioCaptureService.stopCapture()
        }
    }
}

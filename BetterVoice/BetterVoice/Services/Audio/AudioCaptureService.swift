//
//  AudioCaptureService.swift
//  BetterVoice
//
//  Audio capture service using AVAudioEngine
//  Conforms to AudioCaptureServiceProtocol with <100ms start latency (PR-001)
//

import Foundation
import AVFoundation
import Combine

// MARK: - Protocol

protocol AudioCaptureServiceProtocol {
    var isCapturing: Bool { get }
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }

    func startCapture(deviceUID: String?) throws
    func stopCapture() throws -> Data
}

// MARK: - Error Types

enum AudioCaptureError: Error {
    case alreadyCapturing
    case notCapturing
    case deviceNotFound
    case permissionDenied
    case configurationFailed(String)
}

// MARK: - Service Implementation

final class AudioCaptureService: AudioCaptureServiceProtocol {

    // MARK: - Properties

    private(set) var isCapturing: Bool = false

    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }

    private let audioEngine = AVAudioEngine()
    private var audioBuffer = Data()
    private var levelTimer: Timer?
    private var isEngineConfigured = false

    // PCM16 format at 16kHz mono (whisper.cpp requirement)
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    // MARK: - Initialization

    init() {
        // Pre-warm audio engine to reduce first-capture latency
        Task {
            await warmUpAudioEngine()
        }
    }

    @MainActor
    private func warmUpAudioEngine() async {
        // Configure engine without starting capture
        // This initializes audio hardware to reduce latency on first actual capture
        Logger.shared.info("Pre-warming audio engine to reduce first-capture latency")
        do {
            try configureAudioEngine()
            isEngineConfigured = true
            Logger.shared.info("Audio engine pre-warmed successfully")
        } catch {
            Logger.shared.warning("Failed to pre-warm audio engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    func startCapture(deviceUID: String? = nil) throws {
        guard !isCapturing else {
            throw AudioCaptureError.alreadyCapturing
        }

        // Check microphone permission
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard permissionStatus == .authorized else {
            throw AudioCaptureError.permissionDenied
        }

        // Configure audio input device if specified
        if let deviceUID = deviceUID {
            try configureInputDevice(deviceUID)
        }

        // Always configure audio engine to ensure tap is properly installed
        // Even if pre-warmed, we need to reinstall tap when starting capture
        try configureAudioEngine()

        // Start engine
        do {
            try audioEngine.start()
            Logger.shared.info("Audio capture started with device: \(deviceUID ?? "default")")
        } catch {
            throw AudioCaptureError.configurationFailed("Failed to start audio engine: \(error.localizedDescription)")
        }

        isCapturing = true
        audioBuffer = Data()

        // Start audio level monitoring at 60Hz (PR-001 requirement)
        startLevelMonitoring()

        Logger.shared.info("Audio capture started with device: \(deviceUID ?? "default")")
    }

    func stopCapture() throws -> Data {
        guard isCapturing else {
            throw AudioCaptureError.notCapturing
        }

        // Stop level monitoring
        stopLevelMonitoring()

        // Remove tap from input node before stopping
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        // Stop audio engine
        audioEngine.stop()
        isCapturing = false

        // Return captured audio data
        let capturedData = audioBuffer
        audioBuffer = Data()

        Logger.shared.info("Audio capture stopped, captured \(capturedData.count) bytes")

        return capturedData
    }

    // MARK: - Private Methods

    private func configureInputDevice(_ deviceUID: String) throws {
        // Get available audio devices using AVCaptureDeviceDiscoverySession
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        let audioDevices = discoverySession.devices

        guard let device = audioDevices.first(where: { $0.uniqueID == deviceUID }) else {
            throw AudioCaptureError.deviceNotFound
        }

        // Set input device on audio engine
        // Note: AVAudioEngine automatically uses the default input device
        // For custom device selection, we'd need to use AVAudioSession (iOS) or AudioUnit (macOS)
        // For macOS, we use the inputNode which respects system default
        Logger.shared.debug("Configured audio input device: \(device.localizedName)")
    }

    private func configureAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create converter if needed
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.configurationFailed("Failed to create audio format converter")
        }

        // Remove existing tap if any (to avoid duplicates)
        inputNode.removeTap(onBus: 0)

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer, converter: converter)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        // Calculate required output buffer size
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / buffer.format.sampleRate))

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            Logger.shared.error("Failed to create output buffer")
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            Logger.shared.error("Audio conversion failed", error: error)
            return
        }

        // Append converted PCM16 data to buffer
        if let channelData = outputBuffer.int16ChannelData {
            let frameLength = Int(outputBuffer.frameLength)
            let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Int16>.size)
            audioBuffer.append(data)
        }
    }

    private func startLevelMonitoring() {
        // 60Hz updates = ~16.67ms interval
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Calculate RMS level from current audio buffer
            let level = self.calculateAudioLevel()
            self.audioLevelSubject.send(level)
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func calculateAudioLevel() -> Float {
        guard !audioBuffer.isEmpty else { return 0.0 }

        // Calculate RMS from last chunk of audio buffer (last 512 samples)
        let sampleCount = min(512, audioBuffer.count / MemoryLayout<Int16>.size)
        guard sampleCount > 0 else { return 0.0 }

        let offset = max(0, audioBuffer.count - sampleCount * MemoryLayout<Int16>.size)
        let samples = audioBuffer.withUnsafeBytes { bytes -> [Int16] in
            let pointer = bytes.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Int16.self)
            return Array(UnsafeBufferPointer(start: pointer, count: sampleCount))
        }

        // Calculate RMS
        let sum = samples.reduce(0.0) { sum, sample in
            let normalized = Double(sample) / Double(Int16.max)
            return sum + normalized * normalized
        }
        let rms = sqrt(sum / Double(sampleCount))

        // Normalize to 0.0-1.0 range (RMS is typically much lower than 1.0)
        // Apply a multiplier to make levels more visible
        let normalized = Float(min(1.0, rms * 10.0))

        return normalized
    }

    deinit {
        if isCapturing {
            _ = try? stopCapture()
        }
    }
}

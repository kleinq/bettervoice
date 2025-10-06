//
//  AudioProcessingService.swift
//  BetterVoice
//
//  Audio processing utilities for format conversion, waveform generation, and file I/O
//

import Foundation
import AVFoundation
import Accelerate

final class AudioProcessingService {

    // MARK: - Singleton

    static let shared = AudioProcessingService()
    private init() {}

    // MARK: - Format Conversion

    /// Convert audio data from one format to another
    /// - Parameters:
    ///   - data: Input audio data
    ///   - fromFormat: Source audio format
    ///   - toFormat: Target audio format
    /// - Returns: Converted audio data
    func convert(
        _ data: Data,
        from fromFormat: AVAudioFormat,
        to toFormat: AVAudioFormat
    ) throws -> Data {
        // Create source buffer
        let frameCount = AVAudioFrameCount(data.count / Int(fromFormat.streamDescription.pointee.mBytesPerFrame))
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: fromFormat, frameCapacity: frameCount) else {
            throw AudioProcessingError.bufferCreationFailed
        }

        sourceBuffer.frameLength = frameCount
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            memcpy(sourceBuffer.audioBufferList.pointee.mBuffers.mData, baseAddress, data.count)
        }

        // Create converter
        guard let converter = AVAudioConverter(from: fromFormat, to: toFormat) else {
            throw AudioProcessingError.conversionFailed("Failed to create audio converter")
        }

        // Calculate output buffer size
        let outputCapacity = AVAudioFrameCount(Double(frameCount) * (toFormat.sampleRate / fromFormat.sampleRate))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: toFormat, frameCapacity: outputCapacity) else {
            throw AudioProcessingError.bufferCreationFailed
        }

        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw AudioProcessingError.conversionFailed(error.localizedDescription)
        }

        // Extract data from output buffer
        return extractData(from: outputBuffer)
    }

    // MARK: - Waveform Generation

    /// Generate waveform data for visualization
    /// - Parameters:
    ///   - audioData: PCM16 audio data
    ///   - sampleCount: Number of waveform samples to generate
    /// - Returns: Array of normalized waveform values (0.0-1.0)
    func generateWaveform(from audioData: Data, sampleCount: Int = 100) -> [Float] {
        guard !audioData.isEmpty else { return [] }

        let samples = audioData.withUnsafeBytes { bytes -> [Int16] in
            let pointer = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
            let count = audioData.count / MemoryLayout<Int16>.size
            return Array(UnsafeBufferPointer(start: pointer, count: count))
        }

        let samplesPerBucket = max(1, samples.count / sampleCount)
        var waveform: [Float] = []

        for i in 0..<sampleCount {
            let start = i * samplesPerBucket
            let end = min(start + samplesPerBucket, samples.count)

            guard start < end else { break }

            let bucketSamples = Array(samples[start..<end])
            let rms = calculateRMS(bucketSamples)
            waveform.append(rms)
        }

        return normalizeWaveform(waveform)
    }

    // MARK: - Audio File I/O

    /// Save audio data to temporary file
    /// - Parameters:
    ///   - data: Audio data (PCM16 format)
    ///   - filename: Optional filename (generates UUID if nil)
    /// - Returns: URL of saved file
    func saveToTemporaryFile(_ data: Data, filename: String? = nil) throws -> URL {
        let fileName = filename ?? "\(UUID().uuidString).wav"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Create WAV file with header
        let wavData = try createWAVFile(pcm16Data: data)
        try wavData.write(to: fileURL)

        Logger.shared.debug("Saved audio to temporary file: \(fileURL.path)")
        return fileURL
    }

    /// Load audio data from file
    /// - Parameter url: File URL
    /// - Returns: Audio data in PCM16 format
    func loadFromFile(_ url: URL) throws -> Data {
        let fileData = try Data(contentsOf: url)

        // Strip WAV header if present (44 bytes)
        if fileData.count > 44 {
            let header = fileData.prefix(4)
            if String(data: header, encoding: .ascii) == "RIFF" {
                return fileData.dropFirst(44)
            }
        }

        return fileData
    }

    /// Delete temporary audio file
    /// - Parameter url: File URL to delete
    func deleteTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        Logger.shared.debug("Deleted temporary file: \(url.path)")
    }

    // MARK: - Private Helpers

    private func extractData(from buffer: AVAudioPCMBuffer) -> Data {
        let frameLength = Int(buffer.frameLength)
        let bytesPerFrame = buffer.format.streamDescription.pointee.mBytesPerFrame
        let dataSize = frameLength * Int(bytesPerFrame)

        var data = Data(count: dataSize)

        data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            memcpy(baseAddress, buffer.audioBufferList.pointee.mBuffers.mData, dataSize)
        }

        return data
    }

    private func calculateRMS(_ samples: [Int16]) -> Float {
        guard !samples.isEmpty else { return 0.0 }

        let sum = samples.reduce(0.0) { sum, sample in
            let normalized = Double(sample) / Double(Int16.max)
            return sum + normalized * normalized
        }

        return Float(sqrt(sum / Double(samples.count)))
    }

    private func normalizeWaveform(_ waveform: [Float]) -> [Float] {
        guard !waveform.isEmpty else { return [] }

        let maxValue = waveform.max() ?? 1.0
        guard maxValue > 0 else { return waveform }

        return waveform.map { $0 / maxValue }
    }

    private func createWAVFile(pcm16Data: Data) throws -> Data {
        var wavData = Data()

        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)

        // File size (will update later)
        let fileSize = UInt32(36 + pcm16Data.count)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })

        // WAVE header
        wavData.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)

        // fmt chunk size (16 for PCM)
        let fmtSize = UInt32(16)
        wavData.append(contentsOf: withUnsafeBytes(of: fmtSize.littleEndian) { Array($0) })

        // Audio format (1 = PCM)
        let audioFormat = UInt16(1)
        wavData.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })

        // Number of channels (1 = mono)
        let numChannels = UInt16(1)
        wavData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })

        // Sample rate (16000 Hz)
        let sampleRate = UInt32(16000)
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })

        // Byte rate (sampleRate * numChannels * bitsPerSample/8)
        let byteRate = UInt32(16000 * 1 * 2) // 32000 bytes/sec
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })

        // Block align (numChannels * bitsPerSample/8)
        let blockAlign = UInt16(2)
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })

        // Bits per sample (16)
        let bitsPerSample = UInt16(16)
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        wavData.append("data".data(using: .ascii)!)

        // data chunk size
        let dataSize = UInt32(pcm16Data.count)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Append PCM data
        wavData.append(pcm16Data)

        return wavData
    }
}

// MARK: - Error Types

enum AudioProcessingError: Error {
    case bufferCreationFailed
    case conversionFailed(String)
    case fileWriteFailed
    case fileReadFailed
}

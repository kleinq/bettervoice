//
//  NativeMessagingHost.swift
//  BetterVoice
//
//  Native messaging host for Chrome extension communication
//  Receives edit detection messages from web browsers
//

import Foundation

// MARK: - Native Message

struct NativeMessage: Codable {
    let type: String
    let original: String?
    let edited: String?
    let url: String?
    let text: String?
}

// MARK: - Native Messaging Host

final class NativeMessagingHost {

    // MARK: - Singleton

    static let shared = NativeMessagingHost()
    private init() {}

    // MARK: - Properties

    private var inputSource: DispatchSourceRead?
    private var isRunning = false

    // Callback for edit detection
    var onEditDetected: ((String, String, String) -> Void)?

    // Callback for monitoring start request
    var onStartMonitoring: ((String) -> Void)?

    // MARK: - Public Methods

    /// Start listening for messages from Chrome extension
    func startListening() {
        guard !isRunning else {
            Logger.shared.debug("Native messaging host already running")
            return
        }

        // Set up stdin as a dispatch source
        let stdinHandle = FileHandle.standardInput
        inputSource = DispatchSource.makeReadSource(
            fileDescriptor: stdinHandle.fileDescriptor,
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        inputSource?.setEventHandler { [weak self] in
            self?.readMessage()
        }

        inputSource?.resume()
        isRunning = true

        Logger.shared.info("🔌 Native messaging host started")
    }

    /// Stop listening
    func stopListening() {
        inputSource?.cancel()
        inputSource = nil
        isRunning = false

        Logger.shared.info("🔌 Native messaging host stopped")
    }

    /// Send message to Chrome extension
    func sendMessage(_ message: NativeMessage) {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(message)

            // Native messaging protocol: 4-byte length header + JSON
            var length = UInt32(jsonData.count).littleEndian
            let lengthData = Data(bytes: &length, count: 4)

            // Write to stdout
            FileHandle.standardOutput.write(lengthData)
            FileHandle.standardOutput.write(jsonData)

            Logger.shared.debug("📤 Sent message to extension: \(message.type)")
        } catch {
            Logger.shared.error("Failed to send native message", error: error)
        }
    }

    // MARK: - Private Methods

    private func readMessage() {
        // Read 4-byte length header
        let lengthData = FileHandle.standardInput.readData(ofLength: 4)
        guard lengthData.count == 4 else {
            Logger.shared.error("Invalid message length header")
            return
        }

        // Parse length
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }

        // Read JSON message
        let jsonData = FileHandle.standardInput.readData(ofLength: Int(length))
        guard jsonData.count == Int(length) else {
            Logger.shared.error("Incomplete message received")
            return
        }

        // Decode message
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(NativeMessage.self, from: jsonData)

            Logger.shared.debug("📥 Received message from extension: \(message.type)")

            // Handle message
            handleMessage(message)

        } catch {
            Logger.shared.error("Failed to decode native message", error: error)
        }
    }

    private func handleMessage(_ message: NativeMessage) {
        switch message.type {
        case "EDIT_DETECTED":
            guard let original = message.original,
                  let edited = message.edited,
                  let url = message.url else {
                Logger.shared.error("Invalid EDIT_DETECTED message - missing fields")
                return
            }

            Logger.shared.info("✅ Edit detected from web app: \(url)")
            onEditDetected?(original, edited, url)

        case "CONTENT_SCRIPT_READY":
            Logger.shared.debug("Content script ready in browser")

        default:
            Logger.shared.warning("Unknown message type: \(message.type)")
        }
    }
}

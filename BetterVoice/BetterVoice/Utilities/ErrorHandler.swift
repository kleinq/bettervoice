//
//  ErrorHandler.swift
//  BetterVoice
//
//  Central error handling and user-facing error messages
//  SR-007, UR-003: Localized, actionable error descriptions
//

import Foundation

// MARK: - Error Types

enum BetterVoiceError: Error {
    // Audio errors
    case microphonePermissionDenied
    case microphoneUnavailable
    case audioCaptureFailed(String)
    case audioFormatInvalid

    // Transcription errors
    case modelNotLoaded
    case modelDownloadFailed(String)
    case transcriptionFailed(String)
    case transcriptionCancelled

    // Enhancement errors
    case enhancementFailed(String)
    case documentTypeDetectionFailed

    // Cloud API errors
    case apiKeyMissing(String)
    case apiRequestFailed(String)
    case apiTimeout
    case apiRateLimited

    // Learning errors
    case databaseError(String)
    case patternStorageFailed

    // System errors
    case hotkeyRegistrationFailed
    case pasteFailed
    case permissionRequired(String)
    case fileIOError(String)

    // General errors
    case invalidConfiguration(String)
    case unknown(Error)
}

// MARK: - Error Handler

final class ErrorHandler {
    static let shared = ErrorHandler()

    private init() {}

    // MARK: - User-Facing Messages

    func getUserMessage(for error: Error) -> String {
        if let betterVoiceError = error as? BetterVoiceError {
            return getUserMessage(for: betterVoiceError)
        }

        // Handle other error types
        return "An unexpected error occurred: \(error.localizedDescription)"
    }

    func getUserMessage(for error: BetterVoiceError) -> String {
        switch error {
        // Audio
        case .microphonePermissionDenied:
            return "Microphone access is required for voice recording. Please grant permission in System Settings → Privacy & Security → Microphone."

        case .microphoneUnavailable:
            return "No microphone found. Please connect a microphone and try again."

        case .audioCaptureFailed(let reason):
            return "Audio recording failed: \(reason). Please check your microphone settings."

        case .audioFormatInvalid:
            return "The audio format is not supported. BetterVoice requires 16kHz PCM16 mono audio."

        // Transcription
        case .modelNotLoaded:
            return "The transcription model is not loaded. Please select a model in Settings."

        case .modelDownloadFailed(let reason):
            return "Failed to download the Whisper model: \(reason). Please check your internet connection and try again."

        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason). Please try recording again."

        case .transcriptionCancelled:
            return "Transcription was cancelled."

        // Enhancement
        case .enhancementFailed(let reason):
            return "Text enhancement failed: \(reason). The original transcription will be used."

        case .documentTypeDetectionFailed:
            return "Could not detect the document type. Generic formatting will be applied."

        // Cloud API
        case .apiKeyMissing(let provider):
            return "API key for \(provider) is not configured. Please add your API key in Settings → External LLM."

        case .apiRequestFailed(let reason):
            return "External LLM request failed: \(reason). Using local enhancement instead."

        case .apiTimeout:
            return "External LLM request timed out. Using local enhancement instead."

        case .apiRateLimited:
            return "API rate limit exceeded. Please try again later or use local enhancement."

        // Learning
        case .databaseError(let reason):
            return "Database error: \(reason). Learning patterns may not be saved."

        case .patternStorageFailed:
            return "Failed to save learning pattern. Your edits will not be remembered."

        // System
        case .hotkeyRegistrationFailed:
            return "Failed to register the hotkey. Please choose a different key combination in Settings."

        case .pasteFailed:
            return "Failed to paste the transcribed text. Please paste manually from the clipboard."

        case .permissionRequired(let permission):
            return "\(permission) permission is required. Please grant access in System Settings → Privacy & Security."

        case .fileIOError(let reason):
            return "File operation failed: \(reason)."

        // General
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail). Please check your settings."

        case .unknown(let underlyingError):
            return "An unexpected error occurred: \(underlyingError.localizedDescription)"
        }
    }

    // MARK: - Recovery Suggestions

    func getRecoverySuggestion(for error: BetterVoiceError) -> String? {
        switch error {
        case .microphonePermissionDenied:
            return "Go to System Settings → Privacy & Security → Microphone and enable BetterVoice."

        case .microphoneUnavailable:
            return "Check that a microphone is connected and selected in Settings → Recording."

        case .modelNotLoaded, .modelDownloadFailed:
            return "Go to Settings → Transcription and download a Whisper model."

        case .apiKeyMissing:
            return "Add your API key in Settings → External LLM."

        case .hotkeyRegistrationFailed:
            return "Choose a different hotkey in Settings → Recording."

        case .permissionRequired:
            return "Grant the required permission in System Settings."

        default:
            return nil
        }
    }

    // MARK: - Logging

    func handle(_ error: Error, context: String? = nil) {
        let message = context != nil ? "\(context!): \(getUserMessage(for: error))" : getUserMessage(for: error)

        if let betterVoiceError = error as? BetterVoiceError {
            // Log to Logger
            Logger.shared.error(message, error: error)

            // Report critical errors
            if isCritical(betterVoiceError) {
                Logger.shared.error("CRITICAL ERROR: \(message)")
            }
        } else {
            Logger.shared.error(message, error: error)
        }
    }

    private func isCritical(_ error: BetterVoiceError) -> Bool {
        switch error {
        case .microphonePermissionDenied,
             .databaseError,
             .invalidConfiguration:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Extension

extension BetterVoiceError: LocalizedError {
    var errorDescription: String? {
        return ErrorHandler.shared.getUserMessage(for: self)
    }

    var recoverySuggestion: String? {
        return ErrorHandler.shared.getRecoverySuggestion(for: self)
    }
}

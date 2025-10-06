//
//  ClassificationError.swift
//  BetterVoice
//
//  Error types for text classification
//

import Foundation

enum ClassificationError: Error {
    case emptyText
    case modelNotLoaded
    case inferenceFailure(underlying: Error)
}

extension ClassificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Cannot classify empty or whitespace-only text"
        case .modelNotLoaded:
            return "Classification model failed to load"
        case .inferenceFailure(let error):
            return "Classification inference failed: \(error.localizedDescription)"
        }
    }
}

//
//  EnhancedText.swift
//  BetterVoice
//
//  Model representing enhanced transcription with improvement metrics
//  Tracks local and cloud enhancement results
//

import Foundation

struct EnhancedText: Codable, Identifiable {
    let id: UUID
    let originalText: String
    let enhancedText: String
    let documentType: DocumentType
    let appliedRules: [String]
    let learnedPatternsApplied: Int
    let cloudEnhanced: Bool
    let cloudProvider: String?
    let timestamp: Date

    // Default initializer
    init(
        id: UUID = UUID(),
        originalText: String,
        enhancedText: String,
        documentType: DocumentType,
        appliedRules: [String] = [],
        learnedPatternsApplied: Int = 0,
        cloudEnhanced: Bool = false,
        cloudProvider: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.enhancedText = enhancedText
        self.documentType = documentType
        self.appliedRules = appliedRules
        self.learnedPatternsApplied = learnedPatternsApplied
        self.cloudEnhanced = cloudEnhanced
        self.cloudProvider = cloudProvider
        self.timestamp = timestamp
    }

    // Computed property for improvement ratio
    var improvementRatio: Double {
        guard !originalText.isEmpty else { return 0.0 }
        let originalLength = Double(originalText.count)
        let enhancedLength = Double(enhancedText.count)
        let lengthChange = abs(enhancedLength - originalLength) / originalLength
        return lengthChange
    }
}

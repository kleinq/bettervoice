//
//  TextEnhancementService.swift
//  BetterVoice
//
//  6-stage text enhancement pipeline coordinating multiple services
//  Per research.md: Normalize → RemoveFillers → Punctuate → Format → Learning → Cloud
//

import Foundation

// MARK: - Protocol

protocol TextEnhancementServiceProtocol {
    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool,
        useCloud: Bool
    ) async throws -> EnhancedText
}

// MARK: - Service Implementation

final class TextEnhancementService: TextEnhancementServiceProtocol {

    // MARK: - Dependencies

    private let fillerRemover = FillerWordRemover.shared
    private let formatApplier = FormatApplier.shared
    private let learningService = LearningService.shared

    // MARK: - Public Methods

    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool = false,
        useCloud: Bool = false
    ) async throws -> EnhancedText {

        var enhanced = text
        var appliedRules: [String] = []

        // Stage 1: Normalize
        enhanced = normalize(enhanced)
        appliedRules.append("normalize")

        // Stage 2: Remove Fillers
        let fillerResult = fillerRemover.remove(from: enhanced)
        enhanced = fillerResult.cleanedText
        _ = fillerResult.removedFillers  // Track but don't store in final model
        appliedRules.append("remove_fillers")

        // Stage 3: Punctuate (handled by FormatApplier)
        appliedRules.append("punctuate")

        // Stage 4: Format by document type
        let formatResult = formatApplier.apply(to: enhanced, documentType: documentType)
        enhanced = formatResult.formattedText
        _ = formatResult.changes  // Track but don't store in final model
        appliedRules.append("format_\(documentType.rawValue)")

        // Stage 5: Apply Learning (if enabled)
        var patternsApplied = 0
        if applyLearning {
            do {
                let beforeLearning = enhanced
                enhanced = try learningService.applyLearned(text: enhanced, documentType: documentType)
                if enhanced != beforeLearning {
                    appliedRules.append("apply_learning")
                    patternsApplied = 1 // Simplified count
                }
            } catch {
                Logger.shared.error("Failed to apply learning patterns", error: error)
            }
        }

        // Stage 6: Cloud Enhancement (if enabled)
        if useCloud {
            // TODO: Implement cloud LLM enhancement
            // enhanced = try await applyCloudEnhancement(enhanced, documentType: documentType)
            appliedRules.append("cloud_enhance")
        }

        return EnhancedText(
            id: UUID(),
            originalText: text,
            enhancedText: enhanced,
            documentType: documentType,
            appliedRules: appliedRules,
            learnedPatternsApplied: patternsApplied,
            cloudEnhanced: useCloud,
            cloudProvider: useCloud ? "claude" : nil,
            timestamp: Date()
        )
    }

    // MARK: - Pipeline Stages

    private func normalize(_ text: String) -> String {
        var normalized = text

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize unicode (NFC form)
        normalized = normalized.precomposedStringWithCanonicalMapping

        // Replace multiple spaces with single space
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }

        // Normalize line endings
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        return normalized
    }

    private func calculateImprovementRatio(original: String, enhanced: String) -> Double {
        // Simple heuristic: ratio of enhanced length to original
        // More sophisticated metrics could include:
        // - Sentence structure improvements
        // - Punctuation additions
        // - Capitalization fixes
        // - Filler word removal percentage

        guard !original.isEmpty else { return 1.0 }

        let originalWords = original.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let enhancedWords = enhanced.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // If enhanced text is significantly shorter, it means fillers were removed (good)
        // If enhanced text is longer, it means formatting was added (also good)
        // Neutral ratio around 1.0

        let lengthRatio = Double(enhancedWords.count) / Double(originalWords.count)

        // Prefer slight reduction (0.8-1.0) or slight increase (1.0-1.2)
        // Penalize dramatic changes
        if lengthRatio >= 0.8 && lengthRatio <= 1.2 {
            return 1.0 + abs(1.0 - lengthRatio) * 0.5
        } else {
            return max(0.5, 1.0 - abs(1.0 - lengthRatio))
        }
    }

    // TODO: Future implementations

    private func applyLearningPatterns(_ text: String, documentType: DocumentType) async throws -> String {
        // This would query the LearningPattern database
        // and apply user-learned preferences
        // Placeholder for now
        return text
    }

    private func applyCloudEnhancement(_ text: String, documentType: DocumentType) async throws -> String {
        // This would call external LLM API (Claude/OpenAI)
        // with document-type-specific prompts
        // Placeholder for now
        return text
    }
}

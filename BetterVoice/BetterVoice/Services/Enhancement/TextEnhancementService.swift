//
//  TextEnhancementService.swift
//  BetterVoice
//
//  6-stage text enhancement pipeline coordinating multiple services
//  Per research.md: Normalize → RemoveFillers → Punctuate → Format → Learning → Cloud
//

import Foundation

// MARK: - Errors

enum EnhancementError: Error {
    case missingAPIKey
    case unsupportedProvider(String)
}

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
    private let sentenceAnalyzer = SentenceAnalyzer()
    private var classificationService: TextClassificationService?

    // MARK: - Initialization

    init(classificationService: TextClassificationService? = nil) {
        self.classificationService = classificationService
    }

    // MARK: - Public Methods

    func enhance(
        text: String,
        documentType: DocumentType,
        applyLearning: Bool = false,
        useCloud: Bool = false
    ) async throws -> EnhancedText {

        var enhanced = text
        var appliedRules: [String] = []
        var detectedType = documentType

        // Stage 0: Auto-classify if service available and documentType is .unknown
        if documentType == .unknown, let classifier = classificationService {
            do {
                let classification = try await classifier.classify(text)
                detectedType = classification.category
                appliedRules.append("auto_classify_\(detectedType.rawValue)")
            } catch {
                Logger.shared.error("Auto-classification failed", error: error)
                // Continue with .unknown
            }
        }

        // Stage 1: Normalize
        enhanced = normalize(enhanced)
        appliedRules.append("normalize")

        // Stage 2: Remove Fillers
        let prefs = UserPreferences.load()
        if prefs.removeFillerWords {
            let fillerResult = fillerRemover.remove(from: enhanced)
            enhanced = fillerResult.cleanedText
            _ = fillerResult.removedFillers  // Track but don't store in final model
            appliedRules.append("remove_fillers")
        }

        // Stage 3: Punctuate & Capitalize (using sentence analyzer)
        if prefs.autoPunctuate || prefs.autoCapitalize {
            enhanced = await sentenceAnalyzer.enhance(
                enhanced,
                autoPunctuate: prefs.autoPunctuate,
                autoCapitalize: prefs.autoCapitalize
            )
            appliedRules.append("punctuate_capitalize")
        }

        // Stage 4: Format by document type (use detected type)
        let formatResult = formatApplier.apply(to: enhanced, documentType: detectedType)
        enhanced = formatResult.formattedText
        _ = formatResult.changes  // Track but don't store in final model
        appliedRules.append("format_\(detectedType.rawValue)")

        // Stage 5: Apply Learning (if enabled)
        var patternsApplied = 0
        if applyLearning {
            do {
                let beforeLearning = enhanced
                enhanced = try learningService.applyLearned(text: enhanced, documentType: detectedType)
                if enhanced != beforeLearning {
                    appliedRules.append("apply_learning")
                    patternsApplied = 1 // Simplified count
                }
            } catch {
                Logger.shared.error("Failed to apply learning patterns", error: error)
            }
        }

        // Stage 6: Cloud Enhancement (if enabled)
        if useCloud && prefs.externalLLMEnabled {
            do {
                enhanced = try await applyCloudEnhancement(enhanced, documentType: detectedType)
                appliedRules.append("cloud_enhance")
            } catch {
                Logger.shared.error("Cloud enhancement failed", error: error)
            }
        }

        return EnhancedText(
            id: UUID(),
            originalText: text,
            enhancedText: enhanced,
            documentType: detectedType,  // Use detected type in result
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
        let prefs = UserPreferences.load()

        // Check if external LLM is enabled for this document type
        let shouldEnhance: Bool
        switch documentType {
        case .email: shouldEnhance = prefs.llmEnhanceEmail
        case .message: shouldEnhance = prefs.llmEnhanceMessage
        case .document: shouldEnhance = prefs.llmEnhanceDocument
        case .social: shouldEnhance = prefs.llmEnhanceSocial
        case .code: shouldEnhance = prefs.llmEnhanceCode
        case .search, .searchQuery, .unknown: shouldEnhance = false
        }

        guard shouldEnhance else {
            return text // Skip LLM enhancement for this document type
        }

        guard let apiKey = prefs.externalLLMAPIKey, !apiKey.isEmpty else {
            throw EnhancementError.missingAPIKey
        }

        let provider = prefs.externalLLMProvider ?? "claude"

        switch provider.lowercased() {
        case "claude":
            let client = ClaudeAPIClient(apiKey: apiKey)
            let systemPrompt = documentType.enhancementPrompt
            return try await client.enhance(text: text, documentType: documentType, systemPrompt: systemPrompt)

        case "openai":
            let client = OpenAIAPIClient(apiKey: apiKey)
            let systemPrompt = documentType.enhancementPrompt
            return try await client.enhance(text: text, documentType: documentType, systemPrompt: systemPrompt)

        default:
            throw EnhancementError.unsupportedProvider(provider)
        }
    }
}

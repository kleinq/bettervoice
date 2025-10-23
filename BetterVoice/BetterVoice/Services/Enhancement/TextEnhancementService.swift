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
        useCloud: Bool
    ) async throws -> EnhancedText
}

// MARK: - Service Implementation

final class TextEnhancementService: TextEnhancementServiceProtocol {

    // MARK: - Dependencies

    private let fillerRemover = FillerWordRemover.shared
    private let formatApplier = FormatApplier.shared
    private let sentenceAnalyzer = SentenceAnalyzer()
    private let voiceCommandParser = VoiceCommandParser.shared
    private let selfCorrectionHandler = SelfCorrectionHandler.shared
    private var classificationService: TextClassificationService?

    // MARK: - Initialization

    init(classificationService: TextClassificationService? = nil) {
        self.classificationService = classificationService
    }

    // MARK: - Public Methods

    func enhance(
        text: String,
        documentType: DocumentType,
        useCloud: Bool = false
    ) async throws -> EnhancedText {

        var enhanced = text
        var appliedRules: [String] = []
        var detectedType = documentType
        var voiceCommandInstruction: VoiceCommandInstruction?

        // Stage -1: Voice Command Detection
        // Check if text starts with "BV" or "Better Voice" command prefix
        if let instruction = voiceCommandParser.parse(text) {
            Logger.shared.info("🎤 Voice command detected: \(instruction.instruction)")
            voiceCommandInstruction = instruction

            // Override document type based on instruction
            detectedType = instruction.targetDocumentType

            // Use the extracted content (without prefix and instruction)
            enhanced = instruction.content

            appliedRules.append("voice_command_\(instruction.targetDocumentType.rawValue)")

            // Log recipient if present
            if let recipient = instruction.recipient {
                Logger.shared.info("📧 Recipient: \(recipient)")
                appliedRules.append("recipient_\(recipient)")
            }
        }

        // If no voice command and still .unknown, keep as .unknown for generic formatting
        if documentType == .unknown && voiceCommandInstruction == nil {
            Logger.shared.info("📝 No voice command detected - using generic formatting")
        }

        // Stage 1: Normalize
        enhanced = normalize(enhanced)
        Logger.shared.debug("📝 After normalize: '\(enhanced)'")
        appliedRules.append("normalize")

        // Stage 1.5: Remove Self-Corrections
        let beforeCorrection = enhanced
        enhanced = selfCorrectionHandler.process(enhanced)
        if enhanced != beforeCorrection {
            Logger.shared.debug("🔧 After self-correction: '\(enhanced)'")
            appliedRules.append("self_correction")

            // Log detected corrections for debugging
            let corrections = selfCorrectionHandler.analyzeCorrections(beforeCorrection)
            if !corrections.isEmpty {
                Logger.shared.info("Detected \(corrections.count) self-correction(s): \(corrections.map { $0.marker })")
            }
        }

        // Stage 2: Remove Fillers
        let prefs = UserPreferences.load()
        if prefs.removeFillerWords {
            let fillerResult = fillerRemover.remove(from: enhanced)
            enhanced = fillerResult.cleanedText
            Logger.shared.debug("🧹 After filler removal: '\(enhanced)'")
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
            Logger.shared.debug("✏️ After punctuate/capitalize: '\(enhanced)'")
            appliedRules.append("punctuate_capitalize")
        }

        // Stage 4: Format by document type (use detected type)
        // Pass recipient and metadata from voice command if available
        let beforeFormat = enhanced
        let formatResult = formatApplier.apply(
            to: enhanced,
            documentType: detectedType,
            recipient: voiceCommandInstruction?.recipient,
            metadata: voiceCommandInstruction?.metadata ?? [:]
        )
        enhanced = formatResult.formattedText
        Logger.shared.debug("📐 After format (\(detectedType.rawValue)): '\(enhanced)'")

        // Warn if content was significantly truncated (possible mis-classification)
        let beforeLength = beforeFormat.count
        let afterLength = enhanced.count
        if beforeLength > 200 && Double(afterLength) < Double(beforeLength) * 0.5 {
            Logger.shared.warning("⚠️ Content significantly truncated: \(beforeLength) → \(afterLength) chars. Type: \(detectedType.rawValue). This may indicate mis-classification.")
        }

        _ = formatResult.changes  // Track but don't store in final model
        appliedRules.append("format_\(detectedType.rawValue)")

        // Stage 5: Cloud Enhancement (if enabled)
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
            learnedPatternsApplied: 0,
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

        // Ensure space after sentence-ending punctuation (. ! ?)
        // Pattern: period/exclamation/question followed by letter without space
        let sentenceEndPattern = "([.!?])([A-Z])"
        if let regex = try? NSRegularExpression(pattern: sentenceEndPattern, options: []) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        }

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

//
//  DocumentTypeContext.swift
//  BetterVoice
//
//  Model representing detected document context
//  Multi-strategy detection: Bundle ID → URL → NLP
//

import Foundation

enum DocumentType: String, Codable {
    case email
    case message
    case document
    case social
    case code
    case search  // Renamed from searchQuery for classification consistency
    case searchQuery  // Deprecated: Use .search instead
    case unknown

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .message: return "Message"
        case .document: return "Document"
        case .social: return "Social Media"
        case .code: return "Code"
        case .search, .searchQuery: return "Search"
        case .unknown: return "Unknown"
        }
    }

    /// Raw string value for database storage (classification uses "search")
    var classificationCategory: String {
        switch self {
        case .searchQuery: return "search"
        case .unknown: return "unknown"
        default: return self.rawValue
        }
    }

    /// Get LLM prompt for this document type
    var enhancementPrompt: String {
        // Check for custom prompt first (Feature 004-allow-editing-of)
        let prefs = UserPreferences.load()
        if let customPrompt = prefs.getCustomPrompt(for: self) {
            Logger.shared.debug("Using custom prompt for \(self.rawValue)")
            return customPrompt
        }

        // Fallback to default prompts
        Logger.shared.debug("Using default prompt for \(self.rawValue)")
        switch self {
        case .email:
            return """
            You are a text reviewer and editor. Your task is to analyze written communications and rewrite them to be more effective based on their intended purpose and meaning.

            Here is the text you need to review:

            <text>
            {{TEXT}}
            </text>

            Follow this process to improve the text:

            ## Step 1: Communication Type Assessment
            Determine what type of communication this is (email, text message, Slack message, social media post, etc.) and identify its primary purpose.

            **Important:** If this is a casual text message or informal email, return the original message unchanged and skip all remaining steps.

            ## Step 2: Systematic Analysis and Improvement

            For all other communications, conduct a thorough analysis. This internal work will help you create the best possible result, but remember: you must output ONLY the final improved text after your analysis is complete. It's OK for this section to be quite long. Do not output the <analysis>

            In your analysis, work through these steps:

            ### 2.1 Communication Type and Purpose Verification
            - Explicitly state the communication type you've identified
            - Explicitly state whether you're proceeding with improvement or returning the original unchanged
            - If proceeding, state the primary purpose (inform, request, persuade, apologize, etc.)

            ### 2.2 Key Phrase Extraction and Purpose Analysis
            - Quote at least 3-5 important phrases from the original text verbatim
            - Quote specific phrases that indicate the communication type and primary purpose
            - Summarize the core meaning and key points
            - Identify the intended audience

            ### 2.3 Custom Evaluation Criteria
            Create 5 specific criteria for evaluating this message based on its purpose. Choose from:
            - Clarity and conciseness
            - Appropriate tone for audience and context
            - Completeness of necessary information
            - Call-to-action clarity (if one exists in the original)
            - Professional/appropriate language use
            - Emotional impact alignment with purpose
            - Structure and organization

            ### 2.4 Iterative Improvement Process
            - Quote specific parts that need improvement and explain why
            - Write an initial improved version (label it "Version 1")
            - Score it against each of your 5 criteria using this format:
              * Criterion 1: X/10 - [reasoning]
              * Criterion 2: X/10 - [reasoning]
              * etc.
            - If any scores are below 10, write a revised version addressing those weaknesses (label it "Version 2")
            - Note what specific changes you're making and why
            - Re-score the revision against all 5 criteria using the same format
            - Continue revising and scoring with clearly labeled versions until you achieve 10/10 on all criteria
            - Confirm your final scoring with brief justification for each 10/10 score

            ### 2.5 Final Verification
            - Verify that if the original had no call-to-action, you haven't added one
            - Ensure the improved version maintains the original intent and meaning

            ## Writing Guidelines
            Write with extreme clarity, precision, and simplicity. Use direct communication that balances optimization with reader engagement. Focus on:
            - Simple subject-verb-object sentence structures
            - Precise word selection
            - Elimination of unnecessary complexity
            - Clear, structured content
            - Language that works for both algorithms and humans

            ** Output Requirements. **
            Do not output any of the analysis performed, after completing your analysis, provide only the final improved message. Do not include any commentary, explanation, scoring, or prefatory phrases like "Here's a professionally formatted version:" Your final output should consist solely of the improved message text.

            **Example of desired output structure: **
            [Only the improved message text appears here, with no additional commentary or labels, or XML tags]
            """

        case .message:
            return """
            You are editing a message (Slack/Teams). Format the text conversationally:
            - Keep it concise and casual
            - Use natural conversational tone
            - Add punctuation for clarity
            - Break into short lines if needed
            """

        case .document:
            return """
            You are editing a document. Format the text formally:
            - Use proper grammar and punctuation
            - Organize into well-structured paragraphs
            - Maintain formal, clear language
            - Ensure professional tone
            """

        case .social:
            return """
            You are editing a social media post. Format appropriately:
            - Keep it engaging and concise
            - Use natural, conversational tone
            - Add appropriate punctuation
            - Consider character limits
            """

        case .code:
            return """
            You are editing code comments or documentation:
            - Use technical terminology accurately
            - Keep formatting minimal
            - Preserve code-like structure
            - Use proper technical capitalization
            """

        case .search, .searchQuery:
            return """
            Format as a search query:
            - Keep concise and keyword-focused
            - Use proper capitalization for proper nouns
            - No punctuation needed
            """

        case .unknown:
            return """
            Format the text with proper grammar and punctuation:
            - Capitalize sentences
            - Add appropriate punctuation
            - Improve clarity
            """
        }
    }
}

enum DetectionMethod: String, Codable {
    case bundleID
    case url
    case nlp
    case classification  // New: ML-based text classification
    case unknown
}

struct DocumentTypeContext: Codable {
    let documentType: DocumentType
    let detectionMethod: DetectionMethod
    let confidence: Double
    let bundleID: String?
    let url: String?
    let appName: String?
    let classification: TextClassification?  // New: Classification result if method == .classification

    // Default initializer
    init(
        documentType: DocumentType,
        detectionMethod: DetectionMethod,
        confidence: Double,
        bundleID: String? = nil,
        url: String? = nil,
        appName: String? = nil,
        classification: TextClassification? = nil
    ) {
        self.documentType = documentType
        self.detectionMethod = detectionMethod
        self.confidence = confidence
        self.bundleID = bundleID
        self.url = url
        self.appName = appName
        self.classification = classification
    }

    // Create context from text classification result
    static func fromClassification(_ classification: TextClassification) -> DocumentTypeContext {
        return DocumentTypeContext(
            documentType: classification.category,
            detectionMethod: .classification,
            confidence: 0.8,  // Default confidence for ML classification
            classification: classification
        )
    }

    // QR-002: Document type detection accuracy should be >85%
    var isConfident: Bool {
        return confidence >= 0.85
    }
}

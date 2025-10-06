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
        switch self {
        case .email:
            return """
            You are editing an email. Format the text professionally:
            - Use proper business email tone
            - Start sentences with capital letters
            - Add appropriate punctuation
            - Organize into clear paragraphs if needed
            - Maintain professional language
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

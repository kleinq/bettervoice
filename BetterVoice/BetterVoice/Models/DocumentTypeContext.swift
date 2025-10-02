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
    case searchQuery
    case unknown
}

enum DetectionMethod: String, Codable {
    case bundleID
    case url
    case nlp
    case unknown
}

struct DocumentTypeContext: Codable {
    let documentType: DocumentType
    let detectionMethod: DetectionMethod
    let confidence: Double
    let bundleID: String?
    let url: String?
    let appName: String?

    // Default initializer
    init(
        documentType: DocumentType,
        detectionMethod: DetectionMethod,
        confidence: Double,
        bundleID: String? = nil,
        url: String? = nil,
        appName: String? = nil
    ) {
        self.documentType = documentType
        self.detectionMethod = detectionMethod
        self.confidence = confidence
        self.bundleID = bundleID
        self.url = url
        self.appName = appName
    }

    // QR-002: Document type detection accuracy should be >85%
    var isConfident: Bool {
        return confidence >= 0.85
    }
}

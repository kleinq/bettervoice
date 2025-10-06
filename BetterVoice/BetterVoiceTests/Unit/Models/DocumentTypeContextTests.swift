//
//  DocumentTypeContextTests.swift
//  BetterVoiceTests
//
//  Unit tests for DocumentTypeContext model
//  Tests document type detection accuracy (QR-002: >85%)
//

import XCTest
@testable import BetterVoice

final class DocumentTypeContextTests: XCTestCase {

    func testDocumentTypeContextIsEncodableAndDecodable() throws {
        // Given
        let context = DocumentTypeContext(
            documentType: .email,
            detectionMethod: .bundleID,
            confidence: 0.95,
            bundleID: "com.apple.mail",
            url: nil,
            appName: "Mail"
        )

        // When
        let encoded = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(DocumentTypeContext.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.documentType, context.documentType)
        XCTAssertEqual(decoded.detectionMethod, context.detectionMethod)
        XCTAssertEqual(decoded.confidence, context.confidence)
        XCTAssertEqual(decoded.bundleID, context.bundleID)
    }

    func testIsConfidentProperty() {
        // Given: High confidence (≥0.85)
        let highConf = DocumentTypeContext(
            documentType: .email,
            detectionMethod: .bundleID,
            confidence: 0.95,
            bundleID: "com.apple.mail"
        )

        // Then: QR-002 requires >85% accuracy
        XCTAssertTrue(highConf.isConfident, "Confidence ≥0.85 should be confident (QR-002)")
        XCTAssertEqual(highConf.confidence, 0.95, accuracy: 0.01)

        // Given: Edge case exactly 0.85
        let edgeConf = DocumentTypeContext(
            documentType: .email,
            detectionMethod: .bundleID,
            confidence: 0.85
        )

        // Then
        XCTAssertTrue(edgeConf.isConfident, "Confidence exactly 0.85 should be confident")

        // Given: Low confidence (<0.85)
        let lowConf = DocumentTypeContext(
            documentType: .unknown,
            detectionMethod: .nlp,
            confidence: 0.5
        )

        // Then
        XCTAssertFalse(lowConf.isConfident, "Confidence <0.85 should not be confident")
    }

    func testDocumentTypeEnum() {
        // Given
        let types: [DocumentType] = [.email, .message, .document, .searchQuery, .unknown]

        // Then
        XCTAssertEqual(types.count, 5)
        XCTAssertEqual(DocumentType.email.rawValue, "email")
        XCTAssertEqual(DocumentType.message.rawValue, "message")
        XCTAssertEqual(DocumentType.document.rawValue, "document")
        XCTAssertEqual(DocumentType.searchQuery.rawValue, "searchQuery")
        XCTAssertEqual(DocumentType.unknown.rawValue, "unknown")
    }

    func testDetectionMethodEnum() {
        // Given: Multi-strategy detection (plan.md section 4.2.1)
        let methods: [DetectionMethod] = [
            .bundleID,
            .url,
            .nlp,
            .unknown
        ]

        // Then
        XCTAssertEqual(methods.count, 4)
        XCTAssertEqual(DetectionMethod.bundleID.rawValue, "bundleID")
        XCTAssertEqual(DetectionMethod.url.rawValue, "url")
        XCTAssertEqual(DetectionMethod.nlp.rawValue, "nlp")
        XCTAssertEqual(DetectionMethod.unknown.rawValue, "unknown")
    }

    func testBundleIDDetection() {
        // Given: Bundle ID mapping (highest confidence)
        let context = DocumentTypeContext(
            documentType: .message,
            detectionMethod: .bundleID,
            confidence: 0.98,
            bundleID: "com.apple.iChat",
            appName: "Messages"
        )

        // Then
        XCTAssertEqual(context.documentType, .message)
        XCTAssertEqual(context.detectionMethod, .bundleID)
        XCTAssertGreaterThanOrEqual(context.confidence, 0.85, "Bundle ID detection should be high confidence")
        XCTAssertNotNil(context.bundleID)
        XCTAssertNotNil(context.appName)
    }

    func testURLDetection() {
        // Given: URL-based detection
        let context = DocumentTypeContext(
            documentType: .email,
            detectionMethod: .url,
            confidence: 0.92,
            bundleID: "com.google.Chrome",
            url: "https://mail.google.com/mail/u/0/#inbox",
            appName: "Chrome"
        )

        // Then
        XCTAssertEqual(context.documentType, .email)
        XCTAssertEqual(context.detectionMethod, .url)
        XCTAssertNotNil(context.url, "URL detection should have URL")
        XCTAssertTrue(context.isConfident)
    }

    func testNLPFallbackDetection() {
        // Given: NLP fallback (lowest confidence)
        let context = DocumentTypeContext(
            documentType: .searchQuery,
            detectionMethod: .nlp,
            confidence: 0.65,
            bundleID: "com.unknown.app"
        )

        // Then
        XCTAssertEqual(context.documentType, .searchQuery)
        XCTAssertEqual(context.detectionMethod, .nlp)
        XCTAssertLessThan(context.confidence, 0.85, "NLP fallback typically has lower confidence")
        XCTAssertFalse(context.isConfident)
    }

    func testUnknownTypeDetection() {
        // Given: Unknown type when all detection fails
        let context = DocumentTypeContext(
            documentType: .unknown,
            detectionMethod: .unknown,
            confidence: 0.0,
            bundleID: "com.unrecognized.app"
        )

        // Then
        XCTAssertEqual(context.documentType, .unknown)
        XCTAssertEqual(context.detectionMethod, .unknown)
        XCTAssertEqual(context.confidence, 0.0)
        XCTAssertFalse(context.isConfident)
    }

    func testOptionalFields() {
        // Given: Context without optional URL
        let contextWithoutURL = DocumentTypeContext(
            documentType: .document,
            detectionMethod: .bundleID,
            confidence: 0.90,
            bundleID: "com.microsoft.Word"
        )

        // Then
        XCTAssertNil(contextWithoutURL.url)
        XCTAssertNil(contextWithoutURL.appName)

        // Given: Context with all fields
        let contextComplete = DocumentTypeContext(
            documentType: .email,
            detectionMethod: .url,
            confidence: 0.95,
            bundleID: "com.google.Chrome",
            url: "https://gmail.com",
            appName: "Chrome"
        )

        // Then
        XCTAssertNotNil(contextComplete.url)
        XCTAssertNotNil(contextComplete.appName)
        XCTAssertNotNil(contextComplete.bundleID)
    }

    func testConfidenceThreshold() {
        // Given: QR-002 requires >85% accuracy
        let contexts = [
            DocumentTypeContext(documentType: .email, detectionMethod: .bundleID, confidence: 1.0),
            DocumentTypeContext(documentType: .email, detectionMethod: .bundleID, confidence: 0.95),
            DocumentTypeContext(documentType: .email, detectionMethod: .bundleID, confidence: 0.85),
            DocumentTypeContext(documentType: .email, detectionMethod: .url, confidence: 0.84),
            DocumentTypeContext(documentType: .email, detectionMethod: .nlp, confidence: 0.5)
        ]

        // Then
        XCTAssertTrue(contexts[0].isConfident)
        XCTAssertTrue(contexts[1].isConfident)
        XCTAssertTrue(contexts[2].isConfident) // Exactly 0.85
        XCTAssertFalse(contexts[3].isConfident)
        XCTAssertFalse(contexts[4].isConfident)
    }
}

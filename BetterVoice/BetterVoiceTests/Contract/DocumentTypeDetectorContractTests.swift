//
//  DocumentTypeDetectorContractTests.swift
//  BetterVoiceTests
//
//  Contract tests for DocumentTypeDetector
//  Tests MUST FAIL until implementation (TDD Red phase)
//

import XCTest
@testable import BetterVoice

final class DocumentTypeDetectorContractTests: XCTestCase {
    var sut: DocumentTypeDetector!

    override func setUp() {
        super.setUp()
        sut = DocumentTypeDetector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Contract: Detects email from Mail.app bundle ID

    func testDetectsEmailFromMailApp() {
        // Given
        let bundleID = "com.apple.mail"
        let appName = "Mail"

        // When
        let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: nil)

        // Then
        XCTAssertEqual(result.detectedType, .email, "Should detect email from Mail.app")
        XCTAssertEqual(result.detectionMethod, .bundleIDMapping, "Should use bundle ID mapping")
        XCTAssertGreaterThan(result.confidence, 0.9, "Should have high confidence")
    }

    // MARK: - Contract: Detects email from Gmail URL

    func testDetectsEmailFromGmailURL() {
        // Given
        let bundleID = "com.google.Chrome"
        let appName = "Google Chrome"
        let url = "https://mail.google.com/mail/u/0/#inbox?compose=new"

        // When
        let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: url)

        // Then
        XCTAssertEqual(result.detectedType, .email, "Should detect email from Gmail URL")
        XCTAssertEqual(result.detectionMethod, .urlAnalysis, "Should use URL analysis")
        XCTAssertGreaterThan(result.confidence, 0.85, "Should have high confidence")
    }

    // MARK: - Contract: Detects message from Slack bundle ID

    func testDetectsMessageFromSlack() {
        // Given
        let bundleID = "com.tinyspeck.slackmacgap"
        let appName = "Slack"

        // When
        let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: nil)

        // Then
        XCTAssertEqual(result.detectedType, .message, "Should detect message from Slack")
        XCTAssertEqual(result.detectionMethod, .bundleIDMapping, "Should use bundle ID mapping")
        XCTAssertGreaterThan(result.confidence, 0.9, "Should have high confidence")
    }

    // MARK: - Contract: Fallback NLP detection for unknown apps

    func testFallbackNLPDetectionForUnknownApp() {
        // Given
        let bundleID = "com.unknown.app"
        let appName = "Unknown App"
        let textSample = "search for best restaurants near me"

        // When
        let result = sut.detectFromText(sample: textSample)

        // Then
        XCTAssertEqual(result.detectedType, .searchQuery, "Should detect search query from text")
        XCTAssertEqual(result.detectionMethod, .nlpFallback, "Should use NLP fallback")
        XCTAssertGreaterThan(result.confidence, 0.0, "Should have some confidence")
    }

    // MARK: - QR-002: >85% accuracy goal

    func testDetectionMeetsAccuracyGoal() {
        // Given: Test cases representing common scenarios
        let testCases: [(bundleID: String, appName: String, url: String?, expectedType: DocumentType)] = [
            ("com.apple.mail", "Mail", nil, .email),
            ("com.microsoft.Outlook", "Outlook", nil, .email),
            ("com.google.Chrome", "Chrome", "https://mail.google.com", .email),
            ("com.tinyspeck.slackmacgap", "Slack", nil, .message),
            ("com.apple.iChat", "Messages", nil, .message),
            ("discord.Discord", "Discord", nil, .message),
            ("com.apple.TextEdit", "TextEdit", nil, .document),
            ("com.apple.dt.Xcode", "Xcode", nil, .document),
            ("com.google.Chrome", "Chrome", "https://docs.google.com", .document),
            ("com.apple.Safari", "Safari", "https://www.google.com/search?q=", .searchQuery)
        ]

        var correctCount = 0

        // When
        for testCase in testCases {
            let result = sut.detect(
                bundleID: testCase.bundleID,
                appName: testCase.appName,
                windowTitle: nil,
                url: testCase.url
            )

            if result.detectedType == testCase.expectedType {
                correctCount += 1
            }
        }

        let accuracy = Double(correctCount) / Double(testCases.count)

        // Then
        XCTAssertGreaterThan(accuracy, 0.85, "Detection accuracy must exceed 85% (QR-002)")
    }

    // MARK: - Known App Mappings

    func testDetectsEmailApps() {
        let emailApps = [
            ("com.apple.mail", "Mail"),
            ("com.microsoft.Outlook", "Outlook"),
            ("com.readdle.sparkmac", "Spark")
        ]

        for (bundleID, appName) in emailApps {
            let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: nil)
            XCTAssertEqual(result.detectedType, .email, "\(appName) should be detected as email")
        }
    }

    func testDetectsMessageApps() {
        let messageApps = [
            ("com.tinyspeck.slackmacgap", "Slack"),
            ("com.apple.iChat", "Messages"),
            ("discord.Discord", "Discord"),
            ("com.electron.whatsapp", "WhatsApp"),
            ("ru.keepcoder.Telegram", "Telegram")
        ]

        for (bundleID, appName) in messageApps {
            let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: nil)
            XCTAssertEqual(result.detectedType, .message, "\(appName) should be detected as message")
        }
    }

    func testDetectsDocumentApps() {
        let documentApps = [
            ("com.apple.TextEdit", "TextEdit"),
            ("com.microsoft.Word", "Microsoft Word"),
            ("com.apple.iWork.Pages", "Pages"),
            ("com.apple.dt.Xcode", "Xcode"),
            ("md.obsidian", "Obsidian")
        ]

        for (bundleID, appName) in documentApps {
            let result = sut.detect(bundleID: bundleID, appName: appName, windowTitle: nil, url: nil)
            XCTAssertEqual(result.detectedType, .document, "\(appName) should be detected as document")
        }
    }

    // MARK: - Browser URL Analysis

    func testDetectsBrowserBasedApps() {
        let browserURLs = [
            ("https://mail.google.com/mail/u/0/", .email),
            ("https://docs.google.com/document/d/123", .document),
            ("https://www.google.com/search?q=test", .searchQuery),
            ("https://app.slack.com/client/", .message)
        ]

        for (url, expectedType) in browserURLs {
            let result = sut.detect(
                bundleID: "com.google.Chrome",
                appName: "Chrome",
                windowTitle: nil,
                url: url
            )
            XCTAssertEqual(result.detectedType, expectedType, "\(url) should be detected as \(expectedType)")
        }
    }

    // MARK: - NLP Fallback

    func testNLPFallbackDetectsSearchQueries() {
        let searchTexts = [
            "find best pizza near me",
            "search for weather forecast",
            "what is the capital of france"
        ]

        for text in searchTexts {
            let result = sut.detectFromText(sample: text)
            XCTAssertEqual(result.detectedType, .searchQuery, "Should detect search query from '\(text)'")
        }
    }

    func testNLPFallbackDetectsEmailContent() {
        let emailTexts = [
            "dear john i wanted to follow up sincerely",
            "hi sarah thanks for your help best regards",
            "hello team i hope this email finds you well"
        ]

        for text in emailTexts {
            let result = sut.detectFromText(sample: text)
            XCTAssertEqual(result.detectedType, .email, "Should detect email from '\(text)'")
        }
    }

    func testNLPFallbackDetectsMessageContent() {
        let messageTexts = [
            "hey can you send me the link",
            "lol that's funny",
            "btw did you see that message"
        ]

        for text in messageTexts {
            let result = sut.detectFromText(sample: text)
            XCTAssertEqual(result.detectedType, .message, "Should detect message from '\(text)'")
        }
    }

    // MARK: - Unknown Cases

    func testReturnsUnknownForAmbiguousCases() {
        // Given
        let unknownBundleID = "com.totally.unknown.app"
        let unknownAppName = "Unknown App"
        let ambiguousText = "abc def ghi"

        // When
        let result = sut.detect(bundleID: unknownBundleID, appName: unknownAppName, windowTitle: nil, url: nil)

        // Then
        XCTAssertEqual(result.detectedType, .unknown, "Should return unknown for unrecognized app")
        XCTAssertLessThan(result.confidence, 0.5, "Should have low confidence for unknown")
    }
}

// MARK: - Supporting Types (Contracts)

protocol DocumentTypeDetectorProtocol {
    func detect(bundleID: String, appName: String, windowTitle: String?, url: String?) -> DocumentTypeContext
    func detectFromText(sample: String) -> DocumentTypeContext
}

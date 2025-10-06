//
//  DominantCharacteristicAnalyzerTests.swift
//  BetterVoiceTests
//
//  Unit tests for DominantCharacteristicAnalyzer
//

import XCTest
@testable import BetterVoice

final class DominantCharacteristicAnalyzerTests: XCTestCase {

    var analyzer: DominantCharacteristicAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = DominantCharacteristicAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Message Classification Tests

    func testAnalyze_casualGreeting_returnsMessage() {
        let text = "Hey what's up"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 3,
            averageSentenceLength: 3.0,
            hasCompleteSentences: false,
            formalityScore: 0.2,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: true,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .message)

        XCTAssertEqual(result, .message)
    }

    func testAnalyze_shortCasualText_returnsMessage() {
        let text = "Thanks for the help!"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 4,
            averageSentenceLength: 4.0,
            hasCompleteSentences: true,
            formalityScore: 0.3,
            technicalTermCount: 0,
            punctuationDensity: 0.1,
            hasGreeting: false,
            hasSignature: true
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .social)

        // Should classify as message due to short length + signature
        XCTAssertTrue([.message, .social].contains(result))
    }

    // MARK: - Email Classification Tests

    func testAnalyze_formalGreetingWithSignature_returnsEmail() {
        let text = "Dear Sir, I am writing to inquire. Best regards,"
        let features = TextFeatures(
            sentenceCount: 2,
            wordCount: 10,
            averageSentenceLength: 5.0,
            hasCompleteSentences: true,
            formalityScore: 0.8,
            technicalTermCount: 0,
            punctuationDensity: 0.1,
            hasGreeting: true,
            hasSignature: true
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .email)

        XCTAssertEqual(result, .email)
    }

    func testAnalyze_highFormalityLongSentences_returnsEmailOrDocument() {
        let text = "The comprehensive analysis demonstrates significant findings."
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 7,
            averageSentenceLength: 20.0,
            hasCompleteSentences: true,
            formalityScore: 0.9,
            technicalTermCount: 0,
            punctuationDensity: 0.05,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .document)

        XCTAssertTrue([.email, .document].contains(result))
    }

    // MARK: - Document Classification Tests

    func testAnalyze_longFormalText_returnsDocument() {
        let text = String(repeating: "The analysis shows significant results. ", count: 10)
        let features = TextFeatures(
            sentenceCount: 10,
            wordCount: 120,
            averageSentenceLength: 25.0,
            hasCompleteSentences: true,
            formalityScore: 0.85,
            technicalTermCount: 0,
            punctuationDensity: 0.08,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .document)

        XCTAssertEqual(result, .document)
    }

    // MARK: - Social Classification Tests

    func testAnalyze_shortInformalNoPunctuation_returnsSocial() {
        let text = "Just shipped our new feature"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 5,
            averageSentenceLength: 5.0,
            hasCompleteSentences: false,
            formalityScore: 0.2,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .social)

        XCTAssertEqual(result, .social)
    }

    func testAnalyze_highPunctuationDensity_returnsSocial() {
        let text = "Wow!!! This is amazing!!!"
        let features = TextFeatures(
            sentenceCount: 2,
            wordCount: 4,
            averageSentenceLength: 2.0,
            hasCompleteSentences: true,
            formalityScore: 0.1,
            technicalTermCount: 0,
            punctuationDensity: 0.3,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .social)

        XCTAssertEqual(result, .social)
    }

    // MARK: - Code Classification Tests

    func testAnalyze_technicalTermsHighPunctuation_returnsCode() {
        let text = "function test() { return 42; }"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 6,
            averageSentenceLength: 6.0,
            hasCompleteSentences: false,
            formalityScore: 0.0,
            technicalTermCount: 3,
            punctuationDensity: 0.25,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .code)

        XCTAssertEqual(result, .code)
    }

    func testAnalyze_multipleTechnicalTerms_returnsCode() {
        let text = "const myVar = () => { return value; }"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 8,
            averageSentenceLength: 8.0,
            hasCompleteSentences: false,
            formalityScore: 0.0,
            technicalTermCount: 5,
            punctuationDensity: 0.2,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .message)

        // Technical terms should override ML prediction
        XCTAssertEqual(result, .code)
    }

    // MARK: - Search Classification Tests

    func testAnalyze_veryShortNoSentences_returnsSearch() {
        let text = "weather in Boston"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 3,
            averageSentenceLength: 3.0,
            hasCompleteSentences: false,
            formalityScore: 0.0,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .search)

        XCTAssertEqual(result, .search)
    }

    func testAnalyze_shortQueryLike_returnsSearch() {
        let text = "best restaurants nearby"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 3,
            averageSentenceLength: 3.0,
            hasCompleteSentences: false,
            formalityScore: 0.0,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .search)

        XCTAssertEqual(result, .search)
    }

    // MARK: - Tie Breaking Tests

    func testAnalyze_tieScenario_defersToPrediction() {
        let text = "Test"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 1,
            averageSentenceLength: 1.0,
            hasCompleteSentences: false,
            formalityScore: 0.5,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: false,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .message)

        // With no clear dominant features, should use ML prediction
        XCTAssertEqual(result, .message)
    }

    func testAnalyze_ambiguousFeatures_usesMLPrediction() {
        let text = "Hello thanks"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 2,
            averageSentenceLength: 2.0,
            hasCompleteSentences: false,
            formalityScore: 0.4,
            technicalTermCount: 0,
            punctuationDensity: 0.0,
            hasGreeting: true,
            hasSignature: true
        )

        // Both greeting and signature - could be email or message
        let result = analyzer.analyze(text: text, features: features, mlPrediction: .email)

        // Should respect ML prediction when features are ambiguous
        XCTAssertTrue([.email, .message].contains(result))
    }

    // MARK: - Mixed Signals Tests

    func testAnalyze_casualGreetingFormalBody_usesDominant() {
        let text = "Hey, I wanted to formally request approval for the proposed budget allocation."
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 12,
            averageSentenceLength: 12.0,
            hasCompleteSentences: true,
            formalityScore: 0.7,
            technicalTermCount: 0,
            punctuationDensity: 0.05,
            hasGreeting: true,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .message)

        // High formality should dominate casual greeting
        XCTAssertTrue([.email, .document].contains(result))
    }

    func testAnalyze_formalOpeningCasualClose_usesDominant() {
        let text = "Dear Sir, just wanted to check in quickly!"
        let features = TextFeatures(
            sentenceCount: 1,
            wordCount: 8,
            averageSentenceLength: 8.0,
            hasCompleteSentences: true,
            formalityScore: 0.6,
            technicalTermCount: 0,
            punctuationDensity: 0.1,
            hasGreeting: true,
            hasSignature: false
        )

        let result = analyzer.analyze(text: text, features: features, mlPrediction: .message)

        // Should analyze mixed signals and pick dominant
        XCTAssertTrue([.email, .message].contains(result))
    }
}

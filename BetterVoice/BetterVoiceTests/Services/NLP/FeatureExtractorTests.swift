//
//  FeatureExtractorTests.swift
//  BetterVoiceTests
//
//  Unit tests for FeatureExtractor service
//

import XCTest
import NaturalLanguage
@testable import BetterVoice

final class FeatureExtractorTests: XCTestCase {

    var extractor: FeatureExtractor!

    override func setUp() {
        super.setUp()
        extractor = FeatureExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - Sentence Count Tests

    func testExtract_singleSentence_returnsOne() {
        let text = "This is a single sentence."
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.sentenceCount, 1)
    }

    func testExtract_multipleSentences_returnsCorrectCount() {
        let text = "First sentence. Second sentence! Third sentence?"
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.sentenceCount, 3)
    }

    func testExtract_noSentence_returnsAtLeastOne() {
        let text = "no punctuation"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThanOrEqual(features.sentenceCount, 1)
    }

    // MARK: - Word Count Tests

    func testExtract_simpleText_correctWordCount() {
        let text = "Hello world how are you"
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.wordCount, 5)
    }

    func testExtract_withPunctuation_correctWordCount() {
        let text = "Hey, how's it going?"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThanOrEqual(features.wordCount, 4)
    }

    func testExtract_emptyText_zeroWords() {
        let text = ""
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.wordCount, 0)
    }

    // MARK: - Average Sentence Length Tests

    func testExtract_singleSentence_averageMatchesTotal() {
        let text = "This has five total words."
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.averageSentenceLength, Double(features.wordCount))
    }

    func testExtract_multipleSentences_correctAverage() {
        let text = "Short. This is a longer sentence with more words."
        let features = extractor.extract(from: text)
        let expectedAvg = Double(features.wordCount) / Double(features.sentenceCount)
        XCTAssertEqual(features.averageSentenceLength, expectedAvg, accuracy: 0.1)
    }

    // MARK: - Complete Sentences Tests

    func testExtract_endsWithPeriod_hasCompleteSentences() {
        let text = "This is a complete sentence."
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasCompleteSentences)
    }

    func testExtract_endsWithExclamation_hasCompleteSentences() {
        let text = "This is exciting!"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasCompleteSentences)
    }

    func testExtract_endsWithQuestion_hasCompleteSentences() {
        let text = "Is this a question?"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasCompleteSentences)
    }

    func testExtract_noEndingPunctuation_noCompleteSentences() {
        let text = "This has no ending"
        let features = extractor.extract(from: text)
        XCTAssertFalse(features.hasCompleteSentences)
    }

    // MARK: - Formality Score Tests

    func testExtract_formalityScore_inValidRange() {
        let texts = [
            "Dear Sir, I am writing to inquire.",
            "hey what's up",
            "The quarterly report demonstrates growth."
        ]

        for text in texts {
            let features = extractor.extract(from: text)
            XCTAssertGreaterThanOrEqual(features.formalityScore, 0.0)
            XCTAssertLessThanOrEqual(features.formalityScore, 1.0)
        }
    }

    func testExtract_formalText_higherFormalityScore() {
        let formal = "Dear Sir, I hereby submit this formal request."
        let casual = "yo what's up dude"

        let formalFeatures = extractor.extract(from: formal)
        let casualFeatures = extractor.extract(from: casual)

        XCTAssertGreaterThan(formalFeatures.formalityScore, casualFeatures.formalityScore)
    }

    // MARK: - Punctuation Density Tests

    func testExtract_punctuationDensity_correctRatio() {
        let text = "Hello, world! How are you?"
        let features = extractor.extract(from: text)

        // Count expected punctuation: , ! ?
        let punctuationCount = 3
        let totalChars = text.count
        let expectedDensity = Double(punctuationCount) / Double(totalChars)

        XCTAssertEqual(features.punctuationDensity, expectedDensity, accuracy: 0.01)
    }

    func testExtract_noPunctuation_zeroDensity() {
        let text = "no punctuation here"
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.punctuationDensity, 0.0, accuracy: 0.01)
    }

    func testExtract_punctuationDensity_inValidRange() {
        let text = "Test... with... lots... of... punctuation!!!"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThanOrEqual(features.punctuationDensity, 0.0)
        XCTAssertLessThanOrEqual(features.punctuationDensity, 1.0)
    }

    // MARK: - Greeting Detection Tests

    func testExtract_hasGreeting_detectsHey() {
        let text = "Hey there, how are you?"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasGreeting)
    }

    func testExtract_hasGreeting_detectsHi() {
        let text = "Hi everyone, great to see you!"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasGreeting)
    }

    func testExtract_hasGreeting_detectsDear() {
        let text = "Dear hiring manager, I am writing..."
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasGreeting)
    }

    func testExtract_hasGreeting_detectsHello() {
        let text = "Hello world!"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasGreeting)
    }

    func testExtract_noGreeting_returnsFalse() {
        let text = "This text has no greeting at all."
        let features = extractor.extract(from: text)
        XCTAssertFalse(features.hasGreeting)
    }

    func testExtract_greetingInMiddle_stillDetects() {
        let text = "I wanted to say hello to everyone."
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasGreeting)
    }

    // MARK: - Signature Detection Tests

    func testExtract_hasSignature_detectsRegards() {
        let text = "Looking forward to hearing from you. Best regards,"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasSignature)
    }

    func testExtract_hasSignature_detectsThanks() {
        let text = "Please let me know. Thanks!"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasSignature)
    }

    func testExtract_hasSignature_detectsBest() {
        let text = "Talk soon. Best,"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasSignature)
    }

    func testExtract_hasSignature_detectsSincerely() {
        let text = "I appreciate your time. Sincerely, John"
        let features = extractor.extract(from: text)
        XCTAssertTrue(features.hasSignature)
    }

    func testExtract_noSignature_returnsFalse() {
        let text = "Just a regular message with no closing."
        let features = extractor.extract(from: text)
        XCTAssertFalse(features.hasSignature)
    }

    // MARK: - Technical Terms Tests

    func testExtract_codeSnippet_detectsTechnicalTerms() {
        let text = "function calculateTotal(items) { return items.reduce() }"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThan(features.technicalTermCount, 0)
    }

    func testExtract_swiftCode_detectsTerms() {
        let text = "let myVar = 42; func doSomething() { return true }"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThan(features.technicalTermCount, 0)
    }

    func testExtract_pythonCode_detectsTerms() {
        let text = "def process_data(data): return [item for item in data]"
        let features = extractor.extract(from: text)
        XCTAssertGreaterThan(features.technicalTermCount, 0)
    }

    func testExtract_noTechnicalTerms_returnsZero() {
        let text = "This is just regular everyday text."
        let features = extractor.extract(from: text)
        XCTAssertEqual(features.technicalTermCount, 0)
    }

    // MARK: - Integration Tests

    func testExtract_casualMessage_expectedFeatures() {
        let text = "Hey Sarah, are we still on for lunch today?"

        let features = extractor.extract(from: text)

        XCTAssertTrue(features.hasGreeting)
        XCTAssertFalse(features.hasSignature)
        XCTAssertLessThan(features.formalityScore, 0.5)
        XCTAssertGreaterThan(features.wordCount, 0)
    }

    func testExtract_formalEmail_expectedFeatures() {
        let text = "Dear hiring manager, I am writing to express my interest. Best regards,"

        let features = extractor.extract(from: text)

        XCTAssertTrue(features.hasGreeting)
        XCTAssertTrue(features.hasSignature)
        XCTAssertGreaterThan(features.formalityScore, 0.3)
        XCTAssertTrue(features.hasCompleteSentences)
    }

    func testExtract_codeSnippet_expectedFeatures() {
        let text = "function test() { return 42; }"

        let features = extractor.extract(from: text)

        XCTAssertFalse(features.hasGreeting)
        XCTAssertFalse(features.hasSignature)
        XCTAssertGreaterThan(features.technicalTermCount, 0)
        XCTAssertGreaterThan(features.punctuationDensity, 0.1)
    }
}

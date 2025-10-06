//
//  TextTokenizer.swift
//  BetterVoice
//
//  Smart tokenization with word boundary detection
//  Handles spaces, punctuation, hyphens, and Unicode boundaries
//

import Foundation

// MARK: - Token Type

enum TokenType {
    case word
    case whitespace
    case punctuation
    case hyphen
}

// MARK: - Token

struct Token: Equatable {
    let text: String
    let type: TokenType
    let range: Range<String.Index>

    var isWord: Bool { type == .word }
    var isWhitespace: Bool { type == .whitespace }
    var isPunctuation: Bool { type == .punctuation }
    var isHyphen: Bool { type == .hyphen }
}

// MARK: - Text Tokenizer

final class TextTokenizer {

    // MARK: - Singleton

    static let shared = TextTokenizer()
    private init() {}

    // MARK: - Character Sets

    private let whitespaceChars = CharacterSet.whitespacesAndNewlines
    private let punctuationChars = CharacterSet.punctuationCharacters
        .subtracting(CharacterSet(charactersIn: "-–—")) // Exclude hyphens/dashes
    private let hyphenChars = CharacterSet(charactersIn: "-–—") // Hyphen, en-dash, em-dash

    // MARK: - Tokenization

    /// Tokenize text into words, whitespace, punctuation, and hyphens
    func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            let unicodeScalars = char.unicodeScalars

            // Determine token type
            if let scalar = unicodeScalars.first {
                if whitespaceChars.contains(scalar) {
                    // Whitespace token
                    let token = extractWhitespace(from: text, startingAt: currentIndex)
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                } else if hyphenChars.contains(scalar) {
                    // Hyphen token (special handling)
                    let range = currentIndex..<text.index(after: currentIndex)
                    tokens.append(Token(text: String(char), type: .hyphen, range: range))
                    currentIndex = text.index(after: currentIndex)
                } else if punctuationChars.contains(scalar) {
                    // Punctuation token
                    let range = currentIndex..<text.index(after: currentIndex)
                    tokens.append(Token(text: String(char), type: .punctuation, range: range))
                    currentIndex = text.index(after: currentIndex)
                } else {
                    // Word token
                    let token = extractWord(from: text, startingAt: currentIndex)
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                }
            }
        }

        return tokens
    }

    /// Extract contiguous word characters
    private func extractWord(from text: String, startingAt start: String.Index) -> Token {
        var endIndex = start

        while endIndex < text.endIndex {
            let char = text[endIndex]
            let unicodeScalars = char.unicodeScalars

            guard let scalar = unicodeScalars.first else { break }

            // Continue if alphanumeric or apostrophe (for contractions)
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "'" || scalar == "'" {
                endIndex = text.index(after: endIndex)
            } else {
                break
            }
        }

        let range = start..<endIndex
        let tokenText = String(text[range])

        return Token(text: tokenText, type: .word, range: range)
    }

    /// Extract contiguous whitespace
    private func extractWhitespace(from text: String, startingAt start: String.Index) -> Token {
        var endIndex = start

        while endIndex < text.endIndex {
            let char = text[endIndex]
            let unicodeScalars = char.unicodeScalars

            guard let scalar = unicodeScalars.first,
                  whitespaceChars.contains(scalar) else {
                break
            }

            endIndex = text.index(after: endIndex)
        }

        let range = start..<endIndex
        let tokenText = String(text[range])

        return Token(text: tokenText, type: .whitespace, range: range)
    }

    // MARK: - Utility Methods

    /// Get word tokens only (filter out whitespace/punctuation)
    func wordTokens(_ text: String) -> [Token] {
        return tokenize(text).filter { $0.isWord }
    }

    /// Reconstruct text from tokens
    func reconstruct(_ tokens: [Token]) -> String {
        return tokens.map { $0.text }.joined()
    }
}

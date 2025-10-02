//
//  ClaudeAPIClient.swift
//  BetterVoice
//
//  Anthropic Claude API client for cloud-based text enhancement
//  Conforms to LLMProvider protocol with 30s timeout (SR-008)
//

import Foundation

// MARK: - Protocol

protocol LLMProvider {
    func enhance(text: String, documentType: DocumentType, systemPrompt: String?) async throws -> String
}

// MARK: - Client Implementation

final class ClaudeAPIClient: LLMProvider {

    // MARK: - Properties

    private let apiKey: String
    private let endpoint: String
    private let model: String
    private let timeout: TimeInterval

    // MARK: - Initialization

    init(
        apiKey: String,
        endpoint: String = "https://api.anthropic.com/v1/messages",
        model: String = "claude-3-5-sonnet-20241022",
        timeout: TimeInterval = 30.0
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.timeout = timeout
    }

    // MARK: - LLMProvider Implementation

    func enhance(
        text: String,
        documentType: DocumentType,
        systemPrompt: String? = nil
    ) async throws -> String {
        // Create request
        let request = try createRequest(text: text, documentType: documentType, systemPrompt: systemPrompt)

        // Create URL session with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)

        // Send request
        let (data, response) = try await session.data(for: request)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: "Claude API returned status \(httpResponse.statusCode)")
        }

        // Parse response
        let enhancedText = try parseResponse(data)

        Logger.shared.info("Claude API enhancement completed: \(enhancedText.prefix(50))...")

        return enhancedText
    }

    // MARK: - Private Methods

    private func createRequest(
        text: String,
        documentType: DocumentType,
        systemPrompt: String?
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build system prompt
        let finalSystemPrompt = systemPrompt ?? getDefaultSystemPrompt(for: documentType)

        // Build request body
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": finalSystemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": "Please enhance the following transcribed text:\n\n\(text)"
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return request
    }

    private func parseResponse(_ data: Data) throws -> String {
        // Parse Claude API response format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.parseError("Failed to parse Claude API response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getDefaultSystemPrompt(for documentType: DocumentType) -> String {
        switch documentType {
        case .email:
            return """
            You are an expert email editor. Enhance the transcribed text to create a professional, well-formatted email.
            - Add proper greeting and closing if missing
            - Capitalize names and proper nouns
            - Format into clear paragraphs
            - Maintain the original intent and meaning
            - Keep it concise and professional
            """

        case .message:
            return """
            You are an expert at formatting casual messages. Enhance the transcribed text for instant messaging.
            - Keep the casual, friendly tone
            - Add minimal punctuation
            - Keep it concise
            - Maintain the original meaning
            """

        case .document:
            return """
            You are an expert document editor. Enhance the transcribed text for a professional document.
            - Format into clear paragraphs
            - Add proper punctuation and capitalization
            - Organize with headings if appropriate
            - Maintain formal, professional tone
            """

        case .searchQuery:
            return """
            You are an expert at formatting search queries. Enhance the transcribed text into an effective search query.
            - Extract key terms and concepts
            - Remove unnecessary words
            - Keep it concise (under 10 words)
            - Focus on searchable keywords
            """

        case .unknown:
            return """
            You are an expert text editor. Enhance the transcribed text with proper formatting.
            - Add proper punctuation and capitalization
            - Format into clear sentences
            - Maintain the original intent
            """
        }
    }
}

// MARK: - Error Types

enum LLMError: Error {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError(String)
    case timeout
    case networkError(Error)
}

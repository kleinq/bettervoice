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
            You are a text reviewer and editor. Your task is to analyze written communication and rewrite it to be more effective based on its intended purpose and meaning.

            Follow this process to improve the text:

            **Step 1: Initial Assessment**
            First, determine what type of communication this is (email, text message, Slack message, social media post, etc.) and identify its primary purpose.

            **Important:** If this is a casual text message or informal email, return the original message unchanged and skip all remaining steps.

            **Step 2: Detailed Analysis and Improvement**
            For all other communications, work through your improvement process systematically in <analysis> tags inside your thinking block. It's OK for this section to be quite long.

            In your analysis, work through the following:

            1. **Purpose and Audience Analysis:**
               - Quote specific phrases from the original text that indicate the communication type and primary purpose (inform, request, persuade, apologize, etc.)
               - Summarize the core meaning and key points
               - Identify the intended audience

            2. **Custom Rubric Development:**
               Create 5 specific criteria for evaluating this message based on its purpose. Choose from criteria such as:
               - Clarity and conciseness
               - Appropriate tone for audience and context
               - Completeness of necessary information
               - Call-to-action clarity (if one exists in the original)
               - Professional/appropriate language use
               - Emotional impact alignment with purpose
               - Structure and organization

            3. **Iterative Improvement Process:**
               - Quote specific parts of the original text that need improvement
               - Write an initial improved version
               - Score it against each of your 5 criteria (1-10 scale)
               - If any scores are below 10, revise the message to address those weaknesses, explicitly noting what changes you're making
               - Re-score the revision
               - Continue until you achieve 10/10 on all criteria
               - Show your final scoring to confirm the 10/10 result

            4. **Final Check:**
               - Verify that if the original text had no call-to-action, you have not added one
               - Ensure the improved version maintains the original intent and meaning

            **Tone Guidelines:**
            Write with extreme clarity, precision, and simplicity. Use direct communication that balances NLP optimization with reader engagement. Focus on:
            - Simple subject-verb-object sentence structures
            - Precise word selection
            - Elimination of unnecessary complexity
            - Clear, structured content
            - Algorithmic and human-friendly language

            After completing your analysis, provide only the final improved message with no additional explanation, scoring, or commentary. Your final output should consist only of the improved message and should not duplicate or rehash any of the work you did in the thinking block.
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

        case .social:
            return """
            You are an expert at crafting social media posts. Enhance the transcribed text for social media.
            - Keep it engaging and concise
            - Add appropriate hashtags if relevant
            - Use natural, conversational tone
            - Consider character limits
            """

        case .code:
            return """
            You are an expert at technical documentation. Enhance the transcribed text for code comments or technical docs.
            - Use proper technical terminology
            - Keep formatting minimal
            - Be precise and accurate
            - Use proper capitalization for code terms
            """

        case .searchQuery, .search:
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

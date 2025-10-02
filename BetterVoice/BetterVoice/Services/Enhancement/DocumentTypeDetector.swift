//
//  DocumentTypeDetector.swift
//  BetterVoice
//
//  Detects document type from frontmost application context
//  Target >85% accuracy (QR-002)
//

import Foundation
import AppKit

final class DocumentTypeDetector {

    // MARK: - Singleton

    static let shared = DocumentTypeDetector()

    // Public init for testing
    init() {}

    // MARK: - Public Methods

    // Main detection method that gets live context
    func detect() -> DocumentTypeContext {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmost?.bundleIdentifier ?? ""
        let appName = frontmost?.localizedName ?? "Unknown"

        // Get window title if available
        let windowTitle = getActiveWindowTitle()

        // Detect from bundle ID first (most reliable)
        if let (type, method, confidence) = detectFromBundleID(bundleID, windowTitle: windowTitle) {
            return DocumentTypeContext(
                documentType: type,
                detectionMethod: method,
                confidence: confidence,
                bundleID: bundleID,
                url: nil,
                appName: appName
            )
        }

        // Fallback to NLP detection (lower confidence)
        return DocumentTypeContext(
            documentType: .unknown,
            detectionMethod: .nlp,
            confidence: 0.5,
            bundleID: bundleID,
            url: nil,
            appName: appName
        )
    }

    // MARK: - Detection Methods

    private func detectFromBundleID(_ bundleID: String, windowTitle: String?) -> (DocumentType, DetectionMethod, Double)? {
        // Email applications
        if emailBundleIDs.contains(bundleID) {
            return (.email, .bundleID, 0.95)
        }

        // Message applications
        if messageBundleIDs.contains(bundleID) {
            return (.message, .bundleID, 0.95)
        }

        // Document/text editor applications
        if documentBundleIDs.contains(bundleID) {
            return (.document, .bundleID, 0.90)
        }

        // Browser applications (need URL analysis)
        if browserBundleIDs.contains(bundleID) {
            return detectFromBrowserContext(windowTitle: windowTitle)
        }

        return nil
    }

    private func detectFromBrowserContext(windowTitle: String?) -> (DocumentType, DetectionMethod, Double)? {
        guard let title = windowTitle else {
            return (.unknown, .nlp, 0.3)
        }

        let lowerTitle = title.lowercased()

        // Gmail
        if lowerTitle.contains("gmail") || lowerTitle.contains("inbox") || lowerTitle.contains("compose") {
            return (.email, .url, 0.90)
        }

        // Google Docs
        if lowerTitle.contains("google docs") || lowerTitle.contains("google drive") {
            return (.document, .url, 0.85)
        }

        // Slack web
        if lowerTitle.contains("slack") {
            return (.message, .url, 0.85)
        }

        // Search engines
        if lowerTitle.contains("google search") ||
           lowerTitle.contains("- google") ||
           lowerTitle.contains("bing") ||
           lowerTitle.contains("search") {
            return (.searchQuery, .url, 0.80)
        }

        return (.unknown, .nlp, 0.4)
    }

    private func getActiveWindowTitle() -> String? {
        // Use Accessibility API to get active window title
        // Note: Requires accessibility permissions
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // This is a simplified implementation
        // In production, you'd use AXUIElement APIs
        return app.localizedName
    }

    // MARK: - Bundle ID Mappings

    private let emailBundleIDs: Set<String> = [
        "com.apple.mail",
        "com.microsoft.Outlook",
        "com.readdle.smartemail-Mac",  // Spark
        "com.freron.MailMate",
        "com.postbox-inc.postboxapp"
    ]

    private let messageBundleIDs: Set<String> = [
        "com.apple.iChat",  // Messages
        "com.tinyspeck.slackmacgap",  // Slack
        "com.hnc.Discord",  // Discord
        "ru.keepcoder.Telegram",  // Telegram
        "net.whatsapp.WhatsApp",  // WhatsApp
        "com.microsoft.teams"  // Teams
    ]

    private let documentBundleIDs: Set<String> = [
        "com.apple.TextEdit",
        "com.apple.iWork.Pages",
        "com.microsoft.Word",
        "com.notion.id",  // Notion
        "net.shinyfrog.bear",  // Bear
        "md.obsidian",  // Obsidian
        "com.ulyssesapp.mac",  // Ulysses
        "com.codeux.irc.textual7",  // Textual
        "com.sublimetext.4"  // Sublime Text
    ]

    private let browserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera"
    ]
}

//
//  Logger.swift
//  BetterVoice
//
//  Centralized logging using os.Logger with file logging support
//  Respects user's log level preference
//

import Foundation
import OSLog

final class Logger {
    static let shared = Logger()

    private let osLogger: os.Logger
    private let fileLogger: FileLogger
    private var currentLogLevel: LogLevel

    private init() {
        // Initialize os.Logger with subsystem
        self.osLogger = os.Logger(subsystem: "com.bettervoice.BetterVoice", category: "app")

        // Initialize file logger
        self.fileLogger = FileLogger()

        // Load log level from preferences
        self.currentLogLevel = PreferencesStore.shared.preferences.logLevel
    }

    // MARK: - Logging Methods

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .error, message: fullMessage, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        // Check if should log based on current level
        guard shouldLog(level) else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"

        // Log to os_log
        switch level {
        case .debug:
            osLogger.debug("\(formattedMessage)")
        case .info:
            osLogger.info("\(formattedMessage)")
        case .warning:
            osLogger.warning("\(formattedMessage)")
        case .error:
            osLogger.error("\(formattedMessage)")
        }

        // Log to file
        fileLogger.log(level: level, message: formattedMessage)
    }

    private func shouldLog(_ level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        guard let currentIndex = levels.firstIndex(of: currentLogLevel),
              let messageIndex = levels.firstIndex(of: level) else {
            return true
        }
        return messageIndex >= currentIndex
    }

    // MARK: - Configuration

    func updateLogLevel(_ level: LogLevel) {
        currentLogLevel = level
    }

    func getLogFilePath() -> URL {
        return fileLogger.currentLogFileURL
    }

    func clearLogs() throws {
        try fileLogger.clearLogs()
    }
}

// MARK: - File Logger

private final class FileLogger {
    private let logsDirectory: URL
    private let dateFormatter: DateFormatter
    private let maxLogFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5

    var currentLogFileURL: URL {
        logsDirectory.appendingPathComponent("bettervoice.log")
    }

    init() {
        // Setup logs directory
        let logsRoot = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        logsDirectory = logsRoot
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("BetterVoice", isDirectory: true)

        // Create directory
        try? FileManager.default.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true
        )

        // Date formatter for timestamps
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func log(level: LogLevel, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"

        // Check file size and rotate if needed
        rotateLogIfNeeded()

        // Append to log file
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: currentLogFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: currentLogFileURL) {
                    defer { try? fileHandle.close() }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
            } else {
                // Create new file
                try? data.write(to: currentLogFileURL)
            }
        }
    }

    private func rotateLogIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: currentLogFileURL.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize >= maxLogFileSize else {
            return
        }

        // Rotate logs
        let timestamp = Int(Date().timeIntervalSince1970)
        let rotatedName = "bettervoice-\(timestamp).log"
        let rotatedURL = logsDirectory.appendingPathComponent(rotatedName)

        try? FileManager.default.moveItem(at: currentLogFileURL, to: rotatedURL)

        // Clean up old logs
        cleanupOldLogs()
    }

    private func cleanupOldLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let logFiles = files.filter { $0.pathExtension == "log" && $0.lastPathComponent != "bettervoice.log" }

        // Sort by creation date, oldest first
        let sortedFiles = logFiles.sorted { file1, file2 in
            guard let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                return false
            }
            return date1 < date2
        }

        // Delete oldest files if exceeding max count
        if sortedFiles.count > maxLogFiles {
            let filesToDelete = sortedFiles.prefix(sortedFiles.count - maxLogFiles)
            for file in filesToDelete {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func clearLogs() throws {
        // Delete current log file
        if FileManager.default.fileExists(atPath: currentLogFileURL.path) {
            try FileManager.default.removeItem(at: currentLogFileURL)
        }

        // Delete all rotated logs
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for file in files where file.pathExtension == "log" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

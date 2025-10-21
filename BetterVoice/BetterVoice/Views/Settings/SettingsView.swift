//
//  SettingsView.swift
//  BetterVoice
//
//  Settings window
//  TODO: Full implementation in later tasks
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            PermissionsTab()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            AudioFeedbackTab(preferencesStore: preferencesStore)
                .tabItem {
                    Label("Audio Feedback", systemImage: "speaker.wave.2")
                }

            ModelSettingsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            EnhancementTab()
                .tabItem {
                    Label("Enhancement", systemImage: "wand.and.stars")
                }

            PromptsTab()
                .tabItem {
                    Label("Prompts", systemImage: "text.quote")
                }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Placeholder Setting Tabs

struct GeneralSettingsView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hotkey")
                        .font(.headline)

                    HStack {
                        Text("Recording Hotkey:")
                        Spacer()
                        HotkeyRecorder(
                            keyCode: Binding(
                                get: { preferencesStore.preferences.hotkeyKeyCode },
                                set: { newValue in
                                    var updated = preferencesStore.preferences
                                    updated.hotkeyKeyCode = newValue
                                    preferencesStore.savePreferences(updated)
                                }
                            ),
                            modifiers: Binding(
                                get: { preferencesStore.preferences.hotkeyModifiers },
                                set: { newValue in
                                    var updated = preferencesStore.preferences
                                    updated.hotkeyModifiers = newValue
                                    preferencesStore.savePreferences(updated)
                                }
                            )
                        )
                    }
                    Text("Hold this key combination to record, release to transcribe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.headline)

                    Toggle("Launch at Login", isOn: .constant(false))
                        .disabled(true)
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)

                    HStack {
                        Text("Version:")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build:")
                        Spacer()
                        Text("2025.10.01")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Input")
                        .font(.headline)

                    HStack {
                        Text("Microphone:")
                        Spacer()
                        Text("Default")
                            .foregroundColor(.secondary)
                    }
                    Text("Using system default microphone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording")
                        .font(.headline)

                    HStack {
                        Text("Sample Rate:")
                        Spacer()
                        Text("16 kHz")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Quality:")
                        Spacer()
                        Text("High")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced")
                        .font(.headline)

                    Toggle("Noise Reduction", isOn: .constant(true))
                        .disabled(true)
                    Toggle("Auto Gain Control", isOn: .constant(true))
                        .disabled(true)
                    Text("Advanced audio settings coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
}

struct ModelSettingsView: View {
    @EnvironmentObject var preferencesStore: PreferencesStore
    @State private var models: [WhisperModel] = []
    @State private var downloadingModel: WhisperModelSize?
    @State private var downloadProgress: Double = 0.0
    @State private var downloadSession: URLSession?
    @State private var downloadDelegate: DownloadDelegate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Whisper Models")
                .font(.headline)
                .padding(.horizontal)

            List {
                ForEach(models) { model in
                    ModelRowView(
                        model: model,
                        isSelected: model.size == preferencesStore.preferences.selectedModelSize,
                        isDownloading: downloadingModel == model.size,
                        downloadProgress: downloadProgress,
                        onSelect: {
                            var updated = preferencesStore.preferences
                            updated.selectedModelSize = model.size
                            preferencesStore.savePreferences(updated)
                        },
                        onDownload: {
                            Task {
                                await downloadModel(model.size)
                            }
                        },
                        onDelete: {
                            Task {
                                await deleteModel(model.size)
                            }
                        }
                    )
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Storage info
            HStack {
                Text("Total Storage:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatStorageSize())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            refreshModels()
        }
    }

    private func refreshModels() {
        models = ModelStorage.shared.listAllModels()
    }

    private func downloadModel(_ size: WhisperModelSize) async {
        Logger.shared.info("Starting download for model: \(size.rawValue)")

        await MainActor.run {
            downloadingModel = size
            downloadProgress = 0.0
        }

        guard let url = ModelStorage.shared.getModelURL(for: size) else {
            Logger.shared.error("Failed to get URL for model: \(size.rawValue)")
            await MainActor.run {
                downloadingModel = nil
            }
            return
        }

        let destinationURL = ModelStorage.shared.getModelPath(for: size)

        // Create directory up front
        do {
            let directory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            Logger.shared.info("Ensured directory exists: \(directory.path)")
        } catch {
            Logger.shared.error("Failed to create directory", error: error)
            await MainActor.run {
                downloadingModel = nil
            }
            return
        }

        Logger.shared.info("Downloading from URL: \(url.absoluteString)")

        do {
            Logger.shared.info("Initiating download task...")

            // Create download task and wait for completion using ONLY delegate (no completion handler)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Create delegate with both progress and completion handlers
                let delegate = DownloadDelegate(
                    progressHandler: { progress in
                        Logger.shared.debug("Download progress for \(size.rawValue): \(String(format: "%.1f%%", progress * 100))")
                        DispatchQueue.main.async {
                            Task { @MainActor in
                                self.downloadProgress = progress
                            }
                        }
                    },
                    completionHandler: { location, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let location = location else {
                            continuation.resume(throwing: URLError(.badServerResponse))
                            return
                        }

                        // CRITICAL: Move file IMMEDIATELY inside delegate method before it's deleted
                        do {
                            Logger.shared.info("Moving file from \(location.path) to \(destinationURL.path)")

                            // Remove existing file if present
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }

                            // Move the temp file to destination
                            try FileManager.default.moveItem(at: location, to: destinationURL)
                            Logger.shared.info("File moved successfully")

                            continuation.resume()
                        } catch {
                            Logger.shared.error("Failed to move downloaded file", error: error)
                            continuation.resume(throwing: error)
                        }
                    }
                )

                // Store delegate and session to keep them alive
                Task { @MainActor in
                    self.downloadDelegate = delegate
                }

                // Use main queue for delegate callbacks
                let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)

                Task { @MainActor in
                    self.downloadSession = session
                }

                // Create download task WITHOUT completion handler - this allows delegate methods to work
                let task = session.downloadTask(with: url)
                task.resume()
            }

            Logger.shared.info("Model download completed successfully: \(size.rawValue)")

            await MainActor.run {
                downloadingModel = nil
                downloadProgress = 0.0
                downloadSession = nil
                downloadDelegate = nil
                refreshModels()
            }
        } catch {
            Logger.shared.error("Failed to download model \(size.rawValue)", error: error)
            await MainActor.run {
                downloadingModel = nil
                downloadProgress = 0.0
                downloadSession = nil
                downloadDelegate = nil
            }
        }
    }

    private func deleteModel(_ size: WhisperModelSize) async {
        do {
            try ModelStorage.shared.deleteModel(size)
            refreshModels()
        } catch {
            Logger.shared.error("Failed to delete model \(size.rawValue)", error: error)
        }
    }

    private func formatStorageSize() -> String{
        let bytes = ModelStorage.shared.getTotalStorageUsed()
        let gb = Double(bytes) / 1_073_741_824.0
        let mb = Double(bytes) / 1_048_576.0

        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

struct ModelRowView: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.size.rawValue.capitalized)
                        .font(.headline)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(model.displaySize)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if model.isDownloaded {
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            if isDownloading {
                ProgressView(value: downloadProgress)
                    .frame(width: 100)
            } else if model.isDownloaded {
                HStack(spacing: 8) {
                    Button("Select") {
                        onSelect()
                    }
                    .disabled(isSelected)

                    Button("Delete") {
                        onDelete()
                    }
                }
            } else {
                Button("Download") {
                    onDownload()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Download Delegate

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    private let completionHandler: (URL?, Error?) -> Void

    init(
        progressHandler: @escaping (Double) -> Void,
        completionHandler: @escaping (URL?, Error?) -> Void
    ) {
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Logger.shared.debug("URLSession progress: \(progress)")
        progressHandler(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Logger.shared.info("Download finished at: \(location.path)")
        completionHandler(location, nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Logger.shared.error("Download failed: \(error.localizedDescription)")
            completionHandler(nil, error)
        }
    }
}

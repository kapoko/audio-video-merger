import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

struct FileTypes {
    static let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
    static let audioExtensions = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma"]
}

@MainActor
final class DropViewModel: ObservableObject {
    @Published var droppedVideoURLs: [URL] = []
    @Published var droppedAudioURLs: [URL] = []
    @Published var isDragHovering = false
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var currentTask: String = ""
    @Published var currentJobIndex = 0
    @Published var totalJobs = 0
    @Published var successfulJobs = 0

    private let ffmpegProcessor = SimpleFFmpegProcessor()
    private var overwriteAllExistingFiles = false

    private var jobWeightsBytes: [Double] = []
    private var totalWeightBytes: Double = 1
    private var completedWeightBytes: Double = 0

    func statusText() -> String {
        if isDragHovering {
            return "Cast it into the fire! 🔥"
        }

        let hasVideos = !droppedVideoURLs.isEmpty
        let hasAudios = !droppedAudioURLs.isEmpty

        if hasVideos {
            return "Drop one or more audio files..."
        }

        if hasAudios {
            return "Drop one or more video files..."
        }

        return "Drop audio and video files"
    }

    func progressLabel() -> String {
        let jobText = totalJobs > 1 ? " (Job \(min(currentJobIndex + 1, totalJobs))/\(totalJobs))" : ""
        return String(format: "%.0f%% - %@%@", progress * 100, currentTask, jobText)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !isProcessing else {
            return false
        }

        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }

        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        var loadedURLs: [URL] = []
        let lock = NSLock()

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                item, _ in
                defer { group.leave() }

                guard let url = Self.extractURL(from: item) else {
                    return
                }

                lock.lock()
                loadedURLs.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.registerDroppedFiles(urls: loadedURLs)
        }

        return true
    }

    nonisolated private static func extractURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let nsURL = item as? NSURL {
            return nsURL as URL
        }

        if let data = item as? Data,
            let string = String(data: data, encoding: .utf8)
        {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: trimmed)
        }

        return nil
    }

    private func registerDroppedFiles(urls: [URL]) {
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()

            if FileTypes.videoExtensions.contains(fileExtension) {
                if !droppedVideoURLs.contains(url) {
                    droppedVideoURLs.append(url)
                }
            } else if FileTypes.audioExtensions.contains(fileExtension) {
                if !droppedAudioURLs.contains(url) {
                    droppedAudioURLs.append(url)
                }
            }
        }

        if !droppedVideoURLs.isEmpty && !droppedAudioURLs.isEmpty {
            startBatchProcessing()
        }
    }

    private func startBatchProcessing() {
        let jobs = createJobs()
        guard !jobs.isEmpty else {
            return
        }

        totalJobs = jobs.count
        currentJobIndex = 0
        successfulJobs = 0
        progress = 0
        currentTask = "Starting batch conversion..."
        isProcessing = true

        jobWeightsBytes = createJobWeights(for: jobs)
        totalWeightBytes = max(jobWeightsBytes.reduce(0, +), 1)
        completedWeightBytes = 0
        overwriteAllExistingFiles = false

        ffmpegProcessor.onProgressUpdate = { [weak self] localProgress, task in
            Task { @MainActor in
                self?.handleProgressUpdate(localProgress: localProgress, task: task)
            }
        }

        Task {
            await processJobs(jobs)
        }
    }

    private func handleProgressUpdate(localProgress: Double, task: String) {
        let currentWeight = weightForJob(at: currentJobIndex)
        let weightedProgress = (completedWeightBytes + localProgress * currentWeight) / totalWeightBytes
        progress = min(max(weightedProgress, 0), 1)
        currentTask = task
    }

    private func createJobs() -> [(videoURL: URL, audioURL: URL, outputURL: URL)] {
        var jobs: [(videoURL: URL, audioURL: URL, outputURL: URL)] = []

        for videoURL in droppedVideoURLs {
            for audioURL in droppedAudioURLs {
                let outputURL = createCombinedOutputPath(videoURL: videoURL, audioURL: audioURL)
                jobs.append((videoURL: videoURL, audioURL: audioURL, outputURL: outputURL))
            }
        }

        return jobs
    }

    private func createCombinedOutputPath(videoURL: URL, audioURL: URL) -> URL {
        let audioDirectory = audioURL.deletingLastPathComponent()
        let audioNameWithoutExtension = audioURL.deletingPathExtension().lastPathComponent
        let videoNameWithoutExtension = videoURL.deletingPathExtension().lastPathComponent
        let videoExtension = videoURL.pathExtension

        let outputFilename: String
        if droppedVideoURLs.count == 1 {
            outputFilename = "\(audioNameWithoutExtension).\(videoExtension)"
        } else if droppedAudioURLs.count == 1 {
            outputFilename = "\(videoNameWithoutExtension)_\(audioNameWithoutExtension).\(videoExtension)"
        } else {
            outputFilename = "\(videoNameWithoutExtension)_\(audioNameWithoutExtension).\(videoExtension)"
        }

        return audioDirectory.appendingPathComponent(outputFilename)
    }

    private func createJobWeights(for jobs: [(videoURL: URL, audioURL: URL, outputURL: URL)]) -> [Double] {
        jobs.map { job in
            let videoBytes = fileSizeInBytes(for: job.videoURL)
            let audioBytes = fileSizeInBytes(for: job.audioURL)
            return max(videoBytes + audioBytes, 1)
        }
    }

    private func fileSizeInBytes(for url: URL) -> Double {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

            if let byteCount = attributes[.size] as? NSNumber {
                return byteCount.doubleValue
            }

            if let byteCount = attributes[.size] as? Int {
                return Double(byteCount)
            }
        } catch {
            return 1
        }

        return 1
    }

    private func weightForJob(at index: Int) -> Double {
        guard index >= 0 && index < jobWeightsBytes.count else {
            return 1
        }
        return max(jobWeightsBytes[index], 1)
    }

    private func processJobs(_ jobs: [(videoURL: URL, audioURL: URL, outputURL: URL)]) async {
        for index in jobs.indices {
            currentJobIndex = index
            let job = jobs[index]

            let shouldProceed = await confirmOverwriteIfNeeded(for: job.outputURL)
            if !shouldProceed {
                finishBatchProcessing(showCompletionMessage: false)
                return
            }

            let result = await runJob(job)
            if case .success = result {
                successfulJobs += 1
            }

            completedWeightBytes += weightForJob(at: index)
        }

        finishBatchProcessing(showCompletionMessage: true)
    }

    private func runJob(_ job: (videoURL: URL, audioURL: URL, outputURL: URL)) async -> Result<URL, Error> {
        await withCheckedContinuation { continuation in
            ffmpegProcessor.processVideoAudio(
                videoURL: job.videoURL,
                audioURL: job.audioURL,
                outputURL: job.outputURL
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func confirmOverwriteIfNeeded(for outputURL: URL) async -> Bool {
        if overwriteAllExistingFiles {
            return true
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Overwrite?"
        alert.informativeText = "\(outputURL.lastPathComponent) already exists in this location. Do you want to overwrite it?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "Yes to All")
        alert.addButton(withTitle: "No")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return true
        }
        if response == .alertSecondButtonReturn {
            overwriteAllExistingFiles = true
            return true
        }
        return false
    }

    private func finishBatchProcessing(showCompletionMessage: Bool) {
        if showCompletionMessage {
            let videoLabel = successfulJobs == 1 ? "video" : "videos"
            progress = 1
            currentTask = "✅ Done! Created \(successfulJobs) \(videoLabel)"

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.resetProcessingState()
                }
            }
            return
        }

        resetProcessingState()
    }

    private func resetProcessingState() {
        isProcessing = false
        progress = 0
        currentTask = ""
        currentJobIndex = 0
        totalJobs = 0
        successfulJobs = 0

        jobWeightsBytes.removeAll()
        totalWeightBytes = 1
        completedWeightBytes = 0
        overwriteAllExistingFiles = false

        droppedVideoURLs.removeAll()
        droppedAudioURLs.removeAll()
    }
}

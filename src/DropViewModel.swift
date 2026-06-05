import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

enum DropPromptState: Equatable {
  case idle
  case needsAudio
  case needsVideo
  case hovering
}

enum ProgressOutcome {
  case none
  case success
  case failure
  case cancelled
}

@MainActor
final class DropViewModel: ObservableObject {
  static let shared = DropViewModel()

  @Published var droppedVideoURLs: [URL] = []
  @Published var droppedAudioURLs: [URL] = []
  @Published var isDragHovering = false
  @Published var isProcessing = false
  @Published var progress: Double = 0
  @Published var currentTask: String = ""
  @Published var currentJobIndex = 0
  @Published var totalJobs = 0
  @Published var successfulJobs = 0
  @Published var showUnrecognizedFilesAlert = false
  @Published var unrecognizedFilesMessage = ""
  @Published var progressOutcome: ProgressOutcome = .none

  private let batchConversion = BatchConversion()
  private var shouldShowJobIndex = false
  private var isCancellingConversion = false

  private var isAppBundle: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  func statusText() -> String {
    switch dropPromptState {
    case .idle:
      return "Drop audio and video files"
    case .needsAudio:
      return "Drop one or more audio files..."
    case .needsVideo:
      return "Drop one or more video files..."
    case .hovering:
      return "Cast it into the fire!"
    }
  }

  var dropPromptState: DropPromptState {
    if isDragHovering {
      return .hovering
    }

    if !droppedVideoURLs.isEmpty {
      return .needsAudio
    }

    if !droppedAudioURLs.isEmpty {
      return .needsVideo
    }

    return .idle
  }

  func progressLabel() -> String {
    currentTask
  }

  func jobProgressLabel() -> String? {
    guard shouldShowJobIndex && totalJobs > 1 else {
      return nil
    }

    return "\(min(currentJobIndex + 1, totalJobs))/\(totalJobs)"
  }

  var canCancelConversion: Bool {
    isProcessing && progressOutcome == .none && !isCancellingConversion
  }

  func statusSymbolName() -> String? {
    switch dropPromptState {
    case .hovering:
      return "flame.fill"
    default:
      return nil
    }
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
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
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

  func handleDroppedFileURLs(_ urls: [URL]) {
    guard !isProcessing else {
      return
    }

    registerDroppedFiles(urls: urls)
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
    let intakeResult = batchConversion.registerDroppedFiles(urls: urls)
    droppedVideoURLs = intakeResult.videoURLs
    droppedAudioURLs = intakeResult.audioURLs

    if !intakeResult.unrecognizedURLs.isEmpty {
      let fileNames = intakeResult.unrecognizedURLs.map(\.lastPathComponent)
      let visibleNames = fileNames.prefix(5)
      let baseMessage = visibleNames.joined(separator: "\n")

      if fileNames.count > visibleNames.count {
        unrecognizedFilesMessage =
          "These files are not supported:\n\n\(baseMessage)\n\n... and \(fileNames.count - visibleNames.count) more"
      } else {
        unrecognizedFilesMessage = "These files are not supported:\n\n\(baseMessage)"
      }

      showUnrecognizedFilesAlert = true
    }

    if intakeResult.isReady {
      print("[DropViewModel] Valid batch detected: \(intakeResult.totalJobCount) output job(s)")
    }

    if intakeResult.isReady {
      startBatchProcessing()
    }
  }

  private func startBatchProcessing() {
    Task {
      let jobMode = await resolveJobCreationMode()
      let plan = batchConversion.createPlan(mode: jobMode)
      guard !plan.jobs.isEmpty else {
        return
      }

      totalJobs = plan.jobs.count
      currentJobIndex = 0
      successfulJobs = 0
      progress = 0
      currentTask = "Starting batch conversion..."
      progressOutcome = .none
      isCancellingConversion = false
      isProcessing = true
      shouldShowJobIndex = true

      let outcome = await batchConversion.run(
        plan: plan,
        overwriteDecision: { [weak self] outputURL in
          guard let self else { return .stop }
          return await self.confirmOverwriteIfNeeded(for: outputURL)
        },
        progressUpdate: { [weak self] runProgress in
          Task { @MainActor in
            self?.handleProgressUpdate(runProgress)
          }
        }
      )

      finishBatchProcessing(outcome: outcome)
    }
  }

  private func resolveJobCreationMode() async -> BatchConversionJobMode {
    guard let suggestedPairs = suggestedPairingsIfConfident() else {
      return .allCombinations
    }

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Pair up?"
    alert.informativeText =
      "You added a similar number of audio files to video files. Do you want to make pairs?"
    alert.addButton(withTitle: "Yes")
    alert.addButton(withTitle: "No")

    try? await Task.sleep(nanoseconds: 200_000_000)
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      return .suggestedPairs(suggestedPairs)
    }

    return .allCombinations
  }

  func cancelConversion() {
    guard canCancelConversion else {
      return
    }

    isCancellingConversion = true
    currentTask = "Cancelling..."
    batchConversion.cancel()
  }

  private func handleProgressUpdate(_ runProgress: BatchConversionRunProgress) {
    if !isCancellingConversion {
      progress = runProgress.progress
      currentTask = runProgress.currentTask
    }
    currentJobIndex = runProgress.currentJobIndex
    totalJobs = runProgress.totalJobs
    successfulJobs = runProgress.successfulJobs
  }

  private func suggestedPairingsIfConfident() -> [BatchConversionPair]? {
    batchConversion.suggestedPairingsIfConfident()
  }

  private func confirmOverwriteIfNeeded(for outputURL: URL) async
    -> BatchConversionOverwriteDecision
  {
    guard batchConversion.fileExists(at: outputURL) else {
      return .overwrite
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Overwrite?"
    alert.informativeText =
      "\(outputURL.lastPathComponent) already exists in this location. Do you want to overwrite it?"
    alert.addButton(withTitle: "Yes")
    alert.addButton(withTitle: "Yes to All")
    alert.addButton(withTitle: "No")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      return .overwrite
    }
    if response == .alertSecondButtonReturn {
      return .overwriteAll
    }
    return .stop
  }

  private func finishBatchProcessing(outcome: BatchConversionRunOutcome) {
    let shouldNotify: Bool
    switch outcome {
    case .completed(let processed, let total, _):
      successfulJobs = processed
      totalJobs = total
      let hasFailures = processed < total
      let videoLabel = processed == 1 ? "video" : "videos"
      progress = 1
      currentTask =
        hasFailures
        ? "Failed. Created \(processed) \(videoLabel)" : "Done! Created \(processed) \(videoLabel)"
      progressOutcome = hasFailures ? .failure : .success
      shouldNotify = true
    case .cancelled(let processed, let total, _):
      successfulJobs = processed
      totalJobs = total
      let videoLabel = processed == 1 ? "video" : "videos"
      currentTask = "Cancelled. Created \(processed) \(videoLabel)"
      progressOutcome = .cancelled
      shouldNotify = false
    }

    shouldShowJobIndex = false

    if shouldNotify {
      let hasFailures = successfulJobs < totalJobs
      sendCompletionNotification(
        processed: successfulJobs, total: totalJobs, hasFailures: hasFailures)
    }

    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      await MainActor.run {
        self.resetProcessingState()
      }
    }
  }

  private func sendCompletionNotification(processed: Int, total: Int, hasFailures: Bool) {
    guard isAppBundle else {
      return
    }

    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = hasFailures ? "Merging finished with failures" : "Merging videos complete"
    content.body =
      hasFailures
      ? "Created \(processed) of \(total) videos."
      : "✅ Created \(processed) of \(total) videos."
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    center.add(request) { error in
      if let error {
        print(
          "[Notifications] Failed to schedule completion notification: \(error.localizedDescription)"
        )
      }
    }
  }

  private func resetProcessingState() {
    isProcessing = false
    progress = 0
    currentTask = ""
    progressOutcome = .none
    isCancellingConversion = false
    showUnrecognizedFilesAlert = false
    unrecognizedFilesMessage = ""
    shouldShowJobIndex = false
    currentJobIndex = 0
    totalJobs = 0
    successfulJobs = 0

    droppedVideoURLs.removeAll()
    droppedAudioURLs.removeAll()
    batchConversion.reset()
  }
}

import Foundation

struct BatchConversionPair: Equatable {
  let videoURL: URL
  let audioURL: URL
}

struct BatchConversionJob: Equatable {
  let videoURL: URL
  let audioURL: URL
  let outputURL: URL
}

struct BatchConversionPlan: Equatable {
  let jobs: [BatchConversionJob]
  let jobWeightsBytes: [Double]
  let totalWeightBytes: Double
  let existingOutputURLs: [URL]
}

struct BatchConversionFailedJob: Equatable {
  enum Reason: Equatable {
    case temporaryOutputAlreadyExists
    case processingFailed
    case replacementFailed
  }

  let job: BatchConversionJob
  let reason: Reason
}

struct BatchConversionRunProgress: Equatable {
  let progress: Double
  let currentTask: String
  let currentJobIndex: Int
  let totalJobs: Int
  let successfulJobs: Int
}

enum BatchConversionRunOutcome: Equatable {
  case completed(successfulJobs: Int, totalJobs: Int, failedJobs: [BatchConversionFailedJob])
  case cancelled(successfulJobs: Int, totalJobs: Int, failedJobs: [BatchConversionFailedJob])
}

enum BatchConversionOverwriteDecision: Equatable {
  case overwrite
  case overwriteAll
  case stop
}

struct BatchConversionIntakeResult: Equatable {
  let audioURLs: [URL]
  let videoURLs: [URL]
  let unrecognizedURLs: [URL]
  let totalJobCount: Int

  var isReady: Bool {
    !audioURLs.isEmpty && !videoURLs.isEmpty
  }
}

enum BatchConversionJobMode: Equatable {
  case allCombinations
  case suggestedPairs([BatchConversionPair])
}

protocol BatchConversionFileSystem {
  func fileSizeInBytes(for url: URL) -> Double
  func fileExists(at url: URL) -> Bool
  func temporaryOutputURL(for outputURL: URL) -> URL
  func removeItem(at url: URL)
  func replaceItem(at outputURL: URL, withItemAt temporaryURL: URL) throws
}

protocol BatchConversionFFmpegProcessor {
  @discardableResult
  func processVideoAudio(
    videoURL: URL,
    audioURL: URL,
    outputURL: URL,
    onProgressUpdate: @escaping (Double, String) -> Void,
    completion: @escaping (Result<URL, Error>) -> Void
  ) -> BatchConversionCancellableProcess
}

protocol BatchConversionCancellableProcess: AnyObject {
  func cancel()
}

struct LocalBatchConversionFileSystem: BatchConversionFileSystem {
  func fileSizeInBytes(for url: URL) -> Double {
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

  func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  func temporaryOutputURL(for outputURL: URL) -> URL {
    let directory = outputURL.deletingLastPathComponent()
    let baseName = outputURL.deletingPathExtension().lastPathComponent
    let fileExtension = outputURL.pathExtension
    let token = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
      .lowercased()
    let filename = "\(baseName).avm-\(token).tmp.\(fileExtension)"
    return directory.appendingPathComponent(filename)
  }

  func removeItem(at url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  func replaceItem(at outputURL: URL, withItemAt temporaryURL: URL) throws {
    if fileExists(at: outputURL) {
      _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporaryURL)
    } else {
      try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    }
  }
}

final class BatchConversion {
  private let pairingMatcher: FilePairingMatcher
  private let fileSystem: BatchConversionFileSystem
  private let ffmpegProcessor: BatchConversionFFmpegProcessor

  private var isCancelRequested = false
  private var activeProcess: BatchConversionCancellableProcess?

  private(set) var videoURLs: [URL] = []
  private(set) var audioURLs: [URL] = []

  init(
    pairingMatcher: FilePairingMatcher = FilePairingMatcher(),
    fileSystem: BatchConversionFileSystem = LocalBatchConversionFileSystem(),
    ffmpegProcessor: BatchConversionFFmpegProcessor = SimpleFFmpegProcessor()
  ) {
    self.pairingMatcher = pairingMatcher
    self.fileSystem = fileSystem
    self.ffmpegProcessor = ffmpegProcessor
  }

  @discardableResult
  func registerDroppedFiles(urls: [URL]) -> BatchConversionIntakeResult {
    let validation = FileValidator.validate(urls: urls)

    for url in validation.videoURLs where !videoURLs.contains(url) {
      videoURLs.append(url)
    }

    for url in validation.audioURLs where !audioURLs.contains(url) {
      audioURLs.append(url)
    }

    return BatchConversionIntakeResult(
      audioURLs: audioURLs,
      videoURLs: videoURLs,
      unrecognizedURLs: validation.unrecognizedURLs,
      totalJobCount: audioURLs.count * videoURLs.count
    )
  }

  func suggestedPairingsIfConfident() -> [BatchConversionPair]? {
    pairingMatcher.suggestedPairs(videos: videoURLs, audios: audioURLs)?.map {
      BatchConversionPair(videoURL: $0.videoURL, audioURL: $0.audioURL)
    }
  }

  func createPlan(mode: BatchConversionJobMode) -> BatchConversionPlan {
    let jobs = createJobs(mode: mode)
    let weights = jobs.map { job in
      let videoBytes = fileSystem.fileSizeInBytes(for: job.videoURL)
      let audioBytes = fileSystem.fileSizeInBytes(for: job.audioURL)
      return max(videoBytes + audioBytes, 1)
    }
    let existingOutputURLs = jobs.map(\.outputURL).filter(fileSystem.fileExists(at:))

    return BatchConversionPlan(
      jobs: jobs,
      jobWeightsBytes: weights,
      totalWeightBytes: max(weights.reduce(0, +), 1),
      existingOutputURLs: existingOutputURLs
    )
  }

  func fileExists(at url: URL) -> Bool {
    fileSystem.fileExists(at: url)
  }

  func run(
    plan: BatchConversionPlan,
    overwriteDecision: (URL) async -> BatchConversionOverwriteDecision,
    progressUpdate: @escaping (BatchConversionRunProgress) -> Void
  ) async -> BatchConversionRunOutcome {
    isCancelRequested = false
    activeProcess = nil

    var successfulJobs = 0
    var failedJobs: [BatchConversionFailedJob] = []
    var completedWeightBytes: Double = 0
    var overwriteAllExistingFiles = false
    let totalJobs = plan.jobs.count
    let totalWeightBytes = max(plan.totalWeightBytes, 1)

    for index in plan.jobs.indices {
      if isCancelRequested {
        return .cancelled(
          successfulJobs: successfulJobs, totalJobs: totalJobs, failedJobs: failedJobs)
      }

      let job = plan.jobs[index]
      let currentWeight = weightForJob(at: index, in: plan)
      var lastLocalProgress: Double = 0
      progressUpdate(
        BatchConversionRunProgress(
          progress: min(max(completedWeightBytes / totalWeightBytes, 0), 1),
          currentTask: "Converting...",
          currentJobIndex: index,
          totalJobs: totalJobs,
          successfulJobs: successfulJobs
        ))

      if fileSystem.fileExists(at: job.outputURL) && !overwriteAllExistingFiles {
        let decision = await overwriteDecision(job.outputURL)
        switch decision {
        case .overwrite:
          break
        case .overwriteAll:
          overwriteAllExistingFiles = true
        case .stop:
          return .cancelled(
            successfulJobs: successfulJobs, totalJobs: totalJobs, failedJobs: failedJobs)
        }
      }

      let temporaryOutputURL = fileSystem.temporaryOutputURL(for: job.outputURL)
      guard !fileSystem.fileExists(at: temporaryOutputURL) else {
        failedJobs.append(
          BatchConversionFailedJob(job: job, reason: .temporaryOutputAlreadyExists))
        completedWeightBytes += currentWeight
        continue
      }

      let result = await runJob(
        job,
        temporaryOutputURL: temporaryOutputURL
      ) { localProgress, task in
        let normalizedLocalProgress = min(max(localProgress, 0), 1)
        lastLocalProgress = max(lastLocalProgress, normalizedLocalProgress)
        let weightedProgress =
          (completedWeightBytes + lastLocalProgress * currentWeight) / totalWeightBytes
        progressUpdate(
          BatchConversionRunProgress(
            progress: min(max(weightedProgress, 0), 1),
            currentTask: task,
            currentJobIndex: index,
            totalJobs: totalJobs,
            successfulJobs: successfulJobs
          ))
      }

      activeProcess = nil

      if isCancelRequested {
        fileSystem.removeItem(at: temporaryOutputURL)
        return .cancelled(
          successfulJobs: successfulJobs, totalJobs: totalJobs, failedJobs: failedJobs)
      }

      switch result {
      case .success:
        do {
          try fileSystem.replaceItem(at: job.outputURL, withItemAt: temporaryOutputURL)
          successfulJobs += 1
        } catch {
          fileSystem.removeItem(at: temporaryOutputURL)
          failedJobs.append(BatchConversionFailedJob(job: job, reason: .replacementFailed))
        }
      case .failure:
        fileSystem.removeItem(at: temporaryOutputURL)
        failedJobs.append(BatchConversionFailedJob(job: job, reason: .processingFailed))
      }

      completedWeightBytes += currentWeight
    }

    return .completed(successfulJobs: successfulJobs, totalJobs: totalJobs, failedJobs: failedJobs)
  }

  func cancel() {
    isCancelRequested = true
    activeProcess?.cancel()
  }

  func reset() {
    cancel()
    activeProcess = nil
    isCancelRequested = false
    videoURLs.removeAll()
    audioURLs.removeAll()
  }

  private func runJob(
    _ job: BatchConversionJob,
    temporaryOutputURL: URL,
    onProgressUpdate: @escaping (Double, String) -> Void
  ) async -> Result<URL, Error> {
    await withCheckedContinuation { continuation in
      let process = ffmpegProcessor.processVideoAudio(
        videoURL: job.videoURL,
        audioURL: job.audioURL,
        outputURL: temporaryOutputURL,
        onProgressUpdate: onProgressUpdate
      ) { result in
        continuation.resume(returning: result)
      }
      activeProcess = process
      if isCancelRequested {
        process.cancel()
      }
    }
  }

  private func weightForJob(at index: Int, in plan: BatchConversionPlan) -> Double {
    guard index >= 0 && index < plan.jobWeightsBytes.count else {
      return 1
    }
    return max(plan.jobWeightsBytes[index], 1)
  }

  private func createJobs(mode: BatchConversionJobMode) -> [BatchConversionJob] {
    switch mode {
    case .allCombinations:
      return videoURLs.flatMap { videoURL in
        audioURLs.map { audioURL in
          BatchConversionJob(
            videoURL: videoURL,
            audioURL: audioURL,
            outputURL: createCombinedOutputPath(videoURL: videoURL, audioURL: audioURL)
          )
        }
      }
    case .suggestedPairs(let pairs):
      return pairs.map { pair in
        BatchConversionJob(
          videoURL: pair.videoURL,
          audioURL: pair.audioURL,
          outputURL: createPairedOutputPath(videoURL: pair.videoURL, audioURL: pair.audioURL)
        )
      }
    }
  }

  private func createCombinedOutputPath(videoURL: URL, audioURL: URL) -> URL {
    let audioDirectory = audioURL.deletingLastPathComponent()
    let audioNameWithoutExtension = audioURL.deletingPathExtension().lastPathComponent
    let videoNameWithoutExtension = videoURL.deletingPathExtension().lastPathComponent
    let videoExtension = videoURL.pathExtension

    let outputFilename: String
    if videoURLs.count == 1 {
      outputFilename = "\(audioNameWithoutExtension).\(videoExtension)"
    } else {
      outputFilename = "\(videoNameWithoutExtension)_\(audioNameWithoutExtension).\(videoExtension)"
    }

    return audioDirectory.appendingPathComponent(outputFilename)
  }

  private func createPairedOutputPath(videoURL: URL, audioURL: URL) -> URL {
    let audioDirectory = audioURL.deletingLastPathComponent()
    let audioNameWithoutExtension = audioURL.deletingPathExtension().lastPathComponent
    let videoExtension = videoURL.pathExtension
    let outputFilename = "\(audioNameWithoutExtension).\(videoExtension)"
    return audioDirectory.appendingPathComponent(outputFilename)
  }
}

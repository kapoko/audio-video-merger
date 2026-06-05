import XCTest

@testable import AudioVideoMerger

final class BatchConversionTests: XCTestCase {
  func testRegisterDroppedFilesClassifiesAndDeduplicatesAcceptedFiles() {
    let conversion = BatchConversion(fileSystem: FakeBatchConversionFileSystem())
    let video = URL(fileURLWithPath: "/tmp/clip.mp4")
    let audio = URL(fileURLWithPath: "/tmp/track.wav")
    let unsupported = URL(fileURLWithPath: "/tmp/readme.txt")

    let firstResult = conversion.registerDroppedFiles(urls: [video, audio, unsupported])
    let secondResult = conversion.registerDroppedFiles(urls: [video, audio])

    XCTAssertTrue(firstResult.isReady)
    XCTAssertEqual(firstResult.videoURLs, [video])
    XCTAssertEqual(firstResult.audioURLs, [audio])
    XCTAssertEqual(firstResult.unrecognizedURLs, [unsupported])
    XCTAssertEqual(firstResult.totalJobCount, 1)
    XCTAssertEqual(secondResult.videoURLs, [video])
    XCTAssertEqual(secondResult.audioURLs, [audio])
  }

  func testCreatePlanNamesSingleVideoMultipleAudioOutputsFromAudioNames() {
    let conversion = BatchConversion(fileSystem: FakeBatchConversionFileSystem())
    let video = URL(fileURLWithPath: "/video/clip.mp4")
    let firstAudio = URL(fileURLWithPath: "/audio/song1.wav")
    let secondAudio = URL(fileURLWithPath: "/audio/song2.wav")

    conversion.registerDroppedFiles(urls: [video, firstAudio, secondAudio])

    let plan = conversion.createPlan(mode: .allCombinations)

    XCTAssertEqual(
      plan.jobs.map(\.outputURL),
      [
        URL(fileURLWithPath: "/audio/song1.mp4"),
        URL(fileURLWithPath: "/audio/song2.mp4"),
      ])
  }

  func testCreatePlanNamesMultipleVideoOutputsFromVideoAndAudioNames() {
    let conversion = BatchConversion(fileSystem: FakeBatchConversionFileSystem())
    let firstVideo = URL(fileURLWithPath: "/video/clip1.mov")
    let secondVideo = URL(fileURLWithPath: "/video/clip2.mov")
    let audio = URL(fileURLWithPath: "/audio/music.wav")

    conversion.registerDroppedFiles(urls: [firstVideo, secondVideo, audio])

    let plan = conversion.createPlan(mode: .allCombinations)

    XCTAssertEqual(
      plan.jobs.map(\.outputURL),
      [
        URL(fileURLWithPath: "/audio/clip1_music.mov"),
        URL(fileURLWithPath: "/audio/clip2_music.mov"),
      ])
  }

  func testCreatePlanUsesSuggestedPairsForPairedOutputNames() {
    let conversion = BatchConversion(fileSystem: FakeBatchConversionFileSystem())
    let firstVideo = URL(fileURLWithPath: "/video/red.mp4")
    let secondVideo = URL(fileURLWithPath: "/video/blue.mp4")
    let firstAudio = URL(fileURLWithPath: "/audio/red.wav")
    let secondAudio = URL(fileURLWithPath: "/audio/blue.wav")
    let pairs = [
      BatchConversionPair(videoURL: secondVideo, audioURL: secondAudio),
      BatchConversionPair(videoURL: firstVideo, audioURL: firstAudio),
    ]

    conversion.registerDroppedFiles(urls: [firstVideo, secondVideo, firstAudio, secondAudio])

    let plan = conversion.createPlan(mode: .suggestedPairs(pairs))

    XCTAssertEqual(
      plan.jobs.map(\.outputURL),
      [
        URL(fileURLWithPath: "/audio/blue.mp4"),
        URL(fileURLWithPath: "/audio/red.mp4"),
      ])
  }

  func testCreatePlanComputesWeightsAndExistingOutputsThroughFileSystemAdapter() {
    let video = URL(fileURLWithPath: "/video/clip.mp4")
    let audio = URL(fileURLWithPath: "/audio/song.wav")
    let output = URL(fileURLWithPath: "/audio/song.mp4")
    let fileSystem = FakeBatchConversionFileSystem(
      sizes: [video: 40, audio: 2],
      existingURLs: [output]
    )
    let conversion = BatchConversion(fileSystem: fileSystem)

    conversion.registerDroppedFiles(urls: [video, audio])

    let plan = conversion.createPlan(mode: .allCombinations)

    XCTAssertEqual(plan.jobWeightsBytes, [42])
    XCTAssertEqual(plan.totalWeightBytes, 42)
    XCTAssertEqual(plan.existingOutputURLs, [output])
  }

  func testRunWritesToTemporaryOutputThenReplacesFinalOutput() async {
    let video = URL(fileURLWithPath: "/video/clip.mp4")
    let audio = URL(fileURLWithPath: "/audio/song.wav")
    let output = URL(fileURLWithPath: "/audio/song.mp4")
    let temporaryOutput = URL(fileURLWithPath: "/audio/song.avm-a1b2c3d4.tmp.mp4")
    let fileSystem = FakeBatchConversionFileSystem(temporaryURLs: [output: temporaryOutput])
    let ffmpegProcessor = FakeBatchConversionFFmpegProcessor()
    let conversion = BatchConversion(fileSystem: fileSystem, ffmpegProcessor: ffmpegProcessor)

    conversion.registerDroppedFiles(urls: [video, audio])
    let plan = conversion.createPlan(mode: .allCombinations)

    let outcome = await conversion.run(
      plan: plan,
      overwriteDecision: { _ in .overwrite },
      progressUpdate: { _ in }
    )

    XCTAssertEqual(ffmpegProcessor.outputURLs, [temporaryOutput])
    XCTAssertEqual(fileSystem.replacements, [output: temporaryOutput])
    XCTAssertEqual(outcome, .completed(successfulJobs: 1, totalJobs: 1, failedJobs: []))
  }

  func testRunFailsJobWhenTemporaryOutputAlreadyExists() async {
    let video = URL(fileURLWithPath: "/video/clip.mp4")
    let audio = URL(fileURLWithPath: "/audio/song.wav")
    let output = URL(fileURLWithPath: "/audio/song.mp4")
    let temporaryOutput = URL(fileURLWithPath: "/audio/song.avm-a1b2c3d4.tmp.mp4")
    let fileSystem = FakeBatchConversionFileSystem(
      existingURLs: [temporaryOutput],
      temporaryURLs: [output: temporaryOutput]
    )
    let ffmpegProcessor = FakeBatchConversionFFmpegProcessor()
    let conversion = BatchConversion(fileSystem: fileSystem, ffmpegProcessor: ffmpegProcessor)

    conversion.registerDroppedFiles(urls: [video, audio])
    let plan = conversion.createPlan(mode: .allCombinations)

    let outcome = await conversion.run(
      plan: plan,
      overwriteDecision: { _ in .overwrite },
      progressUpdate: { _ in }
    )

    XCTAssertTrue(ffmpegProcessor.outputURLs.isEmpty)
    XCTAssertEqual(
      outcome,
      .completed(
        successfulJobs: 0,
        totalJobs: 1,
        failedJobs: [
          BatchConversionFailedJob(job: plan.jobs[0], reason: .temporaryOutputAlreadyExists)
        ]
      )
    )
  }

  func testCancelStopsActiveJobAndRemovesTemporaryOutput() async {
    let video = URL(fileURLWithPath: "/video/clip.mp4")
    let audio = URL(fileURLWithPath: "/audio/song.wav")
    let output = URL(fileURLWithPath: "/audio/song.mp4")
    let temporaryOutput = URL(fileURLWithPath: "/audio/song.avm-a1b2c3d4.tmp.mp4")
    let fileSystem = FakeBatchConversionFileSystem(temporaryURLs: [output: temporaryOutput])
    let ffmpegProcessor = FakeBatchConversionFFmpegProcessor(shouldCompleteAutomatically: false)
    let conversion = BatchConversion(fileSystem: fileSystem, ffmpegProcessor: ffmpegProcessor)

    conversion.registerDroppedFiles(urls: [video, audio])
    let plan = conversion.createPlan(mode: .allCombinations)

    let task = Task {
      await conversion.run(
        plan: plan,
        overwriteDecision: { _ in .overwrite },
        progressUpdate: { _ in }
      )
    }

    while ffmpegProcessor.activeHandle == nil {
      await Task.yield()
    }

    conversion.cancel()
    ffmpegProcessor.complete(.failure(SimpleFFmpegProcessor.ProcessingError.processingFailed))
    let outcome = await task.value

    XCTAssertEqual(ffmpegProcessor.activeHandle?.isCancelled, true)
    XCTAssertEqual(fileSystem.removedURLs, [temporaryOutput])
    XCTAssertEqual(outcome, .cancelled(successfulJobs: 0, totalJobs: 1, failedJobs: []))
  }
}

private final class FakeBatchConversionFileSystem: BatchConversionFileSystem {
  var sizes: [URL: Double] = [:]
  var existingURLs: Set<URL> = []
  var temporaryURLs: [URL: URL] = [:]
  var removedURLs: [URL] = []
  var replacements: [URL: URL] = [:]

  init(
    sizes: [URL: Double] = [:],
    existingURLs: Set<URL> = [],
    temporaryURLs: [URL: URL] = [:]
  ) {
    self.sizes = sizes
    self.existingURLs = existingURLs
    self.temporaryURLs = temporaryURLs
  }

  func fileSizeInBytes(for url: URL) -> Double {
    sizes[url] ?? 1
  }

  func fileExists(at url: URL) -> Bool {
    existingURLs.contains(url)
  }

  func temporaryOutputURL(for outputURL: URL) -> URL {
    temporaryURLs[outputURL] ?? outputURL.appendingPathExtension("tmp")
  }

  func removeItem(at url: URL) {
    removedURLs.append(url)
  }

  func replaceItem(at outputURL: URL, withItemAt temporaryURL: URL) throws {
    replacements[outputURL] = temporaryURL
  }
}

private final class FakeBatchConversionFFmpegProcessor: BatchConversionFFmpegProcessor {
  let shouldCompleteAutomatically: Bool
  var outputURLs: [URL] = []
  var completion: ((Result<URL, Error>) -> Void)?
  var activeHandle: FakeBatchConversionCancellableProcess?

  init(shouldCompleteAutomatically: Bool = true) {
    self.shouldCompleteAutomatically = shouldCompleteAutomatically
  }

  func processVideoAudio(
    videoURL: URL,
    audioURL: URL,
    outputURL: URL,
    onProgressUpdate: @escaping (Double, String) -> Void,
    completion: @escaping (Result<URL, Error>) -> Void
  ) -> BatchConversionCancellableProcess {
    outputURLs.append(outputURL)
    self.completion = completion
    let handle = FakeBatchConversionCancellableProcess()
    activeHandle = handle
    onProgressUpdate(0.5, "Converting...")

    if shouldCompleteAutomatically {
      completion(.success(outputURL))
    }

    return handle
  }

  func complete(_ result: Result<URL, Error>) {
    completion?(result)
  }
}

private final class FakeBatchConversionCancellableProcess: BatchConversionCancellableProcess {
  private(set) var isCancelled = false

  func cancel() {
    isCancelled = true
  }
}

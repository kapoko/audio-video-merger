import Darwin
import Foundation

class SimpleFFmpegProcessor {

  enum ProcessingError: Error {
    case ffmpegNotFound
    case invalidFiles
    case processingFailed
  }

  var onProgressUpdate: ((Double, String) -> Void)?
  private var totalDuration: TimeInterval = 0

  private func log(_ message: String) {
    print("[FFmpegProcessor] \(message)")
  }

  func processVideoAudio(
    videoURL: URL, audioURL: URL, completion: @escaping (Result<URL, Error>) -> Void
  ) {
    let outputPath = createOutputPath(from: audioURL, videoURL: videoURL)
    processVideoAudio(
      videoURL: videoURL, audioURL: audioURL, outputURL: outputPath, completion: completion)
  }

  func processVideoAudio(
    videoURL: URL, audioURL: URL, outputURL: URL,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      self.executeFFmpeg(
        videoURL: videoURL, audioURL: audioURL, outputURL: outputURL, completion: completion
      )
    }
  }

  private func createOutputPath(from audioURL: URL, videoURL: URL) -> URL {
    let audioDirectory = audioURL.deletingLastPathComponent()
    let audioNameWithoutExtension = audioURL.deletingPathExtension().lastPathComponent
    let videoExtension = videoURL.pathExtension

    let outputFilename = "\(audioNameWithoutExtension).\(videoExtension)"
    return audioDirectory.appendingPathComponent(outputFilename)
  }

  private func executeFFmpeg(
    videoURL: URL, audioURL: URL, outputURL: URL,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    let ffmpegPath = getFFmpegPath()
    log("Preparing conversion")
    log("Video: \(videoURL.path)")
    log("Audio: \(audioURL.path)")
    log("Output: \(outputURL.path)")
    log("FFmpeg path: \(ffmpegPath)")

    guard FileManager.default.fileExists(atPath: ffmpegPath) else {
      log("FFmpeg not found at expected path")
      completion(.failure(ProcessingError.ffmpegNotFound))
      return
    }

    runFFmpegConversion(
      ffmpegPath: ffmpegPath, videoURL: videoURL, audioURL: audioURL, outputURL: outputURL,
      completion: completion)
  }

  private func runFFmpegConversion(
    ffmpegPath: String, videoURL: URL, audioURL: URL, outputURL: URL,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    log("Starting conversion pipeline")
    DispatchQueue.main.async {
      self.onProgressUpdate?(0.0, "Starting conversion...")
    }

    // First get the duration of the video file
    getDuration(of: videoURL, ffmpegPath: ffmpegPath) { [weak self] duration in
      guard let self = self else { return }
      self.totalDuration = duration
      self.log("Detected video duration: \(String(format: "%.2f", duration))s")

      let process = Process()
      process.executableURL = URL(fileURLWithPath: ffmpegPath)
      process.arguments = [
        "-nostdin",
        "-progress", "pipe:2",  // Send progress to stderr
        "-i", videoURL.path,
        "-i", audioURL.path,
        "-c:v", "copy",
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-y",
        outputURL.path,
      ]

      // Setup stderr pipe to capture progress
      let stderrPipe = Pipe()
      process.standardError = stderrPipe

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try process.run()
          self.log("FFmpeg process started")
          stderrPipe.fileHandleForWriting.closeFile()

          let stderrHandle = stderrPipe.fileHandleForReading
          while process.isRunning {
            let data = stderrHandle.availableData
            if data.isEmpty {
              continue
            }
            if let output = String(data: data, encoding: .utf8) {
              self.parseProgress(from: output)
            }
          }

          let trailingData = stderrHandle.readDataToEndOfFile()
          if let trailingOutput = String(data: trailingData, encoding: .utf8),
            !trailingOutput.isEmpty
          {
            self.parseProgress(from: trailingOutput)
            self.log(
              "Final FFmpeg stderr: \(trailingOutput.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
          }

          process.waitUntilExit()
          self.log("FFmpeg exited with status \(process.terminationStatus)")

          DispatchQueue.main.async {
            if process.terminationStatus == 0 {
              self.onProgressUpdate?(1.0, "Complete!")

              if FileManager.default.fileExists(atPath: outputURL.path) {
                self.showNotification(
                  title: "Conversion Complete",
                  body: "Video saved to \(outputURL.lastPathComponent)")
                self.log("Output file created successfully")
                completion(.success(outputURL))
              } else {
                self.showNotification(
                  title: "Conversion Failed", body: "Output file was not created")
                self.log("FFmpeg succeeded but output file was not found")
                completion(.failure(ProcessingError.processingFailed))
              }
            } else {
              self.showNotification(
                title: "Conversion Failed", body: "FFmpeg process failed")
              self.log("FFmpeg reported failure")
              completion(.failure(ProcessingError.processingFailed))
            }
          }
        } catch {
          self.log("Failed to run FFmpeg process: \(error.localizedDescription)")
          DispatchQueue.main.async {
            completion(.failure(error))
          }
        }
      }
    }
  }

  private func getDuration(
    of videoURL: URL, ffmpegPath: String, completion: @escaping (TimeInterval) -> Void
  ) {
    log("Fetching media duration for \(videoURL.lastPathComponent)")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ffmpegPath)
    process.arguments = [
      "-nostdin",
      "-i", videoURL.path,
    ]

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    DispatchQueue.global(qos: .utility).async {
      do {
        try process.run()
        self.log("Duration probe process started")
        stderrPipe.fileHandleForWriting.closeFile()

        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        self.log("Duration probe exited with status \(process.terminationStatus)")

        if let output = String(data: data, encoding: .utf8) {
          let duration = self.parseDuration(from: output)
          self.log("Parsed duration value: \(String(format: "%.2f", duration))s")
          DispatchQueue.main.async {
            completion(duration)
          }
        } else {
          self.log("Unable to parse duration output, using fallback")
          DispatchQueue.main.async {
            completion(60.0)  // Default fallback duration
          }
        }
      } catch {
        self.log("Duration probe failed: \(error.localizedDescription). Using fallback")
        DispatchQueue.main.async {
          completion(60.0)  // Default fallback duration
        }
      }
    }
  }

  private func parseDuration(from ffmpegOutput: String) -> TimeInterval {
    // Look for "Duration: HH:MM:SS.mmm" pattern
    let pattern = "Duration: (\\d{2}):(\\d{2}):(\\d{2})\\.(\\d{2})"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return 60.0
    }
    let range = NSRange(location: 0, length: ffmpegOutput.count)

    if let match = regex.firstMatch(in: ffmpegOutput, options: [], range: range) {
      let hours = Double((ffmpegOutput as NSString).substring(with: match.range(at: 1))) ?? 0
      let minutes =
        Double((ffmpegOutput as NSString).substring(with: match.range(at: 2))) ?? 0
      let seconds =
        Double((ffmpegOutput as NSString).substring(with: match.range(at: 3))) ?? 0
      let centiseconds =
        Double((ffmpegOutput as NSString).substring(with: match.range(at: 4))) ?? 0

      return hours * 3600 + minutes * 60 + seconds + centiseconds / 100
    }

    return 60.0  // Default fallback
  }

  private func parseProgress(from ffmpegOutput: String) {
    // Supports both classic ffmpeg stderr status lines (time=)
    // and key/value progress output (-progress pipe:2 with out_time* keys).
    let lines = ffmpegOutput.components(separatedBy: .newlines)

    for line in lines {
      if line.contains("out_time_ms=") {
        let value = line.replacingOccurrences(of: "out_time_ms=", with: "")
        if let microseconds = Double(value), microseconds >= 0 {
          let seconds = microseconds / 1_000_000
          updateProgress(currentTime: seconds)
        }
      } else if line.contains("out_time=") {
        let timestamp = line.replacingOccurrences(of: "out_time=", with: "")
        let seconds = parseTimestampToSeconds(timestamp)
        updateProgress(currentTime: seconds)
      } else if line.contains("time=") {
        let pattern = "time=(\\d{2}):(\\d{2}):(\\d{2})\\.(\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
          continue
        }
        let range = NSRange(location: 0, length: line.count)

        if let match = regex.firstMatch(in: line, options: [], range: range) {
          let hours = Double((line as NSString).substring(with: match.range(at: 1))) ?? 0
          let minutes =
            Double((line as NSString).substring(with: match.range(at: 2))) ?? 0
          let seconds =
            Double((line as NSString).substring(with: match.range(at: 3))) ?? 0
          let centiseconds =
            Double((line as NSString).substring(with: match.range(at: 4))) ?? 0

          let currentTime = hours * 3600 + minutes * 60 + seconds + centiseconds / 100
          updateProgress(currentTime: currentTime)
        }
      }
    }
  }

  private func parseTimestampToSeconds(_ timestamp: String) -> TimeInterval {
    let parts = timestamp.split(separator: ":")
    guard parts.count == 3 else { return 0 }

    let hours = Double(parts[0]) ?? 0
    let minutes = Double(parts[1]) ?? 0
    let seconds = Double(parts[2]) ?? 0

    return hours * 3600 + minutes * 60 + seconds
  }

  private func updateProgress(currentTime: TimeInterval) {
    guard totalDuration > 0 else { return }

    let progress = min(max(currentTime / totalDuration, 0), 0.99)

    DispatchQueue.main.async { [weak self] in
      self?.onProgressUpdate?(progress, "Converting...")
    }
  }

  private func getFFmpegPath() -> String {
    let preferredBinaryName = preferredFFmpegBinaryName()

    // Try local Resources directory (for development)
    let currentDir = FileManager.default.currentDirectoryPath
    let localFFmpeg = "\(currentDir)/Resources/\(preferredBinaryName)"

    if FileManager.default.fileExists(atPath: localFFmpeg) {
      log("Using local bundled FFmpeg path (\(preferredBinaryName))")
      return localFFmpeg
    }

    // Try to find ffmpeg in the app bundle
    if let bundlePath = Bundle.main.path(forResource: preferredBinaryName, ofType: nil) {
      log("Using app bundle FFmpeg path (\(preferredBinaryName))")
      return bundlePath
    }

    // Try the Resources directory relative to the executable
    let executablePath = Bundle.main.executablePath ?? ""
    let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
    let resourcesFFmpeg = executableDir.appendingPathComponent(
      "../Resources/\(preferredBinaryName)"
    ).path

    if FileManager.default.fileExists(atPath: resourcesFFmpeg) {
      log("Using executable-relative FFmpeg path (\(preferredBinaryName))")
      return resourcesFFmpeg
    }

    // Fallback to system ffmpeg
    log("Falling back to /usr/local/bin/ffmpeg")
    return "/usr/local/bin/ffmpeg"
  }

  private func preferredFFmpegBinaryName() -> String {
    let machine = currentMachineIdentifier()
    if machine.contains("arm64") || machine.contains("aarch64") {
      return "ffmpeg-arm64"
    }
    return "ffmpeg-x86_64"
  }

  private func currentMachineIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)

    let machine = machineMirror.children.reduce(into: "") { result, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      result.append(Character(UnicodeScalar(UInt8(value))))
    }

    log("Detected machine architecture: \(machine)")
    return machine
  }

  private func showNotification(title: String, body: String) {
    print("\(title): \(body)")

    // For a proper app bundle, we could use NSUserNotification (deprecated)
    // or UserNotifications (requires proper app bundle with entitlements)
    // For now, just print to console
  }
}

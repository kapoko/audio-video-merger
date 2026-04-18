import Cocoa

struct FileTypes {
    static let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
    static let audioExtensions = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma"]
}

class SimpleDropView: NSView {
    private var isDragHovering = false
    private var animationProgress: CGFloat = 0.0
    private var animationTimer: Timer?
    
    private var droppedVideoURLs: [URL] = []
    private var droppedAudioURLs: [URL] = []
    
    private var isProcessing = false
    private var progress: Double = 0.0
    private var currentTask: String = ""
    private var currentJobIndex = 0
    private var totalJobs = 0
    private var successfulJobs = 0
    private var jobWeightsBytes: [Double] = []
    private var totalWeightBytes: Double = 1
    private var completedWeightBytes: Double = 0
    private var isStateTransitioning = false
    private var pendingStateTransition: (() -> Void)?
    private let stateFadeDuration: TimeInterval = 0.15
    
    private let ffmpegProcessor = SimpleFFmpegProcessor()

    private func log(_ message: String) {
        print("[DropView] \(message)")
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }

    func setupDragAndDrop() {
        registerForDraggedTypes([.fileURL])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isProcessing {
            drawProcessingView()
        } else {
            drawDropView()
        }
    }
    
    private func drawDropView() {
        let blueColor = NSColor.systemBlue
        let redColor = NSColor.systemOrange

        guard let blueRGB = blueColor.usingColorSpace(.sRGB),
            let redRGB = redColor.usingColorSpace(.sRGB)
        else {
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 10, dy: 10))
            path.setLineDash([5, 5], count: 2, phase: 0)
            path.lineWidth = 2
            path.stroke()
            return
        }

        let interpolatedColor = NSColor(
            red: blueRGB.redComponent + animationProgress
                * (redRGB.redComponent - blueRGB.redComponent),
            green: blueRGB.greenComponent + animationProgress
                * (redRGB.greenComponent - blueRGB.greenComponent),
            blue: blueRGB.blueComponent + animationProgress
                * (redRGB.blueComponent - blueRGB.blueComponent),
            alpha: 1.0
        )

        interpolatedColor.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 10, dy: 10))
        path.setLineDash([5, 5], count: 2, phase: 0)
        path.lineWidth = 2
        path.stroke()

        var statusText = ""
        let hasVideos = !droppedVideoURLs.isEmpty
        let hasAudios = !droppedAudioURLs.isEmpty
        
        if hasVideos && hasAudios {
            let combinations = droppedVideoURLs.count * droppedAudioURLs.count
            statusText = "Ready to create \(combinations) video\(combinations > 1 ? "s" : "")! 🎬🎵"
        } else if hasVideos {
            let count = droppedVideoURLs.count
            statusText = "\(count) video\(count > 1 ? "s" : "") ready - drop audio file\(count > 1 ? "s" : "") 🎵"
        } else if hasAudios {
            let count = droppedAudioURLs.count
            statusText = "\(count) audio file\(count > 1 ? "s" : "") ready - drop video file\(count > 1 ? "s" : "") 🎬"
        } else {
            statusText = "Drop video and audio files here 🔥"
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 16),
        ]

        let textSize = statusText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        statusText.draw(in: textRect, withAttributes: attributes)
        
        if hasVideos || hasAudios {
            var yOffset: CGFloat = textRect.minY - 30
            
            // Show video files
            for (_, videoURL) in droppedVideoURLs.prefix(3).enumerated() {
                let videoText = "📹 \(videoURL.lastPathComponent)"
                let videoSize = videoText.size(withAttributes: attributes)
                let videoRect = NSRect(
                    x: (bounds.width - videoSize.width) / 2,
                    y: yOffset,
                    width: videoSize.width,
                    height: videoSize.height
                )
                videoText.draw(in: videoRect, withAttributes: attributes)
                yOffset -= 20
            }
            
            if droppedVideoURLs.count > 3 {
                let moreText = "... and \(droppedVideoURLs.count - 3) more videos"
                let moreSize = moreText.size(withAttributes: attributes)
                let moreRect = NSRect(
                    x: (bounds.width - moreSize.width) / 2,
                    y: yOffset,
                    width: moreSize.width,
                    height: moreSize.height
                )
                moreText.draw(in: moreRect, withAttributes: attributes)
                yOffset -= 20
            }
            
            // Show audio files
            for (_, audioURL) in droppedAudioURLs.prefix(3).enumerated() {
                let audioText = "🎵 \(audioURL.lastPathComponent)"
                let audioSize = audioText.size(withAttributes: attributes)
                let audioRect = NSRect(
                    x: (bounds.width - audioSize.width) / 2,
                    y: yOffset,
                    width: audioSize.width,
                    height: audioSize.height
                )
                audioText.draw(in: audioRect, withAttributes: attributes)
                yOffset -= 20
            }
            
            if droppedAudioURLs.count > 3 {
                let moreText = "... and \(droppedAudioURLs.count - 3) more audio files"
                let moreSize = moreText.size(withAttributes: attributes)
                let moreRect = NSRect(
                    x: (bounds.width - moreSize.width) / 2,
                    y: yOffset,
                    width: moreSize.width,
                    height: moreSize.height
                )
                moreText.draw(in: moreRect, withAttributes: attributes)
            }
        }
    }
    
    private func drawProcessingView() {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        
        let progressBarRect = NSRect(x: 20, y: bounds.height / 2 - 10, width: bounds.width - 40, height: 20)
        NSColor.separatorColor.setFill()
        NSBezierPath(roundedRect: progressBarRect, xRadius: 10, yRadius: 10).fill()
        
        let fillWidth = (progressBarRect.width - 4) * CGFloat(progress)
        let fillRect = NSRect(x: progressBarRect.minX + 2, y: progressBarRect.minY + 2, width: fillWidth, height: progressBarRect.height - 4)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 8, yRadius: 8).fill()
        
        let jobText = totalJobs > 1 ? " (Job \(currentJobIndex + 1)/\(totalJobs))" : ""
        let progressText = String(format: "%.0f%% - %@%@", progress * 100, currentTask, jobText)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 14),
        ]
        
        let textSize = progressText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: progressBarRect.maxY + 10,
            width: textSize.width,
            height: textSize.height
        )
        
        progressText.draw(in: textRect, withAttributes: attributes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isProcessing else { return [] }
        isDragHovering = true
        animateToRed()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragHovering = false
        animateToBlue()
    }

    private func animateToRed() {
        animateProgress(to: 1.0)
    }

    private func animateToBlue() {
        animateProgress(to: 0.0)
    }

    private func animateProgress(to target: CGFloat) {
        animationTimer?.invalidate()

        let startProgress = animationProgress
        let startTime = CACurrentMediaTime()
        let duration: TimeInterval = 0.2

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
            timer in
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / duration, 1.0)

            self.animationProgress = startProgress + (target - startProgress) * progress
            self.needsDisplay = true

            if progress >= 1.0 {
                timer.invalidate()
                self.animationTimer = nil
            }
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isProcessing else { 
            log("Drop ignored because processing is already running")
            return false 
        }
        
        let pasteboard = sender.draggingPasteboard

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            print("❌ No URLs found in pasteboard")
            return false
        }

        log("Dropped \(urls.count) file(s)")

        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            
            if FileTypes.videoExtensions.contains(fileExtension) {
                if !droppedVideoURLs.contains(url) {
                    droppedVideoURLs.append(url)
                    log("Registered video file: \(url.lastPathComponent)")
                }
            } else if FileTypes.audioExtensions.contains(fileExtension) {
                if !droppedAudioURLs.contains(url) {
                    droppedAudioURLs.append(url)
                    log("Registered audio file: \(url.lastPathComponent)")
                }
            } else {
                log("Ignored unsupported file: \(url.lastPathComponent)")
            }
        }
        
        // Start processing if we have both video and audio files
        if !droppedVideoURLs.isEmpty && !droppedAudioURLs.isEmpty {
            log("Starting batch processing with \(droppedVideoURLs.count) video(s) and \(droppedAudioURLs.count) audio file(s)")
            startBatchProcessing()
        }

        isDragHovering = false
        animateToBlue()
        needsDisplay = true

        return true
    }
    
    private func startBatchProcessing() {
        let jobs = createJobList()
        totalJobs = jobs.count
        currentJobIndex = 0
        jobWeightsBytes = createJobWeights(for: jobs)
        totalWeightBytes = max(jobWeightsBytes.reduce(0, +), 1)
        completedWeightBytes = 0

        log("Created \(jobs.count) job(s)")
        
        if jobs.isEmpty {
            return
        }

        transitionState {
            self.isProcessing = true
            self.progress = 0.0
            self.currentTask = "Starting batch conversion..."
        }

        successfulJobs = 0
        
        // Set up progress monitoring
        ffmpegProcessor.onProgressUpdate = { [weak self] progress, task in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }

                let currentWeight = self.weightForJob(at: self.currentJobIndex)
                let weightedProgress =
                    (self.completedWeightBytes + progress * currentWeight) / self.totalWeightBytes
                self.progress = min(max(weightedProgress, 0), 1)
                self.currentTask = task
                self.needsDisplay = true
            }
        }
        
        processNextJob(jobs: jobs)
    }
    
    private func createJobList() -> [(videoURL: URL, audioURL: URL, outputURL: URL)] {
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
            // Single video, multiple audio: use audio name
            outputFilename = "\(audioNameWithoutExtension).\(videoExtension)"
        } else if droppedAudioURLs.count == 1 {
            // Multiple videos, single audio: use video name
            outputFilename = "\(videoNameWithoutExtension)_\(audioNameWithoutExtension).\(videoExtension)"
        } else {
            // Multiple videos and audio: combine both names
            outputFilename = "\(videoNameWithoutExtension)_\(audioNameWithoutExtension).\(videoExtension)"
        }
        
        return audioDirectory.appendingPathComponent(outputFilename)
    }

    private func createJobWeights(for jobs: [(videoURL: URL, audioURL: URL, outputURL: URL)]) -> [Double] {
        return jobs.map { job in
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
            log("Could not read file size for \(url.lastPathComponent): \(error.localizedDescription)")
        }

        return 1
    }

    private func weightForJob(at index: Int) -> Double {
        guard index >= 0 && index < jobWeightsBytes.count else {
            return 1
        }

        return max(jobWeightsBytes[index], 1)
    }
    
    private func processNextJob(jobs: [(videoURL: URL, audioURL: URL, outputURL: URL)]) {
        guard currentJobIndex < jobs.count else {
            finishBatchProcessing()
            return
        }

        let job = jobs[currentJobIndex]
        log("Processing job \(currentJobIndex + 1)/\(jobs.count): \(job.videoURL.lastPathComponent) + \(job.audioURL.lastPathComponent)")

        guard confirmOverwriteIfNeeded(for: job.outputURL) else {
            log("User cancelled overwrite for existing file: \(job.outputURL.lastPathComponent)")
            finishBatchProcessing()
            return
        }

        ffmpegProcessor.processVideoAudio(videoURL: job.videoURL, audioURL: job.audioURL, outputURL: job.outputURL) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { 
                    return 
                }

                switch result {
                case .success(let outputURL):
                    self.successfulJobs += 1
                    self.log("Job \(self.currentJobIndex + 1) finished: \(outputURL.lastPathComponent)")
                case .failure(let error):
                    self.log("Job \(self.currentJobIndex + 1) failed: \(error.localizedDescription)")
                }

                self.completedWeightBytes += self.weightForJob(at: self.currentJobIndex)
                
                self.currentJobIndex += 1
                
                if self.currentJobIndex < jobs.count {
                    self.processNextJob(jobs: jobs)
                } else {
                    self.finishBatchProcessing(showCompletionMessage: true)
                }
            }
        }
    }
    
    private func finishBatchProcessing(showCompletionMessage: Bool = false) {
        log("Batch processing finished")

        if showCompletionMessage {
            let videoLabel = successfulJobs == 1 ? "video" : "videos"
            progress = 1.0
            currentTask = "✅ Done! Created \(successfulJobs) \(videoLabel)"
            needsDisplay = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resetProcessingState()
            }
            return
        }

        resetProcessingState()
    }
    
    private func resetDroppedFiles() {
        droppedVideoURLs.removeAll()
        droppedAudioURLs.removeAll()
    }

    private func resetProcessingState() {
        transitionState {
            self.isProcessing = false
            self.progress = 0.0
            self.currentTask = ""
            self.currentJobIndex = 0
            self.totalJobs = 0
            self.successfulJobs = 0
            self.jobWeightsBytes.removeAll()
            self.totalWeightBytes = 1
            self.completedWeightBytes = 0

            self.resetDroppedFiles()
        }
    }

    private func transitionState(_ updateState: @escaping () -> Void) {
        if isStateTransitioning {
            pendingStateTransition = updateState
            return
        }

        isStateTransitioning = true

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = stateFadeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                guard let self = self else { return }

                updateState()
                self.needsDisplay = true

                NSAnimationContext.runAnimationGroup(
                    { context in
                        context.duration = self.stateFadeDuration
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        self.animator().alphaValue = 1
                    },
                    completionHandler: { [weak self] in
                        guard let self = self else { return }
                        self.isStateTransitioning = false

                        if let pendingTransition = self.pendingStateTransition {
                            self.pendingStateTransition = nil
                            self.transitionState(pendingTransition)
                        }
                    }
                )
            }
        )
    }

    private func confirmOverwriteIfNeeded(for outputURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "File already exists"
        alert.informativeText = "\(outputURL.lastPathComponent) already exists in this location. Do you want to overwrite it?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }
    

}

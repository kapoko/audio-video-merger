import Cocoa

class DropView: NSView {
    private var isDragHovering = false
    private var animationProgress: CGFloat = 0.0
    private var animationTimer: Timer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    func setupDragAndDrop() {
        // Register for file drag and drop
        registerForDraggedTypes([.fileURL])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Interpolate between blue and red based on animation progress
        let blueColor = NSColor.systemBlue
        let redColor = NSColor.red
        
        // Convert to RGB color space for interpolation
        guard let blueRGB = blueColor.usingColorSpace(.sRGB),
              let redRGB = redColor.usingColorSpace(.sRGB) else {
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 10, dy: 10))
            path.setLineDash([5, 5], count: 2, phase: 0)
            path.lineWidth = 2
            path.stroke()
            return
        }
        
        let interpolatedColor = NSColor(
            red: blueRGB.redComponent + animationProgress * (redRGB.redComponent - blueRGB.redComponent),
            green: blueRGB.greenComponent + animationProgress * (redRGB.greenComponent - blueRGB.greenComponent),
            blue: blueRGB.blueComponent + animationProgress * (redRGB.blueComponent - blueRGB.blueComponent),
            alpha: 1.0
        )
        
        interpolatedColor.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 10, dy: 10))
        path.setLineDash([5, 5], count: 2, phase: 0)
        path.lineWidth = 2
        path.stroke()
        
        // Draw text
        let text = "Drop files here"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 16)
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
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
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
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
        let pasteboard = sender.draggingPasteboard
        
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        
        // Print all dropped file paths to console
        for url in urls {
            print("Dropped file: \(url.path)")
        }
        
        // Reset border to blue after drop
        isDragHovering = false
        animateToBlue()
        
        return true
    }
}

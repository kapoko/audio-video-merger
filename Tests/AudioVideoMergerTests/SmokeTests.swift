import XCTest
@testable import AudioVideoMerger

@MainActor
final class SmokeTests: XCTestCase {
    func testPromptStateDefaultsToIdle() {
        let viewModel = DropViewModel()

        XCTAssertEqual(viewModel.dropPromptState, .idle)
    }

    func testPromptStateNeedsAudioWhenVideoAlreadyDropped() {
        let viewModel = DropViewModel()
        viewModel.droppedVideoURLs = [URL(fileURLWithPath: "/tmp/sample.mp4")]

        XCTAssertEqual(viewModel.dropPromptState, .needsAudio)
    }

    func testPromptStateNeedsVideoWhenAudioAlreadyDropped() {
        let viewModel = DropViewModel()
        viewModel.droppedAudioURLs = [URL(fileURLWithPath: "/tmp/sample.mp3")]

        XCTAssertEqual(viewModel.dropPromptState, .needsVideo)
    }

    func testPromptStateHoveringOverridesOtherStates() {
        let viewModel = DropViewModel()
        viewModel.droppedVideoURLs = [URL(fileURLWithPath: "/tmp/sample.mp4")]
        viewModel.isDragHovering = true

        XCTAssertEqual(viewModel.dropPromptState, .hovering)
    }

    func testFileValidatorClassifiesAudioVideoAndUnknown() {
        let urls = [
            URL(fileURLWithPath: "/tmp/clip.mp4"),
            URL(fileURLWithPath: "/tmp/track.mp3"),
            URL(fileURLWithPath: "/tmp/readme.txt")
        ]

        let result = FileValidator.validate(urls: urls)

        XCTAssertEqual(result.videoURLs.count, 1)
        XCTAssertEqual(result.audioURLs.count, 1)
        XCTAssertEqual(result.unrecognizedURLs.count, 1)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.numVideos, 1)
    }

    func testFileValidatorComputesCombinationsFromCounts() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.mp3"),
            URL(fileURLWithPath: "/tmp/b.wav"),
            URL(fileURLWithPath: "/tmp/v1.mp4"),
            URL(fileURLWithPath: "/tmp/v2.mov"),
            URL(fileURLWithPath: "/tmp/v3.mkv")
        ]

        let result = FileValidator.validate(urls: urls)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.audioURLs.count, 2)
        XCTAssertEqual(result.videoURLs.count, 3)
        XCTAssertEqual(result.numVideos, 6)
    }
}

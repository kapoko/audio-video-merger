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
            URL(fileURLWithPath: "/tmp/v3.m4v")
        ]

        let result = FileValidator.validate(urls: urls)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.audioURLs.count, 2)
        XCTAssertEqual(result.videoURLs.count, 3)
        XCTAssertEqual(result.numVideos, 6)
    }

    func testFilePairingMatcherFindsExpectedPairsForSimilarNames() {
        let matcher = FilePairingMatcher(
            configuration: .init(minPairScore: 0.3, minAverageScore: 0.3, minTopSecondGap: 0)
        )

        let audios = [
            URL(fileURLWithPath: "/tmp/BrandA_Campaign_Red_Dress_611_Voiceover_v1.wav"),
            URL(fileURLWithPath: "/tmp/BrandA_Campaign_Blue_Jeans_924_Voiceover_v1.wav")
        ]
        let videos = [
            URL(fileURLWithPath: "/tmp/Campaign Red Dress 611 1920x1080 converted syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/Campaign Blue Jeans 924 1920x1080 converted syncfix.mp4")
        ]

        let pairs = matcher.suggestedPairs(videos: videos, audios: audios)

        XCTAssertNotNil(pairs)
        XCTAssertEqual(pairs?.count, 2)

        let pairedByVideoName = Dictionary(
            uniqueKeysWithValues: (pairs ?? []).map {
                ($0.videoURL.lastPathComponent, $0.audioURL.lastPathComponent)
            }
        )

        XCTAssertEqual(
            pairedByVideoName["Campaign Red Dress 611 1920x1080 converted syncfix.mp4"],
            "BrandA_Campaign_Red_Dress_611_Voiceover_v1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["Campaign Blue Jeans 924 1920x1080 converted syncfix.mp4"],
            "BrandA_Campaign_Blue_Jeans_924_Voiceover_v1.wav"
        )
    }

    func testFilePairingMatcherFindsExpectedPairsForSharedLabelWithTechnicalSuffixes() {
        let matcher = FilePairingMatcher()

        let audios = [
            URL(fileURLWithPath: "/tmp/Studio_Sunrise_GARDEN_V3.wav"),
            URL(fileURLWithPath: "/tmp/Studio_Sunrise_STUDENT_V3.wav"),
            URL(fileURLWithPath: "/tmp/Studio_Sunrise_NEIGHBORS_V3.wav"),
            URL(fileURLWithPath: "/tmp/Studio_Sunrise_BICYCLE_V4.wav")
        ]
        let videos = [
            URL(fileURLWithPath: "/tmp/NEIGHBORS 30 16x9_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/STUDENT 30 16x9_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/GARDEN 30  16x9_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/BICYCLE 30 16x9_converted_syncfix.mp4")
        ]

        let pairs = matcher.suggestedPairs(videos: videos, audios: audios)

        XCTAssertNotNil(pairs)
        XCTAssertEqual(pairs?.count, 4)

        let pairedByVideoName = Dictionary(
            uniqueKeysWithValues: (pairs ?? []).map {
                ($0.videoURL.lastPathComponent, $0.audioURL.lastPathComponent)
            }
        )

        XCTAssertEqual(
            pairedByVideoName["NEIGHBORS 30 16x9_converted_syncfix.mp4"],
            "Studio_Sunrise_NEIGHBORS_V3.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["STUDENT 30 16x9_converted_syncfix.mp4"],
            "Studio_Sunrise_STUDENT_V3.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["GARDEN 30  16x9_converted_syncfix.mp4"],
            "Studio_Sunrise_GARDEN_V3.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["BICYCLE 30 16x9_converted_syncfix.mp4"],
            "Studio_Sunrise_BICYCLE_V4.wav"
        )
    }

    func testFilePairingMatcherFindsExpectedPairsForSharedLabelAndDuration() {
        let matcher = FilePairingMatcher()

        let audios = [
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_BRIDGE_8_V1.wav"),
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_BRIDGE_20_V1.wav"),
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_RIVER_8_V1.wav"),
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_RIVER_20_V1.wav"),
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_MARKET_8_V1.wav"),
            URL(fileURLWithPath: "/tmp/BrandZ_Orchard_MARKET_20_V1.wav")
        ]
        let videos = [
            URL(fileURLWithPath: "/tmp/River 20 16x9 EDIT_v1_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/River 8 16x9 EDIT_v1_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/Bridge 20 16x9 EDIT_v1_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/Market 20 16x9 EDIT_v1_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/Bridge 8 16x9 EDIT_v1_converted_syncfix.mp4"),
            URL(fileURLWithPath: "/tmp/Market 8 16x9 EDIT_v1_converted_syncfix.mp4")
        ]

        let pairs = matcher.suggestedPairs(videos: videos, audios: audios)

        XCTAssertNotNil(pairs)
        XCTAssertEqual(pairs?.count, 6)

        let pairedByVideoName = Dictionary(
            uniqueKeysWithValues: (pairs ?? []).map {
                ($0.videoURL.lastPathComponent, $0.audioURL.lastPathComponent)
            }
        )

        XCTAssertEqual(
            pairedByVideoName["River 20 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_RIVER_20_V1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["River 8 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_RIVER_8_V1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["Bridge 20 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_BRIDGE_20_V1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["Market 20 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_MARKET_20_V1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["Bridge 8 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_BRIDGE_8_V1.wav"
        )
        XCTAssertEqual(
            pairedByVideoName["Market 8 16x9 EDIT_v1_converted_syncfix.mp4"],
            "BrandZ_Orchard_MARKET_8_V1.wav"
        )
    }
}

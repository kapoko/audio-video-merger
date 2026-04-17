# FFmpeg Audio Video Merger

A macOS application that allows you to replace audio tracks in videos using FFmpeg. Simply drag and drop a video file and an audio file, and the app will create a new video with the audio replaced, without re-rendering the video stream.

## Features

- **Dual File Drop Support**: Drop both video and audio files onto the application
- **No Re-rendering**: Uses FFmpeg's stream copy (`-c:v copy`) to avoid quality loss
- **Progress Tracking**: Real-time progress bar during conversion
- **macOS Notifications**: Get notified when conversion is complete
- **Smart Output Naming**: Output file is named after the audio file and saved in the audio file's directory
- **Bundled FFmpeg**: No need to install FFmpeg separately

## Supported Formats

### Video Files
- MP4, MOV, AVI, MKV, M4V, WMV, FLV, WebM

### Audio Files  
- MP3, WAV, AAC, M4A, FLAC, OGG, WMA

## How to Use

### Basic Usage (Single Files)
1. **Build and Run**: `swift run` or use the provided build scripts
2. **Drop Files**: Drag and drop a video file and an audio file onto the application window
3. **Wait for Processing**: Watch the progress bar as FFmpeg processes the files
4. **Get Notified**: Receive a macOS notification when conversion is complete
5. **Find Your File**: The new video will be saved in the same directory as the audio file

### Advanced Usage (Multiple Files)
The app supports **batch processing** for multiple combinations:

#### Multiple Audio Files + Single Video
- Drop 1 video + multiple audio files
- Creates a new video for each audio file
- Output naming: `[audio_name].[video_extension]`
- Example: `song1.mp4`, `song2.mp4`, `song3.mp4`

#### Multiple Video Files + Single Audio  
- Drop multiple videos + 1 audio file
- Creates a new video for each video file with the same audio
- Output naming: `[video_name]_[audio_name].[video_extension]`
- Example: `clip1_soundtrack.mp4`, `clip2_soundtrack.mp4`

#### Multiple Videos + Multiple Audio Files
- Drop multiple videos + multiple audio files  
- Creates **all combinations** (videos × audio files)
- Output naming: `[video_name]_[audio_name].[video_extension]`
- Example: 2 videos + 3 audio files = 6 output files

#### Batch Progress Tracking
- Shows overall progress: "Job 3/6" 
- Individual file progress within each job
- All files processed sequentially with real FFmpeg progress

## Building

### Quick Start
```bash
# Build and run in development mode (no notifications)
swift run

# Or use the build script
./build.sh && ./.build/release/swift-test

# Build architecture-specific binaries
./build.sh x86_64
./build.sh arm64

# Create proper app bundle with notifications
make bundle && open "Audio Video Merger.app"

# Create architecture-specific app bundles
make bundle-x86_64
make bundle-arm64
```

### Using Make
```bash
# Download FFmpeg and build everything
make all

# Just download FFmpeg
make ffmpeg  

# Build the application
make build

# Build architecture-specific binaries
make build-x86_64
make build-arm64

# Run the command line version
make run

# Create an app bundle for distribution (recommended)
make bundle

# Create architecture-specific app bundles
make bundle-x86_64
make bundle-arm64

# Create both architecture-specific bundles
make bundle-all
```

### Running
- **Command line version**: `swift run` or `./.build/debug/swift-test` - prints notifications to console
- **App bundle version**: `make bundle && open "Audio Video Merger.app"` - shows macOS notifications

## Project Structure

- `src/main.swift` - Application entry point and window setup
- `src/SimpleDropView.swift` - Main drag-and-drop interface with visual feedback
- `src/SimpleFFmpegProcessor.swift` - FFmpeg processing logic and file management
- `download_ffmpeg.sh` - Script to download and bundle architecture-specific FFmpeg binaries
- `Resources/ffmpeg-x86_64` - Bundled Intel FFmpeg binary
- `Resources/ffmpeg-arm64` - Bundled Apple Silicon FFmpeg binary

## FFmpeg Command

The app uses this FFmpeg command for audio replacement:
```bash
ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -y output.mp4
```

This command:
- Takes video and audio as inputs (`-i`)
- Copies the video stream without re-encoding (`-c:v copy`)
- Encodes audio to AAC (`-c:a aac`)
- Maps the video from first input and audio from second input (`-map`)
- Overwrites output file if it exists (`-y`)

## Requirements

- macOS 10.14 or later
- Swift 5.0 or later
- Internet connection (for downloading FFmpeg during first build)

## Distribution

To create a distributable app bundle:
```bash
make bundle
```

This creates `Audio Video Merger.app` with both FFmpeg binaries embedded.

For architecture-specific distribution bundles:
```bash
make bundle-x86_64
make bundle-arm64
```

`make bundle-x86_64` includes only `ffmpeg-x86_64`, and `make bundle-arm64` includes only `ffmpeg-arm64`.

<img src="Resources/logo.png" title="AudioVideoMerger" alt="AudioVideoMerger logo" width="128">

# AudioVideoMerger

AudioVideoMerger is a macOS app for replacing audio under video files using FFmpeg, without re-encoding the video stream.

- **Fast**: Copies video stream directly (`-c:v copy`) to avoid quality loss.
- **Simple**: Drag and drop files into the window, onto the app icon, or open files with the app.
- **Batch-ready**: Automatically creates every video/audio combination when dropping multiple files.
- **Self-contained**: Uses bundled FFmpeg binaries (`arm64` and `x86_64`).

## In action

![Demo](https://i.imgur.com/CUIK93h.gif)

## Why

This tool is built for fast audio versioning against existing video files. Instead of opening a video editor and re-rendering repeatedly, you can generate new versions in seconds.

## How it works

Drop at least one video file and one audio file.

- `1 video + many audio` -> output names use the audio filename (for example, `song1.mp4`, `song2.mp4`).
- `many videos + 1 audio` -> output names use `video_audio` (for example, `clip1_music.mp4`).
- `many videos + many audio` -> all combinations are created.
- Outputs are saved in the audio file directory.

When an output file already exists, the app asks whether to overwrite.

## Build and run

```bash
# Development run
swift run

# Build release binary for host architecture
make build

# Run release binary
make run

# Create app bundles
make bundle
make bundle-x86_64
make bundle-arm64

# Create release zip assets
make zip
make zip-x86_64
make zip-arm64
```

## Notifications and app verification

- Completion notifications are available when running as an app bundle (`.app`).
- The app is ad-hoc signed (not notarized), so macOS may show a verification warning on first launch. If that happens, allow it from _System Settings_ -> _Privacy & Security_ -> _Open Anyway_.

## Platform and requirements

- macOS 11 or later
- Swift 5.7 or later
- Internet connection for first-time FFmpeg download (`make ffmpeg` / `make setup`)

## Download

You can download releases from the project website:

https://audiovideomerger.github.io

## Development tooling

This repo uses Swift formatting/linting and optional git hooks:

```bash
brew install swiftlint lefthook
lefthook install

swift format lint -r src
swiftlint lint --strict
swift build
```

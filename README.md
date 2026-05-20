<img src="Resources/logo.png" title="AudioVideoMerger" alt="AudioVideoMerger logo" width="128">

# Audio Video Merger

[![](https://github.com/kapoko/audio-video-merger/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/kapoko/audio-video-merger/actions/workflows/build.yml)
[![](https://github.com/kapoko/audio-video-merger/actions/workflows/release.yml/badge.svg)](https://github.com/kapoko/audio-video-merger/actions)

AudioVideoMerger is an open source one-trick pony for painlessly replacing audio under video files. Since v2 rewritten as a native macOS app built with Swift.

- **Fast**: Copies video stream directly to avoid re-rendering.
- **Simple**: Drag and drop files into the window, onto the app icon, or open files with the app.
- **Batch-ready**: Automatically creates every video/audio combination when dropping multiple files.
- **Self-contained**: Uses bundled FFmpeg binaries, so easy to install.

## [Download](https://audiovideomerger.koman.app)

Downloads are available from the project website: [audiovideomerger.koman.app](https://audiovideomerger.koman.app)

## In action

![Demo](https://i.imgur.com/2hqolDx.gif)

## Why

This tool is built for fast audio versioning against existing video files. Instead of opening a video editor and re-rendering repeatedly, you can generate new versions in seconds.

## How it works

Drop at least one video file and one audio file.

- `1 video + multiple audio` -> output names use the audio filename (for example, `song1.mp4`, `song2.mp4`).
- `multiple videos + audio` -> output names use `video_audio` (for example, `clip1_music.mp4`).
- `multiple videos + multiple audio` -> all combinations are created.
- Outputs are saved in the audio file directory.

When an output file already exists, the app asks whether to overwrite.

## Build and run

```bash
# Development run
swift run

# Create app bundles
make bundle

# Create release DMG assets
make dmg
```

Build outputs are written to `dist/` (`dist/apps/*.app` and release DMGs in `dist/*.dmg`).

## Platform and requirements

- macOS 13 (Ventura) or later

## Development tooling

This repo uses Swift formatting/linting and optional git hooks:

```bash
brew install lefthook
lefthook install

swift format lint -r src
swift build
```

### Beta update channel

Enable beta updates. Used for testing releases.

```bash
defaults write app.koman.audiovideomerger updates.beta.enabled -bool true
# or false
```

## Project history

**v2+** is a complete Swift/macOS rewrite, as I didn't want to bundle electron in such a simple app anymore. If you need the old V1 source code, check tags matching `v1.x.x`.

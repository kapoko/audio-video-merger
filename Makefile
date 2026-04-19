.PHONY: all ffmpeg setup build build-x86_64 build-arm64 build-all run clean dev bundle bundle-x86_64 bundle-arm64 zip zip-x86_64 zip-arm64

APP_NAME := Audio Video Merger.app
APP_X86_64 := Audio Video Merger-x86_64.app
APP_ARM64 := Audio Video Merger-arm64.app
EXECUTABLE := AudioVideoMerger
DIST_DIR := dist
APP_VERSION := $(shell tr -d '[:space:]' < VERSION)

# Default target
all: setup build

# Download and setup FFmpeg
ffmpeg:
	@echo "Setting up architecture-specific FFmpeg binaries..."
	./download_ffmpeg.sh

# Setup dependencies
setup: ffmpeg
	@echo "Setup complete!"

# Build for host architecture
build:
	@echo "Building application for host architecture..."
	swift build -c release

# Build for Intel architecture
build-x86_64:
	@echo "Building application for x86_64..."
	swift build -c release --arch x86_64

# Build for Apple Silicon architecture
build-arm64:
	@echo "Building application for arm64..."
	swift build -c release --arch arm64

# Build for both architectures
build-all: build-x86_64 build-arm64

# Run the application
run: build
	@echo "Running application..."
	./.build/release/$(EXECUTABLE)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .build
	rm -rf Resources
	rm -rf "$(APP_NAME)" "$(APP_X86_64)" "$(APP_ARM64)"

# Development build and run
dev:
	swift run

# Create both architecture-specific bundles
bundle: bundle-x86_64 bundle-arm64
	@echo "Both architecture bundles created"

# Create x86_64 app bundle
bundle-x86_64: build-x86_64 setup
	@echo "Creating x86_64 app bundle..."
	rm -rf "$(APP_X86_64)"
	mkdir -p "$(APP_X86_64)/Contents/MacOS"
	mkdir -p "$(APP_X86_64)/Contents/Resources"
	cp .build/x86_64-apple-macosx/release/$(EXECUTABLE) "$(APP_X86_64)/Contents/MacOS/"
	cp Resources/ffmpeg-x86_64 "$(APP_X86_64)/Contents/Resources/"
	cp Resources/AppIcon.icns "$(APP_X86_64)/Contents/Resources/"
	cp Info.plist "$(APP_X86_64)/Contents/"
	codesign --force --deep --sign - "$(APP_X86_64)"
	@echo "App bundle created: $(APP_X86_64)"

# Create arm64 app bundle
bundle-arm64: build-arm64 setup
	@echo "Creating arm64 app bundle..."
	rm -rf "$(APP_ARM64)"
	mkdir -p "$(APP_ARM64)/Contents/MacOS"
	mkdir -p "$(APP_ARM64)/Contents/Resources"
	cp .build/arm64-apple-macosx/release/$(EXECUTABLE) "$(APP_ARM64)/Contents/MacOS/"
	cp Resources/ffmpeg-arm64 "$(APP_ARM64)/Contents/Resources/"
	cp Resources/AppIcon.icns "$(APP_ARM64)/Contents/Resources/"
	cp Info.plist "$(APP_ARM64)/Contents/"
	codesign --force --deep --sign - "$(APP_ARM64)"
	@echo "App bundle created: $(APP_ARM64)"

# Zip x86_64 bundle with normalized app name
zip-x86_64: bundle-x86_64
	@echo "Creating x86_64 zip asset..."
	@mkdir -p "$(DIST_DIR)"
	@tmpdir="$$(mktemp -d)"; \
		ditto "$(APP_X86_64)" "$$tmpdir/$(APP_NAME)"; \
		ditto -c -k --sequesterRsrc --keepParent "$$tmpdir/$(APP_NAME)" "$(DIST_DIR)/AudioVideoMerger-darwin-x86_64-$(APP_VERSION).zip"; \
		rm -rf "$$tmpdir"
	@echo "Created $(DIST_DIR)/AudioVideoMerger-darwin-x86_64-$(APP_VERSION).zip"

# Zip arm64 bundle with normalized app name
zip-arm64: bundle-arm64
	@echo "Creating arm64 zip asset..."
	@mkdir -p "$(DIST_DIR)"
	@tmpdir="$$(mktemp -d)"; \
		ditto "$(APP_ARM64)" "$$tmpdir/$(APP_NAME)"; \
		ditto -c -k --sequesterRsrc --keepParent "$$tmpdir/$(APP_NAME)" "$(DIST_DIR)/AudioVideoMerger-darwin-arm64-$(APP_VERSION).zip"; \
		rm -rf "$$tmpdir"
	@echo "Created $(DIST_DIR)/AudioVideoMerger-darwin-arm64-$(APP_VERSION).zip"

# Create both zip assets
zip: zip-x86_64 zip-arm64
	@echo "All zip assets created"

.PHONY: all ffmpeg setup build build-x86_64 build-arm64 build-all run clean dev bundle bundle-x86_64 bundle-arm64 dmg dmg-x86_64 dmg-arm64

APP_NAME := Audio Video Merger.app
EXECUTABLE := AudioVideoMerger
DIST_DIR := dist
APP_BUNDLE_DIR := $(DIST_DIR)/apps
APP_VERSION := $(shell tr -d '[:space:]' < VERSION)
APP_BUILD_VERSION := $(shell tr -d '[:space:]' < VERSION | sed -E 's/-beta\.([0-9]+)$$/b\1/; s/-.*$$//')
APPCAST_URL_ARM64 ?= https://audiovideomerger.github.io/appcast-arm64.xml
APPCAST_URL_X86_64 ?= https://audiovideomerger.github.io/appcast-x86_64.xml

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
	rm -rf "$(DIST_DIR)"

# Development build and run
dev:
	swift run

# Create both architecture-specific bundles
bundle: bundle-x86_64 bundle-arm64
	@echo "Both architecture bundles created"

# Create architecture-specific app bundle
bundle-x86_64 bundle-arm64: bundle-%: build-% setup
	@echo "Creating $* app bundle..."
	@mkdir -p "$(APP_BUNDLE_DIR)"
	@app_bundle="$(APP_BUNDLE_DIR)/Audio Video Merger-$*.app"; \
		app_executable="$$app_bundle/Contents/MacOS/$(EXECUTABLE)"; \
		appcast_url=""; \
		if [ "$*" = "arm64" ]; then \
			appcast_url="$(APPCAST_URL_ARM64)"; \
		else \
			appcast_url="$(APPCAST_URL_X86_64)"; \
		fi; \
		rm -rf "$$app_bundle"; \
		mkdir -p "$$app_bundle/Contents/MacOS"; \
		mkdir -p "$$app_bundle/Contents/Resources"; \
		mkdir -p "$$app_bundle/Contents/Frameworks"; \
		cp ".build/$*-apple-macosx/release/$(EXECUTABLE)" "$$app_executable"; \
		if ! otool -l "$$app_executable" | grep -q "@executable_path/../Frameworks"; then \
			install_name_tool -add_rpath "@executable_path/../Frameworks" "$$app_executable"; \
		fi; \
		sparkle_framework=""; \
		for candidate in \
			".build/$*-apple-macosx/release/Sparkle.framework" \
			".build/artifacts/sparkle/Sparkle/Sparkle.framework" \
			".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
			".build/artifacts/sparkle/Sparkle.framework"; do \
			if [ -d "$$candidate" ]; then \
				sparkle_framework="$$candidate"; \
				break; \
			fi; \
		done; \
		if [ -z "$$sparkle_framework" ]; then \
			echo "Could not find Sparkle.framework in .build artifacts"; \
			exit 1; \
		fi; \
		cp -R "$$sparkle_framework" "$$app_bundle/Contents/Frameworks/"; \
		cp "Resources/ffmpeg-$*" "$$app_bundle/Contents/Resources/"; \
		cp "Resources/AppIcon.icns" "$$app_bundle/Contents/Resources/"; \
		cp "Info.plist" "$$app_bundle/Contents/"; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APP_VERSION)" "$$app_bundle/Contents/Info.plist"; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(APP_BUILD_VERSION)" "$$app_bundle/Contents/Info.plist"; \
		/usr/libexec/PlistBuddy -c "Set :SUFeedURL $$appcast_url" "$$app_bundle/Contents/Info.plist"; \
		if [ -n "$$MACOS_SIGNING_IDENTITY" ]; then \
			codesign --force --timestamp --options runtime --sign "$$MACOS_SIGNING_IDENTITY" "$$app_bundle/Contents/Resources/ffmpeg-$*"; \
			codesign --force --deep --timestamp --options runtime --sign "$$MACOS_SIGNING_IDENTITY" "$$app_bundle"; \
		else \
			codesign --force --deep --sign - "$$app_bundle"; \
		fi; \
		echo "App bundle created: $$app_bundle"

# Create both DMG assets
dmg: dmg-x86_64 dmg-arm64
	@echo "All DMG assets created"

# Create architecture-specific DMG using create-dmg
dmg-x86_64 dmg-arm64: dmg-%: bundle-%
	@echo "Creating $* DMG asset..."
	@mkdir -p "$(DIST_DIR)"
	@app_bundle="$(APP_BUNDLE_DIR)/Audio Video Merger-$*.app"; \
		tmpdir="$$(mktemp -d)"; \
		staged_app="$$tmpdir/Audio Video Merger.app"; \
		tmp_dmg_dir="$$tmpdir/dmg"; \
		generated_dmg="$$tmp_dmg_dir/Audio Video Merger.dmg"; \
		final_dmg="$(DIST_DIR)/AudioVideoMerger-darwin-$*-$(APP_VERSION).dmg"; \
		rm -rf "$$staged_app"; \
		mkdir -p "$$tmp_dmg_dir"; \
		ditto "$$app_bundle" "$$staged_app"; \
		rm -rf "$$final_dmg"; \
		if [ -n "$$MACOS_SIGNING_IDENTITY" ]; then set -- --identity "$$MACOS_SIGNING_IDENTITY"; else set --; fi; \
		create-dmg \
			--overwrite \
			--dmg-title="Audio Video Merger" \
			--no-version-in-filename \
			"$$@" \
			"$$staged_app" \
			"$$tmp_dmg_dir"; \
		if [ ! -f "$$generated_dmg" ]; then \
			echo "create-dmg did not produce a DMG file"; \
			rm -rf "$$tmpdir"; \
			exit 1; \
		fi; \
		mv "$$generated_dmg" "$$final_dmg"; \
		rm -rf "$$tmpdir"; \
		echo "Created $$final_dmg"

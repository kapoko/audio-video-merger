.PHONY: all ffmpeg setup build build-x86_64 build-arm64 build-all run clean dev bundle bundle-x86_64 bundle-arm64 dmg dmg-x86_64 dmg-arm64

APP_NAME := Audio Video Merger.app
EXECUTABLE := AudioVideoMerger
DIST_DIR := dist
APP_BUNDLE_DIR := $(DIST_DIR)/apps
APP_VERSION := $(shell tr -d '[:space:]' < VERSION)
APP_BUILD_VERSION := $(shell tr -d '[:space:]' < VERSION | sed -E 's/-beta\.([0-9]+)$$/b\1/; s/-.*$$//')
DMG_TEMPLATE_DIR := Resources/packaging/dmg-template
DMG_TEMPLATE_DSSTORE := $(DMG_TEMPLATE_DIR)/dmg-layout.DS_Store
DMG_TEMPLATE_BACKGROUND := $(DMG_TEMPLATE_DIR)/background.tiff

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
		codesign --force --deep --sign - "$$app_bundle"; \
		echo "App bundle created: $$app_bundle"

# Create both DMG assets
dmg: dmg-x86_64 dmg-arm64
	@echo "All DMG assets created"

# Create architecture-specific DMG with installer layout
dmg-x86_64 dmg-arm64: dmg-%: bundle-%
	@echo "Creating $* DMG asset..."
	@mkdir -p "$(DIST_DIR)"
	@tmpdir="$$(mktemp -d)"; \
		set -e; \
		stage="$$tmpdir/stage"; \
		rw_dmg="$$tmpdir/AudioVideoMerger-rw.dmg"; \
		mountpoint="$$tmpdir/mnt"; \
		final_dmg="$(DIST_DIR)/AudioVideoMerger-darwin-$*-$(APP_VERSION).dmg"; \
		app_bundle="$(APP_BUNDLE_DIR)/Audio Video Merger-$*.app"; \
		mkdir -p "$$stage"; \
		mkdir -p "$$stage/.background"; \
		cp "$(DMG_TEMPLATE_BACKGROUND)" "$$stage/.background/background.tiff"; \
		ditto "$$app_bundle" "$$stage/$(APP_NAME)"; \
		ln -s /Applications "$$stage/Applications"; \
		chflags hidden "$$stage/.background"; \
		hdiutil create -quiet -ov -srcfolder "$$stage" -volname "Audio Video Merger" -fs HFS+ -format UDRW "$$rw_dmg"; \
		mkdir -p "$$mountpoint"; \
		hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$$mountpoint" "$$rw_dmg"; \
		cp "$(DMG_TEMPLATE_DSSTORE)" "$$mountpoint/.DS_Store"; \
		hdiutil detach "$$mountpoint" -quiet; \
		hdiutil convert -quiet -ov "$$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$$final_dmg"; \
		rm -rf "$$tmpdir"; \
		echo "Created $$final_dmg"

APP_NAME = LoudCoworker
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)
SDK = $(shell xcrun --show-sdk-path)
ARCH = $(shell uname -m)
MIN_OS = 14.0

.PHONY: all build bundle sign run clean

all: run

build: $(BUILD_DIR)/$(APP_NAME)

$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	swiftc $(SOURCES) \
		-o $(BUILD_DIR)/$(APP_NAME) \
		-target $(ARCH)-apple-macosx$(MIN_OS) \
		-sdk $(SDK) \
		-framework AVFoundation \
		-framework CoreAudio \
		-parse-as-library

bundle: build
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Info.plist $(APP_BUNDLE)/Contents/

sign: bundle
	codesign -s - --entitlements VolumeControl.entitlements --force $(APP_BUNDLE)

run: sign
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)

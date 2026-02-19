APP_NAME := JustCopy
PROJECT := $(APP_NAME).xcodeproj
SCHEME := $(APP_NAME)
CONFIGURATION := Debug
BUILD_DIR := .build
APP_PATH := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app

.PHONY: generate build run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -derivedDataPath "$(BUILD_DIR)" CODE_SIGNING_ALLOWED=NO build

run: build
	open "$(APP_PATH)"

clean:
	rm -rf "$(BUILD_DIR)" "$(PROJECT)"

.PHONY: generate build test lint run clean

DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Bee.app

generate:
	xcodegen generate --quiet

build: generate
	xcodebuild -project Bee.xcodeproj -scheme Bee -configuration Debug -derivedDataPath $(DERIVED) -quiet build

test: generate
	xcodebuild -project Bee.xcodeproj -scheme Bee -derivedDataPath $(DERIVED) -quiet test

lint:
	swiftlint lint --strict

run: build
	open $(APP)

clean:
	rm -rf build Bee.xcodeproj

.PHONY: generate build test lint run release clean

DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Bee.app
RELEASE_APP := $(DERIVED)/Build/Products/Release/Bee.app
RELEASE_ZIP := build/Bee.zip

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

# Universal, ad-hoc signed build zipped for GitHub Releases and the Homebrew cask.
# ditto keeps the bundle's symlinks and signature intact, which plain zip does not.
release: generate
	xcodebuild -project Bee.xcodeproj -scheme Bee -configuration Release -derivedDataPath $(DERIVED) -quiet build
	rm -f $(RELEASE_ZIP)
	ditto -c -k --keepParent $(RELEASE_APP) $(RELEASE_ZIP)

clean:
	rm -rf build Bee.xcodeproj

.PHONY: generate build run clean editor-libs

editor-libs:
	bash scripts/build-editor.sh

generate:
	xcodegen generate

build: generate
	xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build

run: build
	open build/Build/Products/Debug/QMark.app

clean:
	rm -rf build DerivedData
	xcodebuild -project QMark.xcodeproj -scheme QMark clean 2>/dev/null || true

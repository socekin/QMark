.PHONY: generate build run clean editor-libs test test-restoration-policy

editor-libs:
	bash scripts/build-editor.sh

generate:
	xcodegen generate

build: generate
	xcodebuild -project QMark.xcodeproj -scheme QMark -configuration Debug -derivedDataPath build build

test: test-restoration-policy

test-restoration-policy:
	swiftc -parse-as-library QMark/WindowRestorationPolicy.swift scripts/test-window-restoration-policy.swift -o /tmp/qmark-window-restoration-policy-test
	/tmp/qmark-window-restoration-policy-test

run: build
	open build/Build/Products/Debug/QMark.app

clean:
	rm -rf build DerivedData
	xcodebuild -project QMark.xcodeproj -scheme QMark clean 2>/dev/null || true

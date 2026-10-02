---
name: macos-build
description: Generate the Xcode project with XcodeGen and build the NotchSuite macOS app, unsigned like CI. Use when asked whether the macOS app still builds, or after changing project.yml or the files in App/.
disable-model-invocation: true
allowed-tools:
  - Bash(xcodegen *)
  - Bash(xcodebuild build -project NotchSuite.xcodeproj *)
---

Build the macOS app from the repository root and report the result. `/swift-check` covers only the platform-independent package.

1. If `project.yml` is missing, say there is nothing to build and stop.
2. If `xcodegen` or `xcodebuild` isn't on `PATH`, say which is missing (`brew install xcodegen`, Xcode) and stop. This needs a Mac.
3. Run these in order, stopping at the first failure:
   1. `xcodegen generate`
   2. `xcodebuild build -project NotchSuite.xcodeproj -scheme NotchSuite -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
4. Report one line per step: passed or failed. For a failure, show the first real `error:` with `file:line` and the smallest useful excerpt, then propose a fix. Don't change any files unless asked.

On success, the app is at `build/DerivedData/Build/Products/Debug/NotchSuite.app`. It has no Dock icon; quit it from its status item.

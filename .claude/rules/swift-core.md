---
paths:
  - "Sources/NotchCore/**"
  - "Tests/NotchCoreTests/**"
---

# NotchCore rules

- Never import `AppKit`, `SwiftUI`, `Combine`, `Cocoa`, or `UIKit`. The Linux build fails if you do. Foundation is fine.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Use `@testable import NotchCore` to reach internal API.
- The package builds in Swift 6 language mode. Make public types `Sendable` value types unless there is a reason not to. Don't use `@unchecked Sendable` without a comment saying why it is safe.
- Reactive state uses `Observation` or async sequences.
- A Mac-only service gets a protocol here and its implementation in the app target.
- Code adapted from the reference projects follows `/port-from-reference`.
- Run `/swift-check` before pushing.

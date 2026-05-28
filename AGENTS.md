# AGENTS.md

This is a native iPadOS SwiftUI/PencilKit sketchbook app.

Use `MyiPadSketchbook.xcodeproj` as the active project.

Core invariants:

- PencilKit drawing is pencil-only.
- Pages are fixed-size dot-grid canvases arranged in a 2D coordinate grid.
- Do not introduce page zooming unless explicitly requested.
- SwiftData `Notebook` and `Page` models contain user data; treat model changes as migrations.
- Branch-specific bundle IDs/display names are intentional because they keep iPadOS data separate.

Useful commands:

```sh
xcodebuild -list -project MyiPadSketchbook.xcodeproj
```

```sh
xcodebuild \
  -project MyiPadSketchbook.xcodeproj \
  -scheme Debug \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' \
  build
```

Keep changes scoped, read relevant Swift files before editing, and do not revert user changes.

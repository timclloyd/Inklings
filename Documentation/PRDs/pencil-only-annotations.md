# Pencil-Only Notebook and Library Annotations

## Context

Inklings currently has a strong constraint: meaningful input happens through Apple Pencil. Page drawing already follows this model, while notebook and library views remain navigation surfaces.

This note explores adding PencilKit ink outside page view:

- notebook-view annotations over the spatial page map
- handwritten notebook labels in library view

The intent is not to add text fields, keyboards, or general UI editing. The feature should preserve the feeling that the app is a physical notebook system where the Pencil is the primary input tool.

## Product Shape

### Notebook view annotations

Notebook annotations should let the user mark, circle, label, and connect areas in the notebook overview. The ink should be freeform and persistent.

The best fit is a content-space overlay, not a display-space overlay. The ink should scroll with the notebook canvas so marks stay near the page clusters they refer to. It does not need to attach to individual pages or understand page positions semantically.

This keeps the behavior closer to writing on a large sheet laid behind the notebook thumbnails.

### Library notebook labels

Library naming should be visual ink attached to each notebook card. Each notebook card can own a small PencilKit drawing area used as its handwritten label or cover title.

The label should scroll with the card because it is part of the card. It does not need handwriting recognition at first, and it should not be treated as the semantic `Notebook.name` unless a later feature explicitly needs search, sorting, or text export.

This avoids keyboard input while still letting notebooks be distinguishable in the library.

## Non-Goals

- No page zooming.
- No handwriting recognition in the first version.
- No semantic text naming in the first version.
- No automatic attachment of notebook annotations to individual page thumbnails.
- No freeform display-level ink that drifts away from notebook content when scrolling.
- No changes to existing page drawing behavior.

## Suggested Data Model

This is a SwiftData migration because `Notebook` contains user data.

Likely additions:

- `Notebook.notebookAnnotationDrawingData: Data?`
- `Notebook.notebookAnnotationWidth: Double?`
- `Notebook.notebookAnnotationHeight: Double?`
- `Notebook.libraryLabelDrawingData: Data?`
- `Notebook.libraryLabelWidth: Double?`
- `Notebook.libraryLabelHeight: Double?`

The width and height fields let drawings scale predictably when the canvas size changes.

Alternative: create a separate annotation model keyed by notebook ID and annotation kind. That is cleaner if this may expand into multiple annotation layers later, but it is more ceremony for the first version.

## Interaction Model

The feature should use `PKCanvasView.drawingPolicy = .pencilOnly`.

Finger interactions should remain available:

- notebook view scrolls and pinches with fingers
- notebook rearrange mode still works
- library cards still tap to open
- library cards still long-press to trash
- add notebook still works

The tricky part is hit testing. A top-level or embedded `PKCanvasView` can intercept touches even when the drawing policy is pencil-only. The implementation may need a pass-through wrapper or gesture delegate behavior so finger touches continue to reach the SwiftUI and `UIScrollView` layers below.

## Implementation Sketch

### Shared PencilKit bridge

Create a separate annotation-oriented PencilKit wrapper instead of reusing the existing page drawing view. The current `PencilKitView` is page-specific: it owns page swipe/pinch gestures and saves into the current page drawing.

An annotation wrapper should:

- host a transparent `PKCanvasView`
- be pencil-only
- accept a `PKDrawing`
- report drawing changes
- avoid page navigation gestures
- expose enough configuration to support scroll-content overlays and card labels

### Notebook annotations

Notebook annotations likely belong inside `NotebookScrollView`, layered above the thumbnail content within the scroll view's content coordinate space.

That means the annotation canvas should have the same content size as the notebook layout. When the user scrolls, both thumbnails and ink move together.

Questions to resolve:

- Should annotations be allowed while rearranging pages?
- Should annotations be hidden or disabled during minimap interaction?
- Should eraser/lasso be shared with the page tool state?
- Should notebook annotations have undo/redo controls, or rely on PencilKit's internal undo only?

### Library labels

Each `LibraryNotebookTile` can include a small label band or overlay area containing a PencilKit canvas for that notebook's label drawing.

This should be deliberately bounded. An always-active full-card canvas risks conflicting with card tap and long-press. A label area is easier to reason about and makes the feature legible.

Questions to resolve:

- Is the label band always visible, or does it appear only when a card has ink?
- Does drawing in the label area prevent a tap from opening the notebook?
- Should erasing the whole label leave the notebook visually unnamed?
- Should the add-notebook card create a notebook immediately and allow writing its label in place?

## Difficulty Assessment

This is hard but bounded.

It is not simple because it requires new persistent drawing data, SwiftData migration work, additional PencilKit surfaces, tool/undo decisions, and careful gesture coexistence with notebook and library navigation.

It is not a "super can of worms" if labels remain visual ink and notebook annotations remain content-space ink. It becomes much larger if the app needs to infer text from handwriting, sort or search by handwritten names, attach annotations to individual pages, export annotations semantically, or keep annotations stable through substantial layout changes.

## Recommended First Version

1. Add per-notebook library label ink as visual-only data.
2. Add per-notebook content-space notebook annotation ink.
3. Keep recognition, search, sorting, and semantic names out of scope.
4. Preserve finger navigation and card gestures.
5. Add migration carefully and test with existing notebooks/pages.

This version supports the product goal while keeping the model honest: Pencil marks are Pencil marks, not hidden text fields.

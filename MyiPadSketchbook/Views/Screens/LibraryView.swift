//
//  LibraryView.swift
//  MyiPadSketchbook
//

import SwiftUI
import UIKit

// MARK: - LibraryView
struct LibraryView: View {
    @ObservedObject var pageManager: PageManager
    let topInset: CGFloat
    let onNotebookSelected: (Notebook) -> Void
    let onAddNotebook: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var notebookPendingTrash: Notebook?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(libraryRows) { row in
                    libraryRow(row)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, topInset)
            .padding(.bottom, 36)
        }
        .alert(
            "Move Notebook to Trash?",
            isPresented: Binding(
                get: { notebookPendingTrash != nil },
                set: { isPresented in
                    if !isPresented {
                        notebookPendingTrash = nil
                    }
                }
            ),
            presenting: notebookPendingTrash
        ) { notebook in
            Button("Move to Trash", role: .destructive) {
                pageManager.moveNotebookToTrash(notebook)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                notebookPendingTrash = nil
            }
            Button("Cancel", role: .cancel) {
                notebookPendingTrash = nil
            }
        } message: { _ in
            Text("This notebook will be hidden from the library. Its pages are kept for future trash recovery.")
        }
    }

    private var libraryRows: [LibraryBentoRow] {
        let notebookItems = pageManager.notebooks.map { notebook in
            let pages = pageManager.pages(in: notebook)
            return LibraryBentoItem.notebook(
                notebook,
                pages: pages,
                layout: LibraryNotebookTileLayout(pages: pages)
            )
        }

        return LibraryBentoLayout.rows(for: notebookItems + [.addNotebook])
    }

    @ViewBuilder
    private func libraryRow(_ row: LibraryBentoRow) -> some View {
        switch row {
        case .wide(let item):
            libraryItem(item)
        case .pair(let leading, let trailing):
            HStack(alignment: .top, spacing: 18) {
                libraryItem(leading)
                    .frame(maxWidth: .infinity)
                libraryItem(trailing)
                    .frame(maxWidth: .infinity)
            }
        case .single(let item):
            HStack(alignment: .top, spacing: 18) {
                libraryItem(item)
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func libraryItem(_ item: LibraryBentoItem) -> some View {
        switch item {
        case .notebook(let notebook, let pages, let layout):
            LibraryNotebookTile(
                pages: pages,
                colorScheme: colorScheme,
                aspectRatio: layout.aspectRatio
            )
            .gesture(notebookGesture(for: notebook))
        case .addNotebook:
            Button(action: onAddNotebook) {
                LibraryAddNotebookTile(colorScheme: colorScheme)
            }
            .buttonStyle(.plain)
        }
    }

    private func notebookGesture(for notebook: Notebook) -> some Gesture {
        ExclusiveGesture(
            LongPressGesture(minimumDuration: 0.5),
            TapGesture()
        )
        .onEnded { value in
            switch value {
            case .first(true):
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                notebookPendingTrash = notebook
            case .second:
                onNotebookSelected(notebook)
            default:
                break
            }
        }
    }
}

// MARK: - LibraryBentoLayout
enum LibraryBentoItem: Identifiable {
    case notebook(Notebook, pages: [Page], layout: LibraryNotebookTileLayout)
    case addNotebook

    var id: String {
        switch self {
        case .notebook(let notebook, _, _):
            "notebook-\(notebook.id?.uuidString ?? "")"
        case .addNotebook:
            "add-notebook"
        }
    }

    var columnSpan: Int {
        switch self {
        case .notebook(_, _, let layout):
            layout.columnSpan
        case .addNotebook:
            1
        }
    }
}

enum LibraryBentoRow: Identifiable {
    case wide(LibraryBentoItem)
    case pair(LibraryBentoItem, LibraryBentoItem)
    case single(LibraryBentoItem)

    var id: String {
        switch self {
        case .wide(let item):
            "wide-\(item.id)"
        case .pair(let leading, let trailing):
            "pair-\(leading.id)-\(trailing.id)"
        case .single(let item):
            "single-\(item.id)"
        }
    }
}

enum LibraryBentoLayout {
    static func rows(for items: [LibraryBentoItem]) -> [LibraryBentoRow] {
        var rows: [LibraryBentoRow] = []
        var pendingSingle: LibraryBentoItem?

        for item in items {
            if item.columnSpan == 2 {
                if let single = pendingSingle {
                    rows.append(.single(single))
                    pendingSingle = nil
                }
                rows.append(.wide(item))
            } else if let single = pendingSingle {
                rows.append(.pair(single, item))
                pendingSingle = nil
            } else {
                pendingSingle = item
            }
        }

        if let pendingSingle {
            rows.append(.single(pendingSingle))
        }

        return rows
    }
}

// MARK: - LibraryNotebookTileLayout
struct LibraryNotebookTileLayout {
    let columnSpan: Int
    let aspectRatio: CGFloat

    init(pages: [Page]) {
        let xPositions = pages.map { $0.positionX ?? 0 }
        let yPositions = pages.map { $0.positionY ?? 0 }
        let columns = max(1, (xPositions.max() ?? 0) - (xPositions.min() ?? 0) + 1)
        let rows = max(1, (yPositions.max() ?? 0) - (yPositions.min() ?? 0) + 1)

        self.init(columns: columns, rows: rows)
    }

    init(columns: Int, rows: Int) {
        let columns = max(1, columns)
        let rows = max(1, rows)
        let isWide = columns >= max(3, rows * 2)
        let isTall = rows >= max(3, columns * 2)

        columnSpan = isWide ? 2 : 1
        aspectRatio = isWide ? 2.08 : isTall ? 0.48 : 1
    }
}

// MARK: - LibraryAddNotebookTile
private struct LibraryAddNotebookTile: View {
    let colorScheme: ColorScheme

    private let cornerRadius: CGFloat = 12
    private var pageSurfaceColor: Color {
        AppTheme.Surface.pageSwiftUIColor(for: colorScheme)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(pageSurfaceColor)

                Image(systemName: "plus.circle")
                    .font(.system(size: toolbarButtonSize))
                    .foregroundColor(Color.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(pageSurfaceColor)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - LibraryNotebookTile
private struct LibraryNotebookTile: View {
    let pages: [Page]
    let colorScheme: ColorScheme
    let aspectRatio: CGFloat

    private let cornerRadius: CGFloat = 12
    private var pageSurfaceColor: Color {
        AppTheme.Surface.pageSwiftUIColor(for: colorScheme)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(pageSurfaceColor)

                NotebookPreview(
                    pages: pages,
                    colorScheme: colorScheme,
                    edgePadding: 0,
                    innerPadding: 18
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
            )
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

// MARK: - NotebookPreview
struct NotebookPreview: View {
    let pages: [Page]
    let colorScheme: ColorScheme
    var edgePadding: Int = 0
    var innerPadding: CGFloat = 18
    var pageSpacing: CGFloat = 3
    var viewport: CGRect? = nil
    var onPageSelected: ((Page) -> Void)? = nil
    var onContentPointChanged: ((CGPoint) -> Void)? = nil
    var onContentPointSelected: ((CGPoint) -> Void)? = nil
    var onGridPositionChanged: (((x: Int, y: Int)) -> Void)? = nil
    var onGridPositionSelected: (((x: Int, y: Int)) -> Void)? = nil

    private var previewSummary: NotebookPreviewSummary {
        NotebookPreviewSummary(pages: pages)
    }

    private var viewportColor: Color {
        colorScheme == .dark ? Color.white : Color.primary
    }

    var body: some View {
        GeometryReader { geometry in
            let summary = previewSummary
            let layout = previewLayout(in: geometry.size, summary: summary)

            if onPageSelected == nil &&
                onContentPointChanged == nil &&
                onContentPointSelected == nil &&
                onGridPositionChanged == nil &&
                onGridPositionSelected == nil {
                previewContent(summary: summary, layout: layout)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                previewContent(summary: summary, layout: layout)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectChangingLocation(value.location, summary: summary, layout: layout)
                            }
                            .onEnded { value in
                                selectLocation(value.location, summary: summary, layout: layout)
                            }
                    )
            }
        }
    }

    private func previewContent(summary: NotebookPreviewSummary, layout: PreviewLayout) -> some View {
        ZStack(alignment: .topLeading) {
            NotebookPreviewPagesLayer(
                summary: summary,
                layout: layout,
                colorScheme: colorScheme,
                edgePadding: edgePadding,
                pageSpacing: pageSpacing
            )
            .equatable()

            if let viewport {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(viewportColor.opacity(0.85), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(viewportColor.opacity(0.08))
                    )
                    .frame(
                        width: max(4, viewport.width * layout.contentSize.width),
                        height: max(4, viewport.height * layout.contentSize.height)
                    )
                    .position(
                        x: layout.origin.x + viewport.midX * layout.contentSize.width,
                        y: layout.origin.y + viewport.midY * layout.contentSize.height
                    )
            }
        }
    }

    private func previewLayout(in size: CGSize, summary: NotebookPreviewSummary) -> PreviewLayout {
        let columns = max(1, summary.maxX - summary.minX + 1 + (edgePadding * 2))
        let rows = max(1, summary.maxY - summary.minY + 1 + (edgePadding * 2))
        let availableWidth = max(1, size.width - (innerPadding * 2))
        let availableHeight = max(1, size.height - (innerPadding * 2))
        let pageAspectRatio = Page.legacyIPadPro11PageSize.width / Page.legacyIPadPro11PageSize.height
        let maxPageWidth = (availableWidth - CGFloat(max(0, columns - 1)) * pageSpacing) / CGFloat(columns)
        let maxPageHeight = (availableHeight - CGFloat(max(0, rows - 1)) * pageSpacing) / CGFloat(rows)
        let pageWidth = min(maxPageWidth, maxPageHeight * pageAspectRatio)
        let pageHeight = pageWidth / pageAspectRatio
        let pageCornerRadius = min(2, max(0.75, pageWidth * 0.08))
        let contentWidth = CGFloat(columns) * pageWidth + CGFloat(max(0, columns - 1)) * pageSpacing
        let contentHeight = CGFloat(rows) * pageHeight + CGFloat(max(0, rows - 1)) * pageSpacing
        let originX = (size.width - contentWidth) / 2
        let originY = (size.height - contentHeight) / 2

        return PreviewLayout(
            containerSize: size,
            origin: CGPoint(x: originX, y: originY),
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            pageCornerRadius: pageCornerRadius
        )
    }

    private func position(for page: Page, summary: NotebookPreviewSummary, layout: PreviewLayout) -> CGPoint {
        position(x: page.positionX ?? 0, y: page.positionY ?? 0, summary: summary, layout: layout)
    }

    private func position(x: Int, y: Int, summary: NotebookPreviewSummary, layout: PreviewLayout) -> CGPoint {
        CGPoint(
            x: layout.origin.x + CGFloat(x - summary.minX + edgePadding) * (layout.pageSize.width + pageSpacing) + layout.pageSize.width / 2,
            y: layout.origin.y + CGFloat(summary.maxY - y + edgePadding) * (layout.pageSize.height + pageSpacing) + layout.pageSize.height / 2
        )
    }

    private func selectNearestPage(to location: CGPoint, summary: NotebookPreviewSummary, layout: PreviewLayout) {
        guard let onPageSelected,
              let nearestPage = pages.min(by: {
                  distanceSquared(from: location, to: position(for: $0, summary: summary, layout: layout)) < distanceSquared(from: location, to: position(for: $1, summary: summary, layout: layout))
              }) else { return }

        onPageSelected(nearestPage)
    }

    private func selectLocation(_ location: CGPoint, summary: NotebookPreviewSummary, layout: PreviewLayout) {
        if let onContentPointSelected {
            onContentPointSelected(contentPoint(for: location, layout: layout))
        } else if let onGridPositionSelected {
            onGridPositionSelected(gridPosition(for: location, summary: summary, layout: layout))
        } else {
            selectNearestPage(to: location, summary: summary, layout: layout)
        }
    }

    private func selectChangingLocation(_ location: CGPoint, summary: NotebookPreviewSummary, layout: PreviewLayout) {
        if let onContentPointChanged {
            onContentPointChanged(contentPoint(for: location, layout: layout))
        } else if let onGridPositionChanged {
            onGridPositionChanged(gridPosition(for: location, summary: summary, layout: layout))
        }
    }

    private func contentPoint(for location: CGPoint, layout: PreviewLayout) -> CGPoint {
        CGPoint(
            x: min(max(0, (location.x - layout.origin.x) / max(1, layout.contentSize.width)), 1),
            y: min(max(0, (location.y - layout.origin.y) / max(1, layout.contentSize.height)), 1)
        )
    }

    private func gridPosition(for location: CGPoint, summary: NotebookPreviewSummary, layout: PreviewLayout) -> (x: Int, y: Int) {
        let columnStride = layout.pageSize.width + pageSpacing
        let rowStride = layout.pageSize.height + pageSpacing
        let columns = max(1, summary.maxX - summary.minX + 1 + (edgePadding * 2))
        let rows = max(1, summary.maxY - summary.minY + 1 + (edgePadding * 2))
        let column = min(max(0, Int(round((location.x - layout.origin.x - layout.pageSize.width / 2) / columnStride))), columns - 1)
        let row = min(max(0, Int(round((location.y - layout.origin.y - layout.pageSize.height / 2) / rowStride))), rows - 1)

        return (
            x: summary.minX - edgePadding + column,
            y: summary.maxY + edgePadding - row
        )
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private struct PreviewLayout: Equatable {
        let containerSize: CGSize
        let origin: CGPoint
        let contentSize: CGSize
        let pageSize: CGSize
        let pageCornerRadius: CGFloat
    }

    private struct NotebookPreviewPagesLayer: View, Equatable {
        let summary: NotebookPreviewSummary
        let layout: PreviewLayout
        let colorScheme: ColorScheme
        let edgePadding: Int
        let pageSpacing: CGFloat

        private var pageColor: Color {
            colorScheme == .dark ? Color(.systemGray2) : Color(.systemGray3)
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                ForEach(summary.pages) { page in
                    RoundedRectangle(cornerRadius: layout.pageCornerRadius)
                        .fill(pageColor)
                        .frame(width: layout.pageSize.width, height: layout.pageSize.height)
                        .position(position(for: page))
                }
            }
            .frame(width: layout.containerSize.width, height: layout.containerSize.height)
        }

        private func position(for page: NotebookPreviewSummary.PagePosition) -> CGPoint {
            CGPoint(
                x: layout.origin.x + CGFloat(page.x - summary.minX + edgePadding) * (layout.pageSize.width + pageSpacing) + layout.pageSize.width / 2,
                y: layout.origin.y + CGFloat(summary.maxY - page.y + edgePadding) * (layout.pageSize.height + pageSpacing) + layout.pageSize.height / 2
            )
        }
    }
}

private struct NotebookPreviewSummary: Equatable {
    let pages: [PagePosition]
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int

    init(pages: [Page]) {
        let pagePositions = pages.map { page in
            PagePosition(
                id: page.id?.uuidString ?? "\(page.positionX ?? 0)_\(page.positionY ?? 0)",
                x: page.positionX ?? 0,
                y: page.positionY ?? 0
            )
        }
        let xPositions = pagePositions.map(\.x)
        let yPositions = pagePositions.map(\.y)

        self.pages = pagePositions
        minX = xPositions.min() ?? 0
        maxX = xPositions.max() ?? 0
        minY = yPositions.min() ?? 0
        maxY = yPositions.max() ?? 0
    }

    struct PagePosition: Identifiable, Equatable {
        let id: String
        let x: Int
        let y: Int
    }
}

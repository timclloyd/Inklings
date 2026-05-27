//
//  NotebookView.swift
//  MyiPadSketchbook
//

import SwiftUI

// MARK: - NotebookView
struct NotebookView: View {
    @ObservedObject var pageManager: PageManager
    let topInset: CGFloat
    let onNotebookSelected: (Notebook) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18)
            ], spacing: 18) {
                ForEach(pageManager.notebooks) { notebook in
                    NotebookTile(
                        pages: pageManager.pages(in: notebook),
                        colorScheme: colorScheme
                    )
                    .onTapGesture {
                        onNotebookSelected(notebook)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, topInset)
            .padding(.bottom, 36)
        }
    }
}

// MARK: - NotebookTile
private struct NotebookTile: View {
    let pages: [Page]
    let colorScheme: ColorScheme

    private let cornerRadius: CGFloat = 8

    private var fillColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)

                NotebookMapPreview(
                    pages: pages,
                    colorScheme: colorScheme,
                    edgePadding: 0,
                    innerPadding: 18
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - NotebookMapPreview
struct NotebookMapPreview: View {
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

    private var pagePositions: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let xPositions = pages.map { $0.positionX ?? 0 }
        let yPositions = pages.map { $0.positionY ?? 0 }

        return (
            minX: xPositions.min() ?? 0,
            maxX: xPositions.max() ?? 0,
            minY: yPositions.min() ?? 0,
            maxY: yPositions.max() ?? 0
        )
    }

    private var pageColor: Color {
        colorScheme == .dark ? Color(.systemGray2) : Color(.systemGray3)
    }

    private var viewportColor: Color {
        colorScheme == .dark ? Color.white : Color.primary
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = previewLayout(in: geometry.size)

            if onPageSelected == nil &&
                onContentPointChanged == nil &&
                onContentPointSelected == nil &&
                onGridPositionChanged == nil &&
                onGridPositionSelected == nil {
                previewContent(layout: layout)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                previewContent(layout: layout)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectChangingLocation(value.location, layout: layout)
                            }
                            .onEnded { value in
                                selectLocation(value.location, layout: layout)
                            }
                    )
            }
        }
    }

    private func previewContent(layout: PreviewLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(pages) { page in
                RoundedRectangle(cornerRadius: layout.pageCornerRadius)
                    .fill(pageColor)
                    .frame(width: layout.pageSize.width, height: layout.pageSize.height)
                    .position(position(for: page, layout: layout))
            }

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

    private func previewLayout(in size: CGSize) -> PreviewLayout {
        let columns = max(1, pagePositions.maxX - pagePositions.minX + 1 + (edgePadding * 2))
        let rows = max(1, pagePositions.maxY - pagePositions.minY + 1 + (edgePadding * 2))
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
            origin: CGPoint(x: originX, y: originY),
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            pageCornerRadius: pageCornerRadius
        )
    }

    private func position(for page: Page, layout: PreviewLayout) -> CGPoint {
        CGPoint(
            x: layout.origin.x + CGFloat((page.positionX ?? 0) - pagePositions.minX + edgePadding) * (layout.pageSize.width + pageSpacing) + layout.pageSize.width / 2,
            y: layout.origin.y + CGFloat(pagePositions.maxY - (page.positionY ?? 0) + edgePadding) * (layout.pageSize.height + pageSpacing) + layout.pageSize.height / 2
        )
    }

    private func selectNearestPage(to location: CGPoint, layout: PreviewLayout) {
        guard let onPageSelected,
              let nearestPage = pages.min(by: {
                  distanceSquared(from: location, to: position(for: $0, layout: layout)) < distanceSquared(from: location, to: position(for: $1, layout: layout))
              }) else { return }

        onPageSelected(nearestPage)
    }

    private func selectLocation(_ location: CGPoint, layout: PreviewLayout) {
        if let onContentPointSelected {
            onContentPointSelected(contentPoint(for: location, layout: layout))
        } else if let onGridPositionSelected {
            onGridPositionSelected(gridPosition(for: location, layout: layout))
        } else {
            selectNearestPage(to: location, layout: layout)
        }
    }

    private func selectChangingLocation(_ location: CGPoint, layout: PreviewLayout) {
        if let onContentPointChanged {
            onContentPointChanged(contentPoint(for: location, layout: layout))
        } else if let onGridPositionChanged {
            onGridPositionChanged(gridPosition(for: location, layout: layout))
        }
    }

    private func contentPoint(for location: CGPoint, layout: PreviewLayout) -> CGPoint {
        CGPoint(
            x: min(max(0, (location.x - layout.origin.x) / max(1, layout.contentSize.width)), 1),
            y: min(max(0, (location.y - layout.origin.y) / max(1, layout.contentSize.height)), 1)
        )
    }

    private func gridPosition(for location: CGPoint, layout: PreviewLayout) -> (x: Int, y: Int) {
        let columnStride = layout.pageSize.width + pageSpacing
        let rowStride = layout.pageSize.height + pageSpacing
        let columns = max(1, pagePositions.maxX - pagePositions.minX + 1 + (edgePadding * 2))
        let rows = max(1, pagePositions.maxY - pagePositions.minY + 1 + (edgePadding * 2))
        let column = min(max(0, Int(round((location.x - layout.origin.x - layout.pageSize.width / 2) / columnStride))), columns - 1)
        let row = min(max(0, Int(round((location.y - layout.origin.y - layout.pageSize.height / 2) / rowStride))), rows - 1)

        return (
            x: pagePositions.minX - edgePadding + column,
            y: pagePositions.maxY + edgePadding - row
        )
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private struct PreviewLayout {
        let origin: CGPoint
        let contentSize: CGSize
        let pageSize: CGSize
        let pageCornerRadius: CGFloat
    }
}

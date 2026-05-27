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
    private let innerPadding: CGFloat = 18
    private let pageSpacing: CGFloat = 3

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

    private var fillColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }

    private var pageColor: Color {
        colorScheme == .dark ? Color(.systemGray2) : Color(.systemGray3)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)

                pageLayout(in: geometry.size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func pageLayout(in size: CGSize) -> some View {
        let columns = max(1, pagePositions.maxX - pagePositions.minX + 1)
        let rows = max(1, pagePositions.maxY - pagePositions.minY + 1)
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

        return ZStack(alignment: .topLeading) {
            ForEach(pages) { page in
                RoundedRectangle(cornerRadius: pageCornerRadius)
                    .fill(pageColor)
                    .frame(width: pageWidth, height: pageHeight)
                    .position(
                        x: originX + CGFloat((page.positionX ?? 0) - pagePositions.minX) * (pageWidth + pageSpacing) + pageWidth / 2,
                        y: originY + CGFloat(pagePositions.maxY - (page.positionY ?? 0)) * (pageHeight + pageSpacing) + pageHeight / 2
                    )
            }
        }
    }
}

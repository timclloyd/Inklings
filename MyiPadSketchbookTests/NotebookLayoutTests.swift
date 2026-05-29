//
//  NotebookLayoutTests.swift
//  MyiPadSketchbookTests
//
//  Created by Tim Lloyd on 2024-08-06.
//

import SwiftUI
import XCTest
@testable import MyiPadSketchbook

final class NotebookLayoutTests: XCTestCase {
    func testNotebookOverviewPreviewUsesScrollLayoutEdgePadding() throws {
        let pages = [
            Page(positionX: 0, positionY: 0),
            Page(positionX: 2, positionY: -1)
        ]
        let layout = NotebookLayout(
            pages: pages,
            thumbnailSize: CGSize(width: 120, height: 160),
            spacing: 6,
            edgePadding: 4
        )

        XCTAssertEqual(NotebookOverviewLayout.previewEdgePadding(for: layout), layout.edgePadding)
    }

    func testNotebookContentRevisionChangesDuringDrag() throws {
        let page = Page(positionX: 0, positionY: 0)
        let restingRevision = NotebookContentRevision.make(
            pages: [page],
            thumbnailCacheRevision: 0,
            isRearranging: true,
            draggedPage: nil,
            draggedPageOffset: .zero,
            colorScheme: .light
        )
        let dragStartedRevision = NotebookContentRevision.make(
            pages: [page],
            thumbnailCacheRevision: 0,
            isRearranging: true,
            draggedPage: page,
            draggedPageOffset: .zero,
            colorScheme: .light
        )
        let dragMovedRevision = NotebookContentRevision.make(
            pages: [page],
            thumbnailCacheRevision: 0,
            isRearranging: true,
            draggedPage: page,
            draggedPageOffset: CGSize(width: 18, height: -24),
            colorScheme: .light
        )

        XCTAssertNotEqual(restingRevision, dragStartedRevision)
        XCTAssertNotEqual(dragStartedRevision, dragMovedRevision)
    }
}

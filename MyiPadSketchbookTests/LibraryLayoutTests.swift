//
//  LibraryLayoutTests.swift
//  MyiPadSketchbookTests
//
//  Created by Tim Lloyd on 2024-08-06.
//

import XCTest
@testable import MyiPadSketchbook

final class LibraryLayoutTests: XCTestCase {
    func testLibraryNotebookTileLayoutUsesSingleColumnForSquareNotebooks() throws {
        let layout = LibraryNotebookTileLayout(columns: 2, rows: 2)

        XCTAssertEqual(layout.columnSpan, 1)
        XCTAssertEqual(layout.aspectRatio, 1)
    }

    func testLibraryNotebookTileLayoutUsesTwoColumnsForWideNotebooks() throws {
        let layout = LibraryNotebookTileLayout(columns: 3, rows: 1)

        XCTAssertEqual(layout.columnSpan, 2)
        XCTAssertGreaterThan(layout.aspectRatio, 1)
    }

    func testLibraryNotebookTileLayoutUsesTallSingleColumnForTallNotebooks() throws {
        let layout = LibraryNotebookTileLayout(columns: 1, rows: 3)

        XCTAssertEqual(layout.columnSpan, 1)
        XCTAssertLessThan(layout.aspectRatio, 1)
    }

    func testLibraryBentoLayoutGivesWideNotebookItsOwnRow() throws {
        let squareNotebook = Notebook(name: "Square")
        let wideNotebook = Notebook(name: "Wide")
        let squareItem = LibraryBentoItem.notebook(
            squareNotebook,
            pages: [],
            layout: LibraryNotebookTileLayout(pages: [])
        )
        let wideItem = LibraryBentoItem.notebook(
            wideNotebook,
            pages: [],
            layout: LibraryNotebookTileLayout(columns: 3, rows: 1)
        )

        let rows = LibraryBentoLayout.rows(for: [squareItem, wideItem, .addNotebook])

        XCTAssertEqual(rows.count, 3)
        if case .single = rows[0] {} else {
            XCTFail("Expected pending square notebook to stay in a single-column row before a wide notebook.")
        }
        if case .wide = rows[1] {} else {
            XCTFail("Expected wide notebook to occupy its own row.")
        }
        if case .single = rows[2] {} else {
            XCTFail("Expected add notebook tile to remain a single-column row.")
        }
    }
}

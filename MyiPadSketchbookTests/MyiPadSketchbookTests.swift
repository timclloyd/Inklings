//
//  MyiPadSketchbookTests.swift
//  MyiPadSketchbookTests
//
//  Created by Tim Lloyd on 2024-08-06.
//

import PencilKit
import SwiftData
import XCTest
@testable import MyiPadSketchbook

@MainActor
final class MyiPadSketchbookTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        clearPersistentSelection()
        container = try makeModelContainer()
    }

    override func tearDownWithError() throws {
        clearPersistentSelection()
        container = nil
        try super.tearDownWithError()
    }

    func testInitialisationCreatesNotebookAndPageWhenStoreIsEmpty() throws {
        let manager = PageManager(modelContext: container.mainContext)

        XCTAssertEqual(manager.notebooks.count, 1)
        XCTAssertEqual(manager.pages.count, 1)
        XCTAssertEqual(manager.getCurrentPage()?.positionX, 0)
        XCTAssertEqual(manager.getCurrentPage()?.positionY, 0)
        XCTAssertEqual(manager.getCurrentPage()?.notebookID, manager.currentNotebookID)
    }

    func testInitialisationMigratesPagesWithoutNotebookToFirstNotebook() throws {
        let notebook = Notebook(name: "Existing Notebook")
        let orphanedPage = Page(positionX: 4, positionY: -2, notebookID: nil)
        container.mainContext.insert(notebook)
        container.mainContext.insert(orphanedPage)
        try container.mainContext.save()

        let manager = PageManager(modelContext: container.mainContext)

        XCTAssertEqual(orphanedPage.notebookID, notebook.id)
        XCTAssertEqual(manager.pages.map(\.id), [orphanedPage.id])
        XCTAssertEqual(manager.currentNotebookID, notebook.id)
    }

    func testInitialisationMigratesPagesWithoutStoredPageSize() throws {
        let notebook = Notebook(name: "Existing Notebook")
        let page = Page(positionX: 0, positionY: 0, pageSize: CGSize(width: 200, height: 300), notebookID: notebook.id)
        page.pageWidth = nil
        page.pageHeight = nil
        container.mainContext.insert(notebook)
        container.mainContext.insert(page)
        try container.mainContext.save()

        _ = PageManager(modelContext: container.mainContext)

        XCTAssertEqual(page.pageSize, Page.legacyIPadPro11PageSize)
    }

    func testCreatePageAssignsCurrentNotebook() throws {
        let manager = PageManager(modelContext: container.mainContext)

        let page = manager.createPage(position: (2, -3))

        XCTAssertEqual(page.notebookID, manager.currentNotebookID)
        XCTAssertTrue(manager.pages.contains { $0.id == page.id })
    }

    func testSwitchToNotebookFiltersPagesAndRestoresLastSelectedPage() throws {
        let firstNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 1), name: "First")
        let secondNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 2), name: "Second")
        let firstPage = Page(positionX: 0, positionY: 0, notebookID: firstNotebook.id)
        let secondPageA = Page(positionX: 10, positionY: 10, notebookID: secondNotebook.id)
        let secondPageB = Page(positionX: 11, positionY: 10, notebookID: secondNotebook.id)
        secondNotebook.lastSelectedPageID = secondPageB.id

        container.mainContext.insert(firstNotebook)
        container.mainContext.insert(secondNotebook)
        container.mainContext.insert(firstPage)
        container.mainContext.insert(secondPageA)
        container.mainContext.insert(secondPageB)
        try container.mainContext.save()

        let manager = PageManager(modelContext: container.mainContext)
        manager.switchToNotebook(secondNotebook)

        XCTAssertEqual(manager.currentNotebookID, secondNotebook.id)
        XCTAssertEqual(Set(manager.pages.compactMap(\.id)), Set([secondPageA.id, secondPageB.id]))
        XCTAssertEqual(manager.getCurrentPage()?.id, secondPageB.id)
        XCTAssertFalse(manager.pages.contains { $0.id == firstPage.id })
    }

    func testSwitchToNotebookCreatesInitialPageWhenNotebookIsEmpty() throws {
        let populatedNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 1), name: "Populated")
        let emptyNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 2), name: "Empty")
        let existingPage = Page(positionX: 4, positionY: 4, notebookID: populatedNotebook.id)
        container.mainContext.insert(populatedNotebook)
        container.mainContext.insert(emptyNotebook)
        container.mainContext.insert(existingPage)
        try container.mainContext.save()

        let manager = PageManager(modelContext: container.mainContext)

        manager.switchToNotebook(emptyNotebook)

        XCTAssertEqual(manager.pages.count, 1)
        XCTAssertEqual(manager.getCurrentPage()?.positionX, 0)
        XCTAssertEqual(manager.getCurrentPage()?.positionY, 0)
        XCTAssertEqual(manager.getCurrentPage()?.notebookID, emptyNotebook.id)
    }

    func testAddPageCreatesExpectedHorizontalAndVerticalCoordinates() throws {
        let manager = PageManager(modelContext: container.mainContext)

        manager.addPage(translation: CGSize(width: -120, height: 10))
        XCTAssertEqual(manager.getCurrentPage()?.positionX, 1)
        XCTAssertEqual(manager.getCurrentPage()?.positionY, 0)

        manager.addPage(translation: CGSize(width: 5, height: -120))
        XCTAssertEqual(manager.getCurrentPage()?.positionX, 1)
        XCTAssertEqual(manager.getCurrentPage()?.positionY, -1)
    }

    func testAddPageSelectsExistingPageInsteadOfCreatingDuplicate() throws {
        let manager = PageManager(modelContext: container.mainContext)

        manager.addPage(translation: CGSize(width: -100, height: 0))
        let createdPage = try XCTUnwrap(manager.getCurrentPage())
        manager.addPage(translation: CGSize(width: 100, height: 0))
        manager.addPage(translation: CGSize(width: -100, height: 0))

        XCTAssertEqual(manager.getCurrentPage()?.id, createdPage.id)
        XCTAssertEqual(manager.pages.filter { $0.positionX == 1 && $0.positionY == 0 }.count, 1)
    }

    func testPreviousPageTracksNavigation() throws {
        let manager = PageManager(modelContext: container.mainContext)
        let firstPage = try XCTUnwrap(manager.getCurrentPage())
        let secondPage = manager.createPage(position: (1, 0))

        manager.setCurrentPage(secondPage)

        let previousPage = manager.goToPreviousPage()

        XCTAssertEqual(previousPage?.id, firstPage.id)
        XCTAssertEqual(manager.getCurrentPage()?.id, firstPage.id)
        XCTAssertEqual(manager.previousPageID, secondPage.id)
    }

    func testSetCurrentPagePersistsLastSelectedPageForNotebook() throws {
        let manager = PageManager(modelContext: container.mainContext)
        let notebook = try XCTUnwrap(manager.notebooks.first)
        let page = manager.createPage(position: (3, 3))

        manager.setCurrentPage(page)

        XCTAssertEqual(notebook.lastSelectedPageID, page.id)
    }

    func testInitialisationUsesSavedNotebookWhenItExists() throws {
        let firstNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 1), name: "First")
        let secondNotebook = Notebook(createdAt: Date(timeIntervalSince1970: 2), name: "Second")
        let firstPage = Page(positionX: 0, positionY: 0, notebookID: firstNotebook.id)
        let secondPage = Page(positionX: 7, positionY: 8, notebookID: secondNotebook.id)

        container.mainContext.insert(firstNotebook)
        container.mainContext.insert(secondNotebook)
        container.mainContext.insert(firstPage)
        container.mainContext.insert(secondPage)
        try container.mainContext.save()
        UserDefaults.standard.set(secondNotebook.id?.uuidString, forKey: "CurrentNotebookID")
        UserDefaults.standard.set(7, forKey: "CurrentPageX")
        UserDefaults.standard.set(8, forKey: "CurrentPageY")

        let manager = PageManager(modelContext: container.mainContext)

        XCTAssertEqual(manager.currentNotebookID, secondNotebook.id)
        XCTAssertEqual(manager.getCurrentPage()?.id, secondPage.id)
    }

    func testDrawingForDisplayHandlesMissingOrCorruptData() throws {
        let manager = PageManager(modelContext: container.mainContext)
        let page = try XCTUnwrap(manager.getCurrentPage())
        page.drawingData = Data("not a PencilKit drawing".utf8)

        let drawing = manager.drawingForDisplay(for: page)

        XCTAssertTrue(drawing.strokes.isEmpty)
    }

    func testUpdateDrawingStoresDataAndCurrentPageSize() throws {
        let manager = PageManager(modelContext: container.mainContext)
        let page = try XCTUnwrap(manager.getCurrentPage())
        manager.updatePageSize(CGSize(width: 512, height: 768))

        manager.updateDrawing(PKDrawing())

        XCTAssertEqual(page.pageSize, CGSize(width: 512, height: 768))
        let storedDrawingData = try XCTUnwrap(page.drawingData)
        XCTAssertTrue(try PKDrawing(data: storedDrawingData).strokes.isEmpty)
        XCTAssertNotNil(page.thumbnailData)
    }

    func testCanvasFileGeneratorProducesCoordinateBasedNodes() throws {
        let pages = [
            Page(positionX: 0, positionY: 0),
            Page(positionX: 2, positionY: -1),
            Page(positionX: -1, positionY: 3)
        ]
        let json = try CanvasFileGenerator().generateCanvasFile(pages: pages, appName: "Inklings")
        let canvasFile = try JSONDecoder().decode(CanvasFile.self, from: Data(json.utf8))

        XCTAssertEqual(canvasFile.edges, [])
        XCTAssertEqual(canvasFile.nodes.count, 3)

        let originNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/0,0.jpeg" })
        XCTAssertEqual(originNode.type, "file")
        XCTAssertEqual(originNode.x, -180)
        XCTAssertEqual(originNode.y, -200)
        XCTAssertEqual(originNode.width, 279)
        XCTAssertEqual(originNode.height, 399)

        let positiveXNegativeYNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/2,-1.jpeg" })
        XCTAssertEqual(positiveXNegativeYNode.x, 378)
        XCTAssertEqual(positiveXNegativeYNode.y, 200)

        let negativeXPositiveYNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/-1,3.jpeg" })
        XCTAssertEqual(negativeXPositiveYNode.x, -459)
        XCTAssertEqual(negativeXPositiveYNode.y, -1400)
    }

    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Notebook.self,
            Page.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func clearPersistentSelection() {
        UserDefaults.standard.removeObject(forKey: "CurrentNotebookID")
        UserDefaults.standard.removeObject(forKey: "CurrentPageX")
        UserDefaults.standard.removeObject(forKey: "CurrentPageY")
    }
}

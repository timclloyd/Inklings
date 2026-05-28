//
//  ViewModels.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import PencilKit
import SwiftData

// MARK: - PageManager
@MainActor
class PageManager: ObservableObject {
    @Published var currentPageID: UUID?
    @Published var previousPageID: UUID?
    @Published var pages: [Page] = []
    @Published var notebooks: [Notebook] = []
    @Published var currentNotebookID: UUID?
    @Published private(set) var pageRect: CGRect
    
    private var modelContext: ModelContext
    private var allPages: [Page] = []
    
    // MARK: - Initialisation
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let screenSize = UIScreen.main.bounds.size
        self.pageRect = CGRect(origin: .zero, size: screenSize)
        
        loadNotebooks()
        loadPages()
        migrateNotebookOwnership()
        selectInitialNotebook()
        refreshCurrentNotebookPages()

        if migratePagesMissingPageSize() {
            updateAllThumbnails()
            try? modelContext.save()
        }
        
        // Load saved position
        let savedX = UserDefaults.standard.integer(forKey: "CurrentPageX")
        let savedY = UserDefaults.standard.integer(forKey: "CurrentPageY")
        
        if let savedPage = pages.first(where: { $0.positionX == savedX && $0.positionY == savedY }) {
            currentPageID = savedPage.id
        } else if let firstPage = pages.first {
            currentPageID = firstPage.id
        } else {
            let initialPage = createPage(position: (0, 0))
            currentPageID = initialPage.id
        }
    }
    
    // MARK: - Page handling
    func createPage(position: (x: Int, y: Int)) -> Page {
        let newPage = Page(positionX: position.x, positionY: position.y, pageSize: pageRect.size, notebookID: currentNotebookID)
        modelContext.insert(newPage)
        allPages.append(newPage)
        pages.append(newPage)
        updateThumbnail(for: newPage)
        return newPage
    }
    
    func setCurrentPage(_ page: Page, updatePrevious: Bool = true) {
        if updatePrevious {
            previousPageID = currentPageID
        }
        currentPageID = page.id
        saveLastSelectedPage(page)
        // Save current page position
        UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
        UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
    }
    
    func goToPreviousPage() -> Page? {
        guard let previousPageID = previousPageID,
              let previousPage = pages.first(where: { $0.id == previousPageID }) else {
            return nil
        }
        
        let currentPage = getCurrentPage()
        self.currentPageID = previousPageID
        self.previousPageID = currentPage?.id
        saveLastSelectedPage(previousPage)
        
        // Save current page position
        UserDefaults.standard.set(previousPage.positionX, forKey: "CurrentPageX")
        UserDefaults.standard.set(previousPage.positionY, forKey: "CurrentPageY")
        
        return previousPage
    }
    
    func addPage(translation: CGSize) {
        guard let currentPage = getCurrentPage() else { return }
        
        var newPosition = (x: currentPage.positionX, y: currentPage.positionY)
        
        if abs(translation.width) > abs(translation.height) {
            // Horizontal movement
            newPosition.x! += translation.width > 0 ? -1 : 1
        } else {
            // Vertical movement
            newPosition.y! += translation.height < 0 ? -1 : 1
        }
        
        let existingPage = pages.first { $0.positionX == newPosition.x && $0.positionY == newPosition.y }
        
        if let existingPage = existingPage {
            setCurrentPage(existingPage, updatePrevious: false)
        } else {
            let newPage = createPage(position: (newPosition.x!, newPosition.y!))
            setCurrentPage(newPage, updatePrevious: false)
        }
    }
    
    func getCurrentPage() -> Page? {
        guard let currentPageID = currentPageID else { return nil }
        return pages.first { $0.id == currentPageID }
    }

    func updatePageSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        let currentSize = pageRect.size
        guard abs(currentSize.width - size.width) > 0.5 || abs(currentSize.height - size.height) > 0.5 else {
            return
        }

        pageRect = CGRect(origin: .zero, size: size)
        updateAllThumbnails()
    }

    // MARK: - Notebook handling
    func createNotebook() -> Notebook {
        let notebook = Notebook(name: "Notebook \(notebooks.count + 1)")
        modelContext.insert(notebook)
        notebooks.append(notebook)
        sortNotebooks()
        switchToNotebook(notebook)
        try? modelContext.save()
        return notebook
    }

    func switchToNotebook(_ notebook: Notebook) {
        guard let notebookID = notebook.id else { return }

        currentNotebookID = notebookID
        UserDefaults.standard.set(notebookID.uuidString, forKey: "CurrentNotebookID")
        previousPageID = nil
        refreshCurrentNotebookPages()

        if let firstPage = pages.first {
            let page = pages.first(where: { $0.id == notebook.lastSelectedPageID }) ?? firstPage
            currentPageID = page.id
            saveCurrentPagePosition(page)
            saveLastSelectedPage(page)
        } else {
            let initialPage = createPage(position: (0, 0))
            currentPageID = initialPage.id
            saveCurrentPagePosition(initialPage)
            saveLastSelectedPage(initialPage)
        }
    }

    func pages(in notebook: Notebook) -> [Page] {
        allPages.filter { $0.notebookID == notebook.id }
    }

    func moveNotebookToTrash(_ notebook: Notebook) {
        guard let notebookID = notebook.id else { return }

        let movingCurrentNotebookToTrash = currentNotebookID == notebookID
        notebook.deletedAt = Date()
        notebooks.removeAll { $0.id == notebookID }

        if notebooks.isEmpty {
            _ = createNotebook()
        } else if movingCurrentNotebookToTrash {
            sortNotebooks()
            switchToNotebook(notebooks[0])
        } else {
            refreshCurrentNotebookPages()
        }

        try? modelContext.save()
    }
    
    func updatePagePosition(_ page: Page) {
        objectWillChange.send()
        try? modelContext.save()
        // Update saved position if this is the current page
        if page.id == currentPageID {
            UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
            UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
        }
    }
    
    // MARK: - Drawing
    func updateDrawing(_ drawing: PKDrawing) {
        guard let currentPage = getCurrentPage() else { return }
        currentPage.drawingData = drawing.dataRepresentation()
        currentPage.setPageSize(pageRect.size)
        updateThumbnail(for: currentPage)
    }

    func drawingForDisplay(for page: Page?) -> PKDrawing {
        guard let page,
              let drawingData = page.drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            return PKDrawing()
        }

        return drawing.scaled(from: page.pageSize, to: pageRect.size)
    }

    private func migratePagesMissingPageSize() -> Bool {
        var didMigrate = false

        for page in pages where page.pageWidth == nil || page.pageHeight == nil {
            page.setPageSize(Page.legacyIPadPro11PageSize)
            didMigrate = true
        }

        return didMigrate
    }

    private func loadNotebooks() {
        let descriptor = FetchDescriptor<Notebook>()
        notebooks = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.deletedAt == nil }

        if notebooks.isEmpty {
            let firstNotebook = Notebook(name: "Notebook 1")
            modelContext.insert(firstNotebook)
            notebooks = [firstNotebook]
        }

        sortNotebooks()
    }

    private func loadPages() {
        let descriptor = FetchDescriptor<Page>()
        allPages = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func migrateNotebookOwnership() {
        guard let firstNotebookID = notebooks.first?.id else { return }
        var didMigrate = false

        for page in allPages where page.notebookID == nil {
            page.notebookID = firstNotebookID
            didMigrate = true
        }

        if didMigrate {
            try? modelContext.save()
        }
    }

    private func selectInitialNotebook() {
        if let savedIDString = UserDefaults.standard.string(forKey: "CurrentNotebookID"),
           let savedID = UUID(uuidString: savedIDString),
           notebooks.contains(where: { $0.id == savedID }) {
            currentNotebookID = savedID
        } else {
            currentNotebookID = notebooks.first?.id
        }
    }

    private func refreshCurrentNotebookPages() {
        pages = allPages.filter { $0.notebookID == currentNotebookID }
    }

    private func sortNotebooks() {
        notebooks.sort {
            let leftDate = $0.createdAt ?? .distantPast
            let rightDate = $1.createdAt ?? .distantPast

            if leftDate == rightDate {
                return ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "")
            }

            return leftDate < rightDate
        }
    }

    private func saveCurrentPagePosition(_ page: Page) {
        UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
        UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
    }

    private func saveLastSelectedPage(_ page: Page) {
        guard let notebookID = page.notebookID,
              let notebook = notebooks.first(where: { $0.id == notebookID }),
              notebook.lastSelectedPageID != page.id else {
            return
        }

        notebook.lastSelectedPageID = page.id
        try? modelContext.save()
    }
    
    // MARK: - Thumbnail handling
    func updateThumbnail(for page: Page) {
        let drawing = drawingForDisplay(for: page)
        
        // Reduce scale for efficiency
        let scale = UIScreen.main.scale * 0.1
        
        let thumbnail = drawing.image(from: pageRect, scale: scale)
        let aspectRatio = pageRect.size.width / pageRect.size.height
        let thumbnailSize = CGSize(width: 120, height: 120 / aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnailImage = renderer.image { context in
            // Set background color based on color scheme
            let backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? UIColor.systemGray6 : .white
            }
            context.cgContext.setFillColor(backgroundColor.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: thumbnailSize))
            
            // Draw the thumbnail
            thumbnail.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
        page.thumbnailData = thumbnailImage.pngData()
    }
    
    func updateAllThumbnails() {
        for page in pages {
            updateThumbnail(for: page)
        }
    }
}

private extension PKDrawing {
    func scaled(from sourceSize: CGSize, to targetSize: CGSize) -> PKDrawing {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              targetSize.width > 0,
              targetSize.height > 0,
              sourceSize != targetSize else {
            return self
        }

        let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let offset = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offset.x, ty: offset.y)

        return transformed(using: transform)
    }
}

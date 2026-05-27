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
    @Published private(set) var pageRect: CGRect
    
    private var modelContext: ModelContext
    
    // MARK: - Initialisation
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let screenSize = UIScreen.main.bounds.size
        self.pageRect = CGRect(origin: .zero, size: screenSize)
        
        let descriptor = FetchDescriptor<Page>()
        self.pages = (try? modelContext.fetch(descriptor)) ?? []
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
        let newPage = Page(positionX: position.x, positionY: position.y, pageSize: pageRect.size)
        modelContext.insert(newPage)
        pages.append(newPage)
        updateThumbnail(for: newPage)
        return newPage
    }
    
    func setCurrentPage(_ page: Page, updatePrevious: Bool = true) {
        if updatePrevious {
            previousPageID = currentPageID
        }
        currentPageID = page.id
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

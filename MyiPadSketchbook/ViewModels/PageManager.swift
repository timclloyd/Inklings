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

@MainActor
class PageManager: ObservableObject {
    @Published var currentPageID: UUID?
    @Published var pages: [Page] = []
    let pageRect: CGRect
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let screenSize = UIScreen.main.bounds.size
        self.pageRect = CGRect(origin: .zero, size: screenSize)
        
        let descriptor = FetchDescriptor<Page>()
        self.pages = (try? modelContext.fetch(descriptor)) ?? []
        
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
    
    func createPage(position: (x: Int, y: Int)) -> Page {
        let newPage = Page(positionX: position.x, positionY: position.y)
        modelContext.insert(newPage)
        pages.append(newPage)
        return newPage
    }
    
    func setCurrentPage(_ page: Page) {
        currentPageID = page.id
        // Save current page position
        UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
        UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
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
            setCurrentPage(existingPage)
        } else {
            let newPage = createPage(position: (newPosition.x!, newPosition.y!))
            setCurrentPage(newPage)
        }
    }
    
    func getCurrentPage() -> Page? {
        guard let currentPageID = currentPageID else { return nil }
        return pages.first { $0.id == currentPageID }
    }
    
    func updateDrawing(_ drawing: PKDrawing) {
        guard let currentPage = getCurrentPage() else { return }
        currentPage.drawingData = drawing.dataRepresentation()
        updateThumbnail(for: currentPage)
    }
    
    func updateThumbnail(for page: Page) {
        guard let drawing = try? PKDrawing(data: page.drawingData!) else { return }
        
        // Reduce scale for efficiency
        let scale = UIScreen.main.scale * 0.1
        
        let thumbnail = drawing.image(from: pageRect, scale: scale)
        let aspectRatio = pageRect.size.width / pageRect.size.height
        let thumbnailSize = CGSize(width: 120, height: 120 / aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnailImage = renderer.image { context in
            // Set background color based on color scheme
            let backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .black : .white
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
    
    func updatePagePosition(_ page: Page) {
        objectWillChange.send()
        try? modelContext.save()
        // Update saved position if this is the current page
        if page.id == currentPageID {
            UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
            UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
        }
    }
}

extension PageManager {
    func movePage(_ page: Page, to newPosition: (x: Int, y: Int)) {
        page.positionX = newPosition.x
        page.positionY = newPosition.y
        try? modelContext.save()
    }
}

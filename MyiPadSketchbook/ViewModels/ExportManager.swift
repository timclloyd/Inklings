//
//  ExportManager.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-11-02.
//

import Foundation
import SwiftUI
import PencilKit
import UIKit

@MainActor
class ExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var progress: Double = 0
    
    private let pageManager: PageManager
    private let colorScheme: ColorScheme
    private let canvasGenerator = CanvasFileGenerator()
    
    init(pageManager: PageManager, colorScheme: ColorScheme) {
        self.pageManager = pageManager
        self.colorScheme = colorScheme
    }
    
    func exportPages() async throws -> URL {
        isExporting = true
        progress = 0
        
        // Create temp directory for exports
        let tempBaseURL = FileManager.default.temporaryDirectory
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "MyiPadSketchbook"
        let exportURL = tempBaseURL.appendingPathComponent(appName)
        
        // Remove any existing export directory
        try? FileManager.default.removeItem(at: exportURL)
        try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
        
        let totalPages = pageManager.pages.count
        
        // Export each page
        for (index, page) in pageManager.pages.enumerated() {
            // Create composite image
            let compositeImage = try await createCompositeImage(for: page)
            
            // Convert to JPEG data
            guard let jpegData = compositeImage.jpegData(compressionQuality: 0.9) else { continue }
            
            // Save to file
            let filename = "\(page.positionX ?? 0),\(page.positionY ?? 0).jpeg"
            let fileURL = exportURL.appendingPathComponent(filename)
            try jpegData.write(to: fileURL)
            
            // Update progress
            progress = Double(index + 1) / Double(totalPages)
        }
        
        // Generate and save canvas file
        let canvasContent = try canvasGenerator.generateCanvasFile(pages: pageManager.pages, appName: appName)
        let canvasURL = exportURL.appendingPathComponent("\(appName).canvas")
        try canvasContent.write(to: canvasURL, atomically: true, encoding: .utf8)
        
        isExporting = false
        progress = 1
        
        return exportURL
    }
    
    private func createCompositeImage(for page: Page) async throws -> UIImage {
        let rect = pageManager.pageRect
        let renderer = UIGraphicsImageRenderer(bounds: rect)
        
        // Create a simplified version of PageView content
        let exportView = ExportPageView(
            pageManager: pageManager,
            page: page,
            colorScheme: colorScheme
        )
        
        return renderer.image { context in
            let controller = UIHostingController(rootView: exportView)
            controller.view.frame = rect
            controller.view.backgroundColor = .clear
            controller.view.layoutIfNeeded()
            controller.view.drawHierarchy(in: rect, afterScreenUpdates: true)
        }
    }
}

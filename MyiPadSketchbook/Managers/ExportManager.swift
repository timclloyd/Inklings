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

// MARK: - ExportManager
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
        // Use number of CPU cores, capped between 2-8 for memory safety
        let maxConcurrentRenders = min(8, max(2, ProcessInfo.processInfo.activeProcessorCount))

        // Export pages with controlled concurrency
        var completedCount = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            var currentIndex = 0

            // Start initial batch
            for page in pageManager.pages.prefix(maxConcurrentRenders) {
                group.addTask {
                    try await self.exportSinglePage(page: page, to: exportURL)
                }
                currentIndex += 1
            }

            // As each completes, start the next one
            for try await _ in group {
                completedCount += 1
                progress = Double(completedCount) / Double(totalPages)

                // Add next page if there are more
                if currentIndex < pageManager.pages.count {
                    let page = pageManager.pages[currentIndex]
                    group.addTask {
                        try await self.exportSinglePage(page: page, to: exportURL)
                    }
                    currentIndex += 1
                }
            }
        }
        
        // Generate and save canvas file
        let canvasContent = try canvasGenerator.generateCanvasFile(pages: pageManager.pages, appName: appName)
        let canvasURL = exportURL.appendingPathComponent("\(appName).canvas")
        try canvasContent.write(to: canvasURL, atomically: true, encoding: .utf8)
        
        isExporting = false
        progress = 1
        
        return exportURL
    }

    private func exportSinglePage(page: Page, to exportURL: URL) async throws {
        // Create composite image
        let compositeImage = try await createCompositeImage(for: page)

        // Convert to JPEG data
        guard let jpegData = compositeImage.jpegData(compressionQuality: 0.9) else {
            return
        }

        // Save to file
        let filename = "\(page.positionX ?? 0),\(page.positionY ?? 0).jpeg"
        let fileURL = exportURL.appendingPathComponent(filename)
        try jpegData.write(to: fileURL)
    }

    private func createCompositeImage(for page: Page) async throws -> UIImage {
        let rect = pageManager.pageRect

        // Create and render the ExportPageView
        let exportView = ExportPageView(
            pageManager: pageManager,
            page: page,
            colorScheme: colorScheme
        )

        let controller = UIHostingController(rootView: exportView)
        controller.view.frame = rect
        controller.view.backgroundColor = .white

        // Force multiple layout passes to ensure SwiftUI view is fully resolved
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // Wait for Core Animation to finish rendering using CATransaction
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                continuation.resume()
            }
            // Trigger another layout inside the transaction
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            CATransaction.commit()
        }

        // Small additional delay for SwiftUI's rendering pipeline
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(bounds: rect, format: format)

        return renderer.image { context in
            // First fill with white background
            UIColor.white.setFill()
            context.fill(rect)

            // Ensure view is ready before drawing
            guard controller.view.bounds.size != .zero else {
                return
            }

            // Use drawHierarchy with afterScreenUpdates now that we've given it time
            controller.view.drawHierarchy(in: rect, afterScreenUpdates: true)
        }
    }
}

// MARK: - ExportPageView
struct ExportPageView: View {
    let pageManager: PageManager
    let page: Page
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with dots
            DotGridView(
                pageRect: pageManager.pageRect,
                adjacentPages: AdjacentPages(left: false, right: false, top: false, bottom: false),
                swipeProgress: SwipeProgress(direction: nil, progress: 0),
                dragState: .inactive
            )
            .environment(\.colorScheme, colorScheme)
            
            // Drawing content
            Image(uiImage: pageManager.drawingForDisplay(for: page).image(from: pageManager.pageRect, scale: UIScreen.main.scale))
                .resizable()
                .scaledToFit()
            
            // Coordinate label
            Text("\(page.positionX ?? 0), \(page.positionY ?? 0)")
                .font(.system(size: 14))
                .padding(2)
                .padding(.horizontal, 4)
                .foregroundColor(Color.primary.opacity(0.87))
                .background(Color(.systemGray5))
                .cornerRadius(7)
                .padding(.bottom, 18)
        }
        .frame(width: pageManager.pageRect.width, height: pageManager.pageRect.height)
        .environment(\.colorScheme, colorScheme)
    }
}

// MARK: - CanvasFileGenerator
struct CanvasNode: Codable {
    let id: String
    let type: String
    let file: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    
    init(id: String, file: String, x: Int, y: Int) {
        self.id = id
        self.type = "file"
        self.file = file
        self.x = x
        self.y = y
        self.width = 279
        self.height = 399
    }
}

struct CanvasFile: Codable {
    let nodes: [CanvasNode]
    let edges: [String]
    
    init(nodes: [CanvasNode]) {
        self.nodes = nodes
        self.edges = []
    }
}

class CanvasFileGenerator {
    private let nodeSpacing = 279
    private let verticalSpacing = 400
    private let baseX = -180
    private let baseY = -200
    
    func generateCanvasFile(pages: [Page], appName: String) throws -> String {
        let nodes = pages.map { page -> CanvasNode in
            let pageX = page.positionX ?? 0
            let pageY = page.positionY ?? 0
            
            return CanvasNode(
                id: generateRandomId(),
                file: "\(appName)/\(pageX),\(pageY).jpeg",
                x: baseX + (pageX * nodeSpacing),
                y: baseY - (pageY * verticalSpacing)
            )
        }
        
        let canvasFile = CanvasFile(nodes: nodes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        let jsonData = try encoder.encode(canvasFile)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func generateRandomId() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<16).map { _ in characters.randomElement()! })
    }
}

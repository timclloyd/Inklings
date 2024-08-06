//
//  ContentView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-06.
//

import SwiftUI
import PencilKit

struct Page: Identifiable, Equatable {
    let id = UUID()
    var drawing = PKDrawing()
    var position: (x: Int, y: Int)
    var thumbnail: UIImage?
    
    static func == (lhs: Page, rhs: Page) -> Bool {
        lhs.id == rhs.id
    }
}

class PageManager: ObservableObject {
    @Published private(set) var pages: [Page]
    @Published var currentPageID: UUID
    
    let pageRect: CGRect
    
    init() {
        let screenSize = UIScreen.main.bounds.size
        self.pageRect = CGRect(origin: .zero, size: screenSize)
        
        let initialPage = Page(position: (0, 0))
        self.pages = [initialPage]
        self.currentPageID = initialPage.id
    }
    
    var currentPage: Page {
        pages.first { $0.id == currentPageID }!
    }
    
    func addPage(direction: DragGesture.Value) {
        var newPosition = currentPage.position
        
        if abs(direction.translation.width) > abs(direction.translation.height) {
            newPosition.x += direction.translation.width > 0 ? 1 : -1
        } else {
            newPosition.y += direction.translation.height > 0 ? -1 : 1
        }
        
        if let existingPage = pages.first(where: { $0.position == newPosition }) {
            DispatchQueue.main.async {
                self.currentPageID = existingPage.id
            }
            print("Moved to existing page at position: \(newPosition)")
        } else {
            let newPage = Page(position: newPosition)
            DispatchQueue.main.async {
                self.pages.append(newPage)
                self.currentPageID = newPage.id
            }
            print("Created new page at position: \(newPosition)")
        }
    }
    
    func updateDrawing(_ drawing: PKDrawing) {
        guard let index = pages.firstIndex(where: { $0.id == currentPageID }) else { return }
        DispatchQueue.main.async {
            self.pages[index].drawing = drawing
            self.updateThumbnail(for: index)
        }
    }
    
    func updateThumbnail(for index: Int) {
        let thumbnail = pages[index].drawing.image(from: pageRect, scale: 1)
        let aspectRatio = pageRect.size.width / pageRect.size.height
        let thumbnailSize = CGSize(width: 120, height: 120 / aspectRatio)
        
        pages[index].thumbnail = UIGraphicsImageRenderer(size: thumbnailSize).image { context in
            thumbnail.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
    
    func updateAllThumbnails() {
        for index in pages.indices {
            updateThumbnail(for: index)
        }
    }
}

struct MiniMapView: View {
    @ObservedObject var pageManager: PageManager
    @Environment(\.colorScheme) var colorScheme
    var onPageSelected: (UUID) -> Void
    let thumbnailSize: CGSize
    
    private var pagePositions: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let xPositions = pageManager.pages.map { $0.position.x }
        let yPositions = pageManager.pages.map { $0.position.y }
        return (
            minX: xPositions.min() ?? 0,
            maxX: xPositions.max() ?? 0,
            minY: yPositions.min() ?? 0,
            maxY: yPositions.max() ?? 0
        )
    }
    
    private func thumbnailPosition(for page: Page) -> CGPoint {
        let positions = pagePositions
        return CGPoint(
            x: CGFloat(positions.maxX - page.position.x) * (thumbnailSize.width + 10) + thumbnailSize.width / 2,
            y: CGFloat(page.position.y - positions.minY) * (thumbnailSize.height + 10) + thumbnailSize.height / 2
        )
    }
    
    private var frameSize: CGSize {
        let positions = pagePositions
        return CGSize(
            width: CGFloat((positions.maxX - positions.minX + 1) * Int(thumbnailSize.width + 10)),
            height: CGFloat((positions.maxY - positions.minY + 1) * Int(thumbnailSize.height + 10))
        )
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            
            ForEach(pageManager.pages) { page in
                thumbnailView(for: page)
                    .position(thumbnailPosition(for: page))
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }
    
    private func thumbnailView(for page: Page) -> some View {
        Group {
            if let thumbnail = page.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray)
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(page.id == pageManager.currentPageID ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onPageSelected(page.id)
        }
    }
}

struct ContentView: View {
    @StateObject private var pageManager = PageManager()
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showMiniMap = false
    @GestureState private var magnifyBy = CGFloat(1.0)
    
    var body: some View {
        ZStack {
            if !showMiniMap {
                PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.currentPage.drawing, onDrawingChange: pageManager.updateDrawing, pageRect: pageManager.pageRect)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .updating($magnifyBy) { currentState, gestureState, transaction in
                                gestureState = currentState
                            }
                            .onEnded { value in
                                if value < 0.8 {
                                    pageManager.updateAllThumbnails()
                                    showMiniMap = true
                                }
                            }
                    )
            
                VStack {
                    Spacer()
                    Text("Page Position: \(pageManager.currentPage.position.x), \(pageManager.currentPage.position.y)")
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.7))
                        .cornerRadius(10)
                }
            } else {
                MiniMapView(pageManager: pageManager, onPageSelected: { selectedPageID in
                    pageManager.currentPageID = selectedPageID
                    canvasView.drawing = pageManager.currentPage.drawing
                    showMiniMap = false
                }, thumbnailSize: CGSize(width: 120, height: 120 / (pageManager.pageRect.width / pageManager.pageRect.height)))
                .gesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { currentState, gestureState, transaction in
                            gestureState = currentState
                        }
                        .onEnded { value in
                            if value > 1.2 {
                                showMiniMap = false
                            }
                        }
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if max(abs(value.translation.width), abs(value.translation.height)) > UIScreen.main.bounds.width / 4 {
                        pageManager.addPage(direction: value)
                        canvasView.drawing = pageManager.currentPage.drawing
                    }
                }
        )
    }
}

struct PencilKitView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var drawing: PKDrawing
    var onDrawingChange: (PKDrawing) -> Void
    var pageRect: CGRect
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.delegate = context.coordinator
        
        canvasView.drawing = drawing
        canvasView.contentSize = pageRect.size
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1  // Disable zooming
        canvasView.zoomScale = 1
        
        // Disable the built-in gestures
        canvasView.isScrollEnabled = false
        for gesture in canvasView.gestureRecognizers ?? [] {
            gesture.isEnabled = false
        }
        
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitView
        
        init(_ parent: PencilKitView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChange(canvasView.drawing)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad Pro (11-inch) (3rd generation)")
    }
}

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
    
    static func == (lhs: Page, rhs: Page) -> Bool {
        lhs.id == rhs.id
    }
}

class PageManager: ObservableObject {
    @Published private(set) var pages: [Page]
    @Published var currentPageID: UUID
    
    init() {
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
            newPosition.y += direction.translation.height > 0 ? -1 : 1  // This is correct
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
        }
    }
}

struct MiniMapView: View {
    @ObservedObject var pageManager: PageManager
    var onPageSelected: (UUID) -> Void
    
    var body: some View {
        let minX = pageManager.pages.map { $0.position.x }.min() ?? 0
        let maxX = pageManager.pages.map { $0.position.x }.max() ?? 0
        let minY = pageManager.pages.map { $0.position.y }.min() ?? 0
        let maxY = pageManager.pages.map { $0.position.y }.max() ?? 0
        
        return ZStack {
            Color.black.opacity(0.8)
            
            ForEach(pageManager.pages) { page in
                RoundedRectangle(cornerRadius: 5)
                    .fill(page.id == pageManager.currentPageID ? Color.blue : Color.gray)
                    .frame(width: 50, height: 50)
                    .position(
                        x: CGFloat(maxX - page.position.x) * 60 + 30,  // Invert X-axis
                        y: CGFloat(page.position.y - minY) * 60 + 30  // Correct Y-axis
                    )
                    .onTapGesture {
                        onPageSelected(page.id)
                    }
            }
        }
        .frame(width: CGFloat((maxX - minX + 1) * 60), height: CGFloat((maxY - minY + 1) * 60))
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
            PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.currentPage.drawing, onDrawingChange: pageManager.updateDrawing)
                .ignoresSafeArea()
                .opacity(showMiniMap ? 0.3 : 1)
            
            if showMiniMap {
                MiniMapView(pageManager: pageManager) { selectedPageID in
                    pageManager.currentPageID = selectedPageID
                    canvasView.drawing = pageManager.currentPage.drawing
                    showMiniMap = false
                }
            }
            
            VStack {
                Spacer()
                Text("Page Position: \(pageManager.currentPage.position.x), \(pageManager.currentPage.position.y)")
                    .padding()
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(10)
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
        .gesture(
            MagnificationGesture()
                .updating($magnifyBy) { currentState, gestureState, transaction in
                    gestureState = currentState
                }
                .onEnded { value in
                    if value < 0.8 {
                        showMiniMap = true
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
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 1)
        canvasView.drawingPolicy = .pencilOnly
        canvasView.delegate = context.coordinator
        
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

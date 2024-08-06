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
            newPosition.y += direction.translation.height > 0 ? 1 : -1
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

struct ContentView: View {
    @StateObject private var pageManager = PageManager()
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
    var body: some View {
        ZStack {
            PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.currentPage.drawing, onDrawingChange: pageManager.updateDrawing)
                .ignoresSafeArea()
            
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

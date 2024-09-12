//
//  ContentView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import SwiftData
import PencilKit

// MARK: - PageView
struct PageView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var pages: [Page]
    
    // MARK: - State Objects
    @StateObject private var pageManager: PageManager
    
    // MARK: - State
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showMapView = false
    @State private var swipeProgress = SwipeProgress(direction: nil, progress: 0)
    @GestureState private var dragState = DragState.inactive
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var canGoToPreviousPage = false
    
    // MARK: - Initialisation
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if !showMapView {
                mainView
            } else {
                mapView
            }
        }
        .onAppear {
            updateUndoRedoState()
            updateCanGoToPreviousPage()
        }
    }
    
    // MARK: - Subviews
    private var mainView: some View {
        ZStack {
            backgroundView
            drawingView
            navIndicatorView
            toolbarView
        }
    }
    
    private var backgroundView: some View {
        DotGridView(pageRect: pageManager.pageRect,
                             adjacentPages: getAdjacentPages(),
                             swipeProgress: swipeProgress,
                             dragState: dragState)
            .ignoresSafeArea()
    }
    
    private var drawingView: some View {
        PencilKitView(canvasView: $canvasView,
                      toolPicker: $toolPicker,
                      drawing: pageManager.getCurrentPage()?.drawingData ?? Data(),
                      onDrawingChange: handleDrawingChange,
                      pageRect: pageManager.pageRect,
                      onSwipe: handleSwipe)
            .ignoresSafeArea()
    }
    
    private var navIndicatorView: some View {
        PageChangeIndicatorView(direction: swipeProgress.direction,
                         progress: swipeProgress.progress,
                         size: pageManager.pageRect.size,
                         adjacentPages: getAdjacentPages())
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
    
    private var toolbarView: some View {
        VStack {
            HStack {
                Spacer()
                pageFlipButton
                showMapButton
            }
            
            HStack {
                Spacer()
                VStack {
                    undoButton
                    redoButton
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Buttons
    private var pageFlipButton: some View {
        Button(action: handlePageFlip) {
            Image(systemName: "rectangle.2.swap")
                .rotationEffect(Angle(degrees: -90.0))
                .font(.system(size: toolbarButtonSize))
                .symbolRenderingMode(.hierarchical)
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .background(Color.clear.contentShape(Circle()))
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: canGoToPreviousPage))
        .disabled(!canGoToPreviousPage)
        .padding(EdgeInsets(top: 18, leading: 0, bottom: 0, trailing: 5))
    }
    
    private var showMapButton: some View {
        Button(action: showMap) {
            Image(systemName: "square.on.square")
                .font(.system(size: toolbarButtonSize * 1.5, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .background(Color.clear.contentShape(Circle()))
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 8))
    }
    
    private var undoButton: some View {
        Button(action: handleUndo) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: toolbarButtonSize))
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .background(Color.clear.contentShape(Circle()))
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: canUndo))
        .disabled(!canUndo)
        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 20.5))
    }
    
    private var redoButton: some View {
        Button(action: handleRedo) {
            Image(systemName: "arrow.uturn.right.circle")
                .font(.system(size: toolbarButtonSize))
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .background(Color.clear.contentShape(Circle()))
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: canRedo))
        .disabled(!canRedo)
        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 20.5))
    }
    
    private var mapView: some View {
        MapView(pageManager: pageManager,
                pages: pages,
                onPageSelected: handlePageSelection,
                showMiniMap: $showMapView,
                onCloseMap: { showMapView = false })
    }
    
    // MARK: - Helper Methods
    private func updateUndoRedoState() {
        DispatchQueue.main.async {
            self.canUndo = self.canvasView.undoManager?.canUndo ?? false
            self.canRedo = self.canvasView.undoManager?.canRedo ?? false
        }
    }
    
    private func updateCanGoToPreviousPage() {
        DispatchQueue.main.async {
            self.canGoToPreviousPage = self.pageManager.previousPageID != nil
        }
    }
    
    private func handleDrawingChange(_ drawing: PKDrawing) {
        pageManager.updateDrawing(drawing)
        updateUndoRedoState()
    }
    
    private func handlePageFlip() {
        if let previousPage = pageManager.goToPreviousPage() {
            if let drawing = try? PKDrawing(data: previousPage.drawingData!) {
                canvasView.drawing = drawing
                updateUndoRedoState()
            }
            updateCanGoToPreviousPage()
        }
    }
    
    private func showMap() {
        pageManager.updateAllThumbnails()
        showMapView = true
    }
    
    private func handleUndo() {
        canvasView.undoManager?.undo()
        updateUndoRedoState()
    }
    
    private func handleRedo() {
        canvasView.undoManager?.redo()
        updateUndoRedoState()
    }
    
    private func handlePageSelection(_ selectedPage: Page) {
        pageManager.setCurrentPage(selectedPage)
        if let drawing = try? PKDrawing(data: selectedPage.drawingData!) {
            canvasView.drawing = drawing
            updateUndoRedoState()
        }
        updateCanGoToPreviousPage()
        showMapView = false
    }
    
    private func handleSwipe(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let progress = min(1.0, max(abs(translation.x), abs(translation.y)) / (UIScreen.main.bounds.width / 4))
        
        let direction: EdgeDirection
        if abs(translation.x) > abs(translation.y) {
            direction = translation.x > 0 ? .left : .right
        } else {
            direction = translation.y > 0 ? .top : .bottom
        }
        
        switch gesture.state {
        case .changed:
            swipeProgress = SwipeProgress(direction: direction, progress: progress)
        case .ended:
            if progress >= 1.0 {
                pageManager.addPage(translation: CGSize(width: translation.x, height: translation.y))
                if let currentPage = pageManager.getCurrentPage(),
                   let drawing = try? PKDrawing(data: currentPage.drawingData!) {
                    canvasView.drawing = drawing
                }
                updateCanGoToPreviousPage()
            }
            // Reset swipeProgress when the gesture ends
            withAnimation(.linear(duration: 0)) {
                swipeProgress = SwipeProgress(direction: nil, progress: 0)
            }
        default:
            break
        }
    }
    
    private func getAdjacentPages() -> AdjacentPages {
        guard let currentPage = pageManager.getCurrentPage() else {
            return AdjacentPages(left: false, right: false, top: false, bottom: false)
        }
        
        return AdjacentPages(
            left: pageManager.pages.contains(where: { $0.positionX == (currentPage.positionX ?? 0) - 1 && $0.positionY == currentPage.positionY }),
            right: pageManager.pages.contains(where: { $0.positionX == (currentPage.positionX ?? 0) + 1 && $0.positionY == currentPage.positionY }),
            top: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == (currentPage.positionY ?? 0) + 1 }),
            bottom: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == (currentPage.positionY ?? 0) - 1 })
        )
    }
}

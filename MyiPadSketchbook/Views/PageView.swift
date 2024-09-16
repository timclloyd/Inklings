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
    @State private var pageChangedFromMap = false
    
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
                VStack() {
                    showMapButton
                    
                    VStack() {
                        pageFlipButton
                        undoButton
                        redoButton
                    }
                }
                .background(Color(UIColor.systemBackground).cornerRadius(10))
                .fixedSize()
            }
            Spacer()
        }
    }
    
    // MARK: - Buttons
    private var showMapButton: some View {
        Button(action: showMap) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: toolbarButtonSize * 1.5, weight: .light))
                .padding(13) // Expand tappable area
                .background(
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                )
        }
        .contentShape(Circle()) // Ensure the tappable area is circular
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 21, leading: 0, bottom: 0, trailing: 10)) // Layout padding
    }
    
    private var pageFlipButton: some View {
        Button(action: handlePageFlip) {
            Image(systemName: "rectangle.2.swap")
                .rotationEffect(Angle(degrees: -90.0))
                .font(.system(size: toolbarButtonSize))
                .padding(9)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canGoToPreviousPage))
        .disabled(!canGoToPreviousPage)
        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 10))
    }
    
    private var undoButton: some View {
        Button(action: handleUndo) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: toolbarButtonSize))
                .padding(9)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canUndo))
        .disabled(!canUndo)
        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 9))
    }
    
    private var redoButton: some View {
        Button(action: handleRedo) {
            Image(systemName: "arrow.uturn.right.circle")
                .font(.system(size: toolbarButtonSize))
                .padding(9)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canRedo))
        .disabled(!canRedo)
        .padding(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 8))
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
        pageManager.setCurrentPage(selectedPage, updatePrevious: true)
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
                // Do not update canGoToPreviousPage here
            }
            // Reset swipeProgress when the gesture ends
            withAnimation(.linear(duration: 0)) {
                swipeProgress = SwipeProgress(direction: nil, progress: 0)
            }
        default:
            break
        }
    }
    
    private func checkAndUpdatePreviousPage() {
        if pageChangedFromMap {
            updateCanGoToPreviousPage()
            pageChangedFromMap = false
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

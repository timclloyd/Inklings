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
    @State private var selectedTool: String = "pen"
    
    // MARK: - Initialisation
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if !showMapView {
                ZStack(alignment: .bottom) {
                    mainView
                    coordinateLabel
                }
            } else {
                mapView
            }
        }
        .onAppear {
            updateUndoRedoState()
            updateCanGoToPreviousPage()
            setupToolPicker()
            selectPen(color: .black)
        }
        .onChange(of: colorScheme) {
            pageManager.updateAllThumbnails()
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
                    toolSelectionButtons
                }
                .background(Color(UIColor.systemBackground).cornerRadius(10))
                .fixedSize()
            }
            Spacer()
        }
    }
    
    private var toolSelectionButtons: some View {
        VStack() {
            toolButton(toolName: "pen_black", action: { selectPen(color: .black) }, systemName: "pencil.line", color: .black)
                .padding(EdgeInsets(top: -3, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "pen_red", action: { selectPen(color: .red) }, systemName: "pencil.line", color: .red)
                .padding(EdgeInsets(top: -3, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "pencil", action: selectPencil, systemName: "pencil")
                .padding(EdgeInsets(top: -2, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "marker_blue", action: { selectMarker(color: .blue) }, systemName: "highlighter", color: .blue)
                .padding(EdgeInsets(top: -4.5, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "marker_green", action: { selectMarker(color: .green) }, systemName: "highlighter", color: .green)
                .padding(EdgeInsets(top: -5.5, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "eraser", action: selectEraser, systemName: "eraser")
                .padding(EdgeInsets(top: -4, leading: 0, bottom: 0, trailing: 10))
            
            toolButton(toolName: "lasso", action: selectLasso, systemName: "lasso")
                .padding(EdgeInsets(top: -4.5, leading: 0, bottom: 0, trailing: 10))
        }
    }
    
    private func toolButton(toolName: String, action: @escaping () -> Void, systemName: String, color: Color? = nil) -> some View {
        Button(action: {
            action()
            selectedTool = toolName
        }) {
            Image(systemName: systemName)
                .font(.system(size: toolbarButtonSize * 0.9))
                .padding(9)
                .background(Circle().fill(Color(UIColor.systemBackground)))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: selectedTool == toolName, color: color))
    }
    
    private var coordinateLabel: some View {
        Text("\(pageManager.getCurrentPage()?.positionX ?? 0), \(pageManager.getCurrentPage()?.positionY ?? 0)")
            .font(.system(size: 14))
            .padding(2)
            .padding(.horizontal, 4)
            .foregroundColor(Color.primary.opacity(0.87))
            .background(Color(.systemGray5))
            .cornerRadius(7)
            .padding(.bottom, 18)
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
        .padding(EdgeInsets(top: -7, leading: 0, bottom: 0, trailing: 9))
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
        canvasView.undoManager?.removeAllActions()
        
        if let previousPage = pageManager.goToPreviousPage() {
            if let drawing = try? PKDrawing(data: previousPage.drawingData!) {
                canvasView.drawing = drawing
                updateUndoRedoState()
            }
            updateCanGoToPreviousPage()
        }
    }
    
    private func showMap() {
        canvasView.undoManager?.removeAllActions()
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
        canvasView.undoManager?.removeAllActions()
        
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
                    canvasView.undoManager?.removeAllActions()
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
    
    //MARK: - Pencil tool stuff
    private func selectPen(color: Color) {
        let toolName: String
        let uiColor: UIColor
        switch color {
        case .black:
            toolName = "pen_black"
            uiColor = UIColor.black.withAlphaComponent(0.9)
        case .red:
            toolName = "pen_red"
            uiColor = UIColor.systemRed.withAlphaComponent(0.9)
        default:
            toolName = "pen_black"
            uiColor = UIColor.black.withAlphaComponent(0.9)
        }
        selectedTool = toolName
        let inkTool = PKInkingTool(.pen, color: uiColor, width: 3)
        toolPicker.selectedTool = inkTool
    }

    private func selectPencil() {
        selectedTool = "pencil"
        let inkTool = PKInkingTool(.pencil, color: UIColor.black.withAlphaComponent(0.5), width: 3)
        toolPicker.selectedTool = inkTool
    }

    private func selectMarker(color: Color) {
        let toolName: String
        let uiColor: UIColor
        switch color {
        case .blue:
            toolName = "marker_blue"
            uiColor = UIColor.systemBlue.withAlphaComponent(0.45)
        case .orange:
            toolName = "marker_orange"
            uiColor = UIColor.systemOrange.withAlphaComponent(0.45)
        case .green:
            toolName = "marker_green"
            uiColor = UIColor.systemGreen.withAlphaComponent(0.45)
        default:
            toolName = "marker"
            uiColor = UIColor.systemBlue.withAlphaComponent(0.45)
        }
        selectedTool = toolName
        let inkTool = PKInkingTool(.marker, color: uiColor, width: 20)
        toolPicker.selectedTool = inkTool
    }

    private func selectEraser() {
        selectedTool = "eraser"
        toolPicker.selectedTool = PKEraserTool(.vector)
    }

    private func selectLasso() {
        selectedTool = "lasso"
        toolPicker.selectedTool = PKLassoTool()
    }

    private func setupToolPicker() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        selectPen(color: .black)
    }
}

enum MarkerColor: String, Equatable {
    case blue
    case orange
    case green
}

enum DrawingTool: Equatable {
    case pen
    case pencil
    case marker(MarkerColor)
    case eraser
    case lasso
}

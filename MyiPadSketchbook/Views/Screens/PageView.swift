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
    @State private var currentTool: String = "pen_black"
    @State private var previousTool: String?
    
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
            setupToolPicker()
            selectPen(color: .black)
        }
        .onChange(of: colorScheme) {
            pageManager.updateAllThumbnails()
        }
        .onPencilSqueeze { phase in
            if case .ended = phase {
                handleSqueeze()
            }
        }
    }
    
    // MARK: - Subviews
    private var mainView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                toolbarView
                    .padding(.top, geometry.safeAreaInsets.top)

                ZStack {
                    backgroundView
                    drawingView
                    navIndicatorView
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var backgroundView: some View {
        DotGridView(pageRect: pageManager.pageRect,
                             adjacentPages: getAdjacentPages(),
                             swipeProgress: swipeProgress,
                             dragState: dragState)
    }

    private var drawingView: some View {
        PencilKitView(canvasView: $canvasView,
                      toolPicker: $toolPicker,
                      drawing: pageManager.getCurrentPage()?.drawingData ?? Data(),
                      onDrawingChange: handleDrawingChange,
                      pageRect: pageManager.pageRect,
                      onSwipe: handleSwipe,
                      onPinch: handlePinch)
    }
    
    private var navIndicatorView: some View {
        PageChangeIndicatorView(
            direction: swipeProgress.direction,
            progress: swipeProgress.progress,
            size: pageManager.pageRect.size,
            adjacentPages: getAdjacentPages(),
            swipeProgress: swipeProgress
        )
        .allowsHitTesting(false)
    }
    
    private var toolbarView: some View {
        HStack() {
            HStack(spacing: 18) {
                pageFlipButton
                undoButton
                redoButton
            }
            .padding(.leading, 10)

            Spacer()

            coordinateLabel
                .padding(.trailing, 10)
        }
        .overlay(
            HStack(spacing: 4) {
                toolButton(toolName: "pen_black", action: { selectPen(color: .black) }, systemName: "circle.fill")

                toolButton(toolName: "pen_red", action: { selectPen(color: .red) }, systemName: "circle.fill", color: .red.opacity(0.9))

                toolButton(toolName: "pencil", action: selectPencil, systemName: "circle.lefthalf.striped.horizontal.inverse")

                toolButton(toolName: "marker_blue", action: { selectMarker(color: .blue) }, systemName: "square.fill", color: .blue.opacity(0.5))

                toolButton(toolName: "marker_green", action: { selectMarker(color: .green) }, systemName: "square.fill", color: .green.opacity(0.5))

                toolButton(toolName: "marker_yellow", action: { selectMarker(color: .yellow) }, systemName: "square.fill", color: .yellow.opacity(0.5))

                toolButton(toolName: "eraser", action: selectEraser, systemName: "circle.slash.fill")

                toolButton(toolName: "lasso", action: selectLasso, systemName: "circle.dashed")
            }
        )
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
    }
    
    private func toolButton(toolName: String, action: @escaping () -> Void, systemName: String, color: Color? = nil) -> some View {
        Button(action: {
            action()
            currentTool = toolName
        }) {
            Image(systemName: systemName)
                .font(.system(size: toolbarButtonSize * 0.8))
                .padding(9)
        }
        .buttonStyle(ToolbarButtonStyle(
            isEnabled: currentTool == toolName,
            color: color,
            highlightBackground: true
        ))
    }
    
    private var coordinateLabel: some View {
        Text("\(pageManager.getCurrentPage()?.positionX ?? 0), \(pageManager.getCurrentPage()?.positionY ?? 0)")
            .font(.system(size: 14))
            .padding(2)
            .padding(.horizontal, 4)
            .foregroundColor(Color.primary.opacity(0.4))
            .cornerRadius(7)
    }
    
    // MARK: - Buttons
    private var pageFlipButton: some View {
        Button(action: handlePageFlip) {
            Image(systemName: "rectangle.2.swap")
                .rotationEffect(Angle(degrees: -90.0))
                .font(.system(size: toolbarButtonSize))
                .padding(1)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canGoToPreviousPage))
        .disabled(!canGoToPreviousPage)
    }
    
    private var undoButton: some View {
        Button(action: handleUndo) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: toolbarButtonSize))
                .padding(1)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canUndo))
        .disabled(!canUndo)
    }
    
    private var redoButton: some View {
        Button(action: handleRedo) {
            Image(systemName: "arrow.uturn.right.circle")
                .font(.system(size: toolbarButtonSize))
                .padding(1)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: canRedo))
        .disabled(!canRedo)
    }
    
    private var mapView: some View {
        MapView(pageManager: pageManager,
                pages: pages,
                onPageSelected: handlePageSelection,
                showMap: $showMapView,
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
            self.canGoToPreviousPage = self.pageManager.previousPageID != nil && self.pageManager.previousPageID != self.pageManager.currentPageID
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
            swipeProgress = SwipeProgress(direction: direction, progress: progress, isMapGesture: false)
        case .ended:
            if progress >= 1.0 {
                pageManager.addPage(translation: CGSize(width: translation.x, height: translation.y))
                if let currentPage = pageManager.getCurrentPage(),
                   let drawing = try? PKDrawing(data: currentPage.drawingData!) {
                    canvasView.drawing = drawing
                    canvasView.undoManager?.removeAllActions()
                }
            }
            withAnimation(.linear(duration: 0)) {
                swipeProgress = SwipeProgress(direction: nil, progress: 0, isMapGesture: false)
            }
        default:
            break
        }
    }
    
    private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = gesture.scale
        let distance = 0.5

        switch gesture.state {
        case .changed:
            if scale <= distance {
                swipeProgress = SwipeProgress(direction: .top, progress: 1.0, isMapGesture: true)
            } else {
                swipeProgress = SwipeProgress(direction: nil, progress: 0, isMapGesture: false)
            }
        case .ended:
            if scale <= 0.6 {
                canvasView.undoManager?.removeAllActions()
                showMapView = true
            }
            swipeProgress = SwipeProgress(direction: nil, progress: 0, isMapGesture: false)
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
    
    // MARK: - Tool Selection
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
        currentTool = toolName
        let inkTool = PKInkingTool(.pen, color: uiColor, width: 3)
        toolPicker.selectedTool = inkTool
    }

    private func selectPencil() {
        currentTool = "pencil"
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
        case .green:
            toolName = "marker_green"
            uiColor = UIColor.systemGreen.withAlphaComponent(0.45)
        case .yellow:
            toolName = "marker_yellow"
            uiColor = UIColor.systemYellow.withAlphaComponent(0.45)
        default:
            toolName = "marker"
            uiColor = UIColor.systemBlue.withAlphaComponent(0.45)
        }
        currentTool = toolName
        let inkTool = PKInkingTool(.marker, color: uiColor, width: 20)
        toolPicker.selectedTool = inkTool
    }

    private func selectEraser() {
        currentTool = "eraser"
        toolPicker.selectedTool = PKEraserTool(.vector)
    }

    private func selectLasso() {
        currentTool = "lasso"
        toolPicker.selectedTool = PKLassoTool()
    }

    private func setupToolPicker() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        selectPen(color: .black)
    }

    private func handleSqueeze() {
        if currentTool == "eraser" {
            if let previous = previousTool {
                (currentTool, previousTool) = (previous, currentTool)
                selectToolByName(previous)
            }
        } else {
            (currentTool, previousTool) = ("eraser", currentTool)
            selectEraser()
        }
    }

    private func selectToolByName(_ toolName: String) {
        switch toolName {
        case "pen_black":
            selectPen(color: .black)
        case "pen_red":
            selectPen(color: .red)
        case "pencil":
            selectPencil()
        case "marker_blue":
            selectMarker(color: .blue)
        case "marker_green":
            selectMarker(color: .green)
        case "marker_yellow":
            selectMarker(color: .yellow)
        case "lasso":
            selectLasso()
        default:
            selectPen(color: .black)
        }
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

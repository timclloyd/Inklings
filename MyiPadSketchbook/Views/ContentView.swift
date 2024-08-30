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

struct CustomButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill((colorScheme == .dark ? Color.black : Color.white)))
            .foregroundColor(isEnabled ? .primary.opacity(0.87) : .primary.opacity(0.2))
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var pages: [Page]
    @StateObject private var pageManager: PageManager
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showMiniMap = false
    @State private var swipeProgress = SwipeProgress(direction: nil, progress: 0)
    @GestureState private var dragState = DragState.inactive
    @State private var canUndo = false
    @State private var canRedo = false
    
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    private let buttonSize: CGFloat = 70
    private let shadowRadius: CGFloat = 15
    private let undoRedoButtonSize: CGFloat = 20
    
    var body: some View {
        ZStack {
            if !showMiniMap {
                DottedBackgroundView(pageRect: pageManager.pageRect, adjacentPages: getAdjacentPages(), swipeProgress: swipeProgress, dragState: dragState)
                    .ignoresSafeArea()

                PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.getCurrentPage()?.drawingData ?? Data(), onDrawingChange: { drawing in
                    pageManager.updateDrawing(drawing)
                    updateUndoRedoState()
                }, pageRect: pageManager.pageRect, onSwipe: handleSwipe)
                    .ignoresSafeArea()

                EdgeOverlayView(direction: swipeProgress.direction, progress: swipeProgress.progress, size: pageManager.pageRect.size, adjacentPages: getAdjacentPages())
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // Undo and Redo buttons
                VStack {
                    HStack {
                        Spacer()
                        HStack() {
                            Button(action: {
                                canvasView.undoManager?.undo()
                                updateUndoRedoState()
                            }) {
                                Image(systemName: "arrow.uturn.left.circle")
                                    .font(.system(size: undoRedoButtonSize))
                                    .frame(width: undoRedoButtonSize, height: undoRedoButtonSize)
                                    .background(Color.clear.contentShape(Circle())) // Make the entire area tappable
                                    .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11)) // Adjust padding to expand the hit area
                            }
                            .buttonStyle(CustomButtonStyle(isEnabled: canUndo))
                            .disabled(!canUndo)
                            .padding(EdgeInsets(top: 18.5, leading: 0, bottom: 0, trailing: -8))
                            
                            Button(action: {
                                canvasView.undoManager?.redo()
                                updateUndoRedoState()
                            }) {
                                Image(systemName: "arrow.uturn.right.circle")
                                    .font(.system(size: undoRedoButtonSize))
                                    .frame(width: undoRedoButtonSize, height: undoRedoButtonSize)
                                    .background(Color.clear.contentShape(Circle())) // Make the entire area tappable
                                    .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11)) // Adjust padding to expand the hit area
                            }
                            .buttonStyle(CustomButtonStyle(isEnabled: canRedo))
                            .disabled(!canRedo)
                            .padding(EdgeInsets(top: 18.5, leading: 0, bottom: 0, trailing: 20.5))
                        }
                    }
                    Spacer()

                    // Map button
                    HStack {
                        Button(action: {
                            pageManager.updateAllThumbnails()
                            showMiniMap = true
                        }) {
                            Image(systemName: "map")
                                .font(.system(size: 28))
                                .foregroundColor(.primary.opacity(0.87))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        .buttonStyle(CustomButtonStyle(isEnabled: true))
                        .shadow(color: colorScheme == .dark ? .clear : .primary.opacity(0.15),
                                radius: shadowRadius, x: 0, y: 0)
                        .padding(EdgeInsets(top: 0, leading: 30, bottom: 6, trailing: 0))

                        Spacer()
                    }
                    .padding(.bottom, shadowRadius)
                }
            } else {
                MapView(pageManager: pageManager, pages: pages, onPageSelected: { selectedPage in
                    pageManager.setCurrentPage(selectedPage)
                    if let drawing = try? PKDrawing(data: selectedPage.drawingData) {
                        canvasView.drawing = drawing
                        updateUndoRedoState()
                    }
                    showMiniMap = false
                }, showMiniMap: $showMiniMap)
            }
        }
        .onAppear {
            updateUndoRedoState()
        }
    }
    
    private func updateUndoRedoState() {
        DispatchQueue.main.async {
            self.canUndo = self.canvasView.undoManager?.canUndo ?? false
            self.canRedo = self.canvasView.undoManager?.canRedo ?? false
        }
    }
    
    private func updateSwipeProgress(for gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let progress = min(1.0, max(abs(translation.x), abs(translation.y)) / (UIScreen.main.bounds.width / 4))
        
        let direction: EdgeDirection
        if abs(translation.x) > abs(translation.y) {
            direction = translation.x > 0 ? .left : .right
        } else {
            direction = translation.y > 0 ? .top : .bottom
        }
        
        swipeProgress = SwipeProgress(direction: direction, progress: progress)
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
                   let drawing = try? PKDrawing(data: currentPage.drawingData) {
                    canvasView.drawing = drawing
                }
            }
            // Always reset the swipe progress when the gesture ends
            withAnimation(.linear(duration: 0.2)) {
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
            left: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX - 1 && $0.positionY == currentPage.positionY }),
            right: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX + 1 && $0.positionY == currentPage.positionY }),
            top: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == currentPage.positionY + 1 }),
            bottom: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == currentPage.positionY - 1 })
        )
    }
}

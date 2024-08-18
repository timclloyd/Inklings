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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [Page]
    @StateObject private var pageManager: PageManager
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showMiniMap = false
    @GestureState private var magnifyBy = CGFloat(1.0)
    @State private var swipeProgress = SwipeProgress(direction: nil, progress: 0)
    @GestureState private var dragState = DragState.inactive
    
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    var body: some View {
        ZStack {
            if !showMiniMap {
                DottedBackgroundView(pageRect: pageManager.pageRect, adjacentPages: getAdjacentPages(), swipeProgress: swipeProgress, dragState: dragState)
                    .ignoresSafeArea()

                PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.getCurrentPage()?.drawingData ?? Data(), onDrawingChange: pageManager.updateDrawing, pageRect: pageManager.pageRect, onSwipe: handleSwipe)
                    .ignoresSafeArea()
            } else {
                MapView(pageManager: pageManager, pages: pages, onPageSelected: { selectedPage in
                    pageManager.setCurrentPage(selectedPage)
                    if let drawing = try? PKDrawing(data: selectedPage.drawingData) {
                        canvasView.drawing = drawing
                    }
                    showMiniMap = false
                }, showMiniMap: $showMiniMap)
            }
        }
        .gesture(makeMagnificationGesture())
    }
    
    private func makeMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                if !showMiniMap && value < 0.8 {
                    pageManager.updateAllThumbnails()
                    showMiniMap = true
                } else if showMiniMap && value > 1.2 {
                    showMiniMap = false
                }
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

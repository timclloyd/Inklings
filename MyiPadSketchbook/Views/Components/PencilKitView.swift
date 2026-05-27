//
//  PencilKitView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import PencilKit

// MARK: - PencilKitView
struct PencilKitView: UIViewRepresentable {
    // MARK: - Properties
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var drawing: PKDrawing
    var onDrawingChange: (PKDrawing) -> Void
    var pageRect: CGRect
    var onSwipe: (UIPanGestureRecognizer) -> Void
    var onPinch: (UIPinchGestureRecognizer) -> Void

    init(canvasView: Binding<PKCanvasView>,
         toolPicker: Binding<PKToolPicker>,
         drawing: PKDrawing,
         onDrawingChange: @escaping (PKDrawing) -> Void,
         pageRect: CGRect,
         onSwipe: @escaping (UIPanGestureRecognizer) -> Void,
         onPinch: @escaping (UIPinchGestureRecognizer) -> Void) {
        _canvasView = canvasView
        _toolPicker = toolPicker
        self.drawing = drawing
        self.onDrawingChange = onDrawingChange
        self.pageRect = pageRect
        self.onSwipe = onSwipe
        self.onPinch = onPinch
    }
    
    // MARK: - Methods
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        context.coordinator.setDrawing(drawing, on: canvasView)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.contentSize = pageRect.size
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        canvasView.zoomScale = 1
        canvasView.drawingPolicy = .pencilOnly

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        
        canvasView.addGestureRecognizer(panGesture)
        canvasView.addGestureRecognizer(pinchGesture)

        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        toolPicker.overrideUserInterfaceStyle = .unspecified

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.contentSize = pageRect.size

        if uiView.drawing != drawing {
            context.coordinator.setDrawing(drawing, on: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitView
        private var isApplyingDrawing = false

        init(_ parent: PencilKitView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing else { return }
            parent.onDrawingChange(canvasView.drawing)
        }

        func setDrawing(_ drawing: PKDrawing, on canvasView: PKCanvasView) {
            isApplyingDrawing = true
            canvasView.drawing = drawing
            isApplyingDrawing = false
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            parent.onSwipe(gesture)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            parent.onPinch(gesture)
        }
    }
}

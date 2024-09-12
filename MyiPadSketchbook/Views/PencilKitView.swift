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
    var drawing: Data
    var onDrawingChange: (PKDrawing) -> Void
    var pageRect: CGRect
    var onSwipe: (UIPanGestureRecognizer) -> Void

    // MARK: - Methods
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawing = try! PKDrawing(data: drawing)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.contentSize = pageRect.size
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        canvasView.zoomScale = 1

        // Set drawing policy to pencil only
        canvasView.drawingPolicy = .pencilOnly

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        canvasView.addGestureRecognizer(panGesture)

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let pkDrawing = try? PKDrawing(data: drawing), uiView.drawing != pkDrawing {
            uiView.drawing = pkDrawing
        }
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

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            parent.onSwipe(gesture)
        }
    }
}

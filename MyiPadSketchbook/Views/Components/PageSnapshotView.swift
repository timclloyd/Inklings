//
//  PageSnapshotView.swift
//  MyiPadSketchbook
//

import SwiftUI
import UIKit

struct PageSnapshotView: UIViewRepresentable {
    let image: UIImage
    let onSwipe: (UIPanGestureRecognizer) -> Void
    let onPinch: (UIPinchGestureRecognizer) -> Void

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.isOpaque = false
        imageView.isUserInteractionEnabled = true

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        imageView.addGestureRecognizer(panGesture)
        imageView.addGestureRecognizer(pinchGesture)

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        private let parent: PageSnapshotView

        init(_ parent: PageSnapshotView) {
            self.parent = parent
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            parent.onSwipe(gesture)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            parent.onPinch(gesture)
        }
    }
}

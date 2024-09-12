//
//  ContentView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-06.
//

import SwiftUI

struct AdjacentPages {
    let left: Bool
    let right: Bool
    let top: Bool
    let bottom: Bool
}

struct SwipeProgress: Equatable {
    var direction: EdgeDirection?
    var progress: CGFloat
    
    static func == (lhs: SwipeProgress, rhs: SwipeProgress) -> Bool {
        lhs.direction == rhs.direction && lhs.progress == rhs.progress
    }
}

enum EdgeDirection: CaseIterable {
    case left, right, top, bottom
}

enum DragState: Equatable {
    case inactive
    case dragging(translation: CGSize)
}

// MARK: - Color interpolation
extension Color {
    static func interpolate(from: Color, to: Color, progress: CGFloat) -> Color {
        let fromComponents = from.components
        let toComponents = to.components
        
        let r = fromComponents.red + (toComponents.red - fromComponents.red) * progress
        let g = fromComponents.green + (toComponents.green - fromComponents.green) * progress
        let b = fromComponents.blue + (toComponents.blue - fromComponents.blue) * progress
        let a = fromComponents.opacity + (toComponents.opacity - fromComponents.opacity) * progress
        
        return Color(.displayP3, red: r, green: g, blue: b, opacity: a)
    }
    
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, opacity: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o) else {
            return (0, 0, 0, 0)
        }
        
        return (r, g, b, o)
    }
}

// MARK: - Debouncer
class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue = DispatchQueue.main
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(_ callback: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: callback)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

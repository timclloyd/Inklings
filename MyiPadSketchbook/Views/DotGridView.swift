//
//  DottedBackgroundView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import PencilKit

// MARK: - DotGridView
struct DotGridView: View {
    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    let pageRect: CGRect
    let dotSize: CGFloat = 2.5
    let largeDotSize: CGFloat = 4
    let dotOpacity: CGFloat = 0.2
    let largeDotOpacity: CGFloat = 0.55
    let targetSpacing: CGFloat = 28
    let adjacentPages: AdjacentPages
    let swipeProgress: SwipeProgress
    let dragState: DragState
    
    // MARK: - Computed Properties
    var dotColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var largeDotColor: Color {
        colorScheme == .dark ? .accentColor : .accentColor
    }
    
    // MARK: - Body
    var body: some View {
        Canvas { context, size in
            let horizontalSpaces = max(2, Int((size.width / targetSpacing).rounded()))
            let verticalSpaces = max(2, Int((size.height / targetSpacing).rounded()))
            let horizontalSpacing = size.width / CGFloat(horizontalSpaces)
            let verticalSpacing = size.height / CGFloat(verticalSpaces)
            let horizontalDots = horizontalSpaces - 1
            let verticalDots = verticalSpaces - 1
            
            let animationProgress: CGFloat
            let animationDirection: EdgeDirection?
            
            switch dragState {
            case .inactive:
                animationProgress = 0 //swipeProgress.progress
                animationDirection = swipeProgress.direction
            case .dragging(let translation):
                animationProgress = 0 //min(1.0, max(abs(translation.width), abs(translation.height)) / (size.width / 4))
                if abs(translation.width) > abs(translation.height) {
                    animationDirection = translation.width > 0 ? .left : .right
                } else {
                    animationDirection = translation.height > 0 ? .top : .bottom
                }
            }
            
            for x in 0..<horizontalDots {
                for y in 0..<verticalDots {
                    var currentDotSize = dotSize
                    var currentOpacity = dotOpacity
                    var currentColor = dotColor
                    
                    let isEdgeDot = x == 0 || x == horizontalDots - 1 || y == 0 || y == verticalDots - 1
                    let isAnimatedEdge = (x == 0 && animationDirection == .left) ||
                                         (x == horizontalDots - 1 && animationDirection == .right) ||
                                         (y == 0 && animationDirection == .top) ||
                                         (y == verticalDots - 1 && animationDirection == .bottom)
                    
                    if isEdgeDot {
                        let edgeProgress: CGFloat
                        if x == 0 || x == horizontalDots - 1 {
                            edgeProgress = 1 - abs((CGFloat(y) / CGFloat(verticalDots - 1)) - 0.5) * 2
                        } else {
                            edgeProgress = 1 - abs((CGFloat(x) / CGFloat(horizontalDots - 1)) - 0.5) * 2
                        }
                        
                        let isAdjacentEdge = (x == 0 && adjacentPages.left) ||
                                             (x == horizontalDots - 1 && adjacentPages.right) ||
                                             (y == 0 && adjacentPages.top) ||
                                             (y == verticalDots - 1 && adjacentPages.bottom)
                        
                        if isAdjacentEdge {
                            // Existing page: enhance current large dot attributes while maintaining progression
                            let baseSize = dotSize + (largeDotSize - dotSize) * edgeProgress
                            let baseOpacity = dotOpacity + (largeDotOpacity - dotOpacity) * edgeProgress
                            
                            if isAnimatedEdge {
                                let enhancementFactor = 0.5 * animationProgress * edgeProgress
                                currentDotSize = baseSize + (largeDotSize - dotSize) * enhancementFactor
                                currentOpacity = baseOpacity + (1 - baseOpacity) * enhancementFactor
                            } else {
                                currentDotSize = baseSize
                                currentOpacity = baseOpacity
                            }
                            currentColor = largeDotColor
                        } else if isAnimatedEdge {
                            // New page: animate from normal to large dot attributes
                            currentDotSize = dotSize + (largeDotSize - dotSize) * edgeProgress * animationProgress * 1.5
                            currentOpacity = min(1, dotOpacity + (largeDotOpacity - dotOpacity) * edgeProgress * animationProgress * 1.5)
//                            currentColor = Color.interpolate(from: dotColor, to: .green, progress: animationProgress)
                            
                            if animationProgress >= 1.0 {
                                currentDotSize *= 1.5
                                currentColor = .green
                            }
                        }
                    }
                    
                    let dotRect = CGRect(
                        x: CGFloat(x + 1) * horizontalSpacing - currentDotSize/2,
                        y: CGFloat(y + 1) * verticalSpacing - currentDotSize/2,
                        width: currentDotSize,
                        height: currentDotSize
                    )
                    let dotPath = Path(ellipseIn: dotRect)
                    context.fill(dotPath, with: .color(currentColor.opacity(currentOpacity)))
                }
            }
        }
        .frame(width: pageRect.width, height: pageRect.height)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .animation(.linear(duration: 0.1), value: dragState)
        .animation(.linear(duration: 0.1), value: swipeProgress)
    }
}

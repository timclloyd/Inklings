//
//  EdgeOverlayView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-28.
//

import Foundation
import SwiftUI

struct EdgeOverlayView: View {
    let direction: EdgeDirection?
    let progress: CGFloat
    let size: CGSize
    let threshold: CGFloat = 0.2
    let createThreshold: CGFloat = 1
    let adjacentPages: AdjacentPages
    @Environment(\.colorScheme) var colorScheme

    private let arrowDiameter: CGFloat = 32
    private let shadowRadius: CGFloat = 15
    private let edgeDistance: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(EdgeDirection.allCases, id: \.self) { edge in
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.black : Color.white)
                            .frame(width: arrowDiameter-1, height: arrowDiameter-1)
                        
                        Image(systemName: arrowSystemName(for: edge))
                            .font(.system(size: arrowDiameter))
                            .foregroundColor(arrowColor(for: edge))
                    }
                    .shadow(color: colorScheme == .dark ? .clear : .primary.opacity(0.15),
                            radius: shadowRadius, x: 0, y: 0)
                    .opacity(arrowOpacity(for: edge))
                    .position(CGPoint(x: geometry.size.width / 2, y: edgeDistance + arrowDiameter / 2 - 1))
                }
            }
        }
    }
    
    private func arrowSystemName(for edge: EdgeDirection) -> String {
        switch edge {
        case .left:
            return "arrow.left.circle.fill"
        case .right:
            return "arrow.right.circle.fill"
        case .top:
            return "arrow.up.circle.fill"
        case .bottom:
            return "arrow.down.circle.fill"
        }
    }

    private func arrowOpacity(for edge: EdgeDirection) -> Double {
        guard let direction = direction, direction == edge else {
            return 0
        }
        
        if progress >= createThreshold {
            return 1
        } else if progress > threshold {
            return 0
        } else {
            return 0
        }
    }
    
    private func arrowColor(for edge: EdgeDirection) -> Color {
        guard let direction = direction, direction == edge else {
            return .blue
        }

        let hasAdjacentPage = hasAdjacentPage(for: edge)
        if hasAdjacentPage {
            return .blue
        } else {
            return .green
        }
    }
    
    private func hasAdjacentPage(for edge: EdgeDirection) -> Bool {
        switch edge {
        case .left:
            return adjacentPages.left
        case .right:
            return adjacentPages.right
        case .top:
            return adjacentPages.top
        case .bottom:
            return adjacentPages.bottom
        }
    }
}

extension EdgeDirection: CaseIterable {
    static var allCases: [EdgeDirection] {
        return [.left, .right, .top, .bottom]
    }
}

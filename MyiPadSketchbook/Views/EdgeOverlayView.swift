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

    private let arrowDiameter: CGFloat = 70
    private let edgeDistance: CGFloat = 30
    private let mediumOpacity: Double = 0.5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(EdgeDirection.allCases, id: \.self) { edge in
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.black : Color.white)
                            .frame(width: arrowDiameter, height: arrowDiameter)
                        
                        Image(systemName: arrowSystemName(for: edge))
                            .font(.system(size: arrowDiameter))
                            .foregroundColor(arrowColor(for: edge))
                    }
                    .opacity(arrowOpacity(for: edge))
                    .position(arrowPosition(for: edge, in: geometry))
                }
            }
        }
    }
    
    private func arrowSystemName(for edge: EdgeDirection) -> String {
        switch edge {
        case .left:
            return "arrowshape.left.circle.fill"
        case .right:
            return "arrowshape.right.circle.fill"
        case .top:
            return "arrowshape.up.circle.fill"
        case .bottom:
            return "arrowshape.down.circle.fill"
        }
    }
    
    private func arrowPosition(for edge: EdgeDirection, in geometry: GeometryProxy) -> CGPoint {
        switch edge {
        case .left:
            return CGPoint(x: edgeDistance + arrowDiameter / 2, y: geometry.size.height / 2)
        case .right:
            return CGPoint(x: geometry.size.width - edgeDistance - arrowDiameter / 2, y: geometry.size.height / 2)
        case .top:
            return CGPoint(x: geometry.size.width / 2, y: edgeDistance + arrowDiameter / 2)
        case .bottom:
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height - edgeDistance - arrowDiameter / 2)
        }
    }

    private func arrowOpacity(for edge: EdgeDirection) -> Double {
        guard let direction = direction, direction == edge else {
            return 0
        }
        
        if progress >= createThreshold {
            return 1
        } else if progress > threshold {
            // Smooth transition from 0 to mediumOpacity
            return Double(progress) * mediumOpacity
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
            return progress >= createThreshold ? .green : .blue
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

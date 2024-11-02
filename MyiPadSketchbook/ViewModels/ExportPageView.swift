//
//  ExportPageView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-11-02.
//

import Foundation
import SwiftUI
import PencilKit
import UIKit

struct ExportPageView: View {
    let pageManager: PageManager
    let page: Page
    let colorScheme: ColorScheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background with dots
            DotGridView(
                pageRect: pageManager.pageRect,
                adjacentPages: AdjacentPages(left: false, right: false, top: false, bottom: false),
                swipeProgress: SwipeProgress(direction: nil, progress: 0),
                dragState: .inactive
            )
            .environment(\.colorScheme, colorScheme)
            
            // Drawing content
            if let drawing = try? PKDrawing(data: page.drawingData ?? Data()) {
                Image(uiImage: drawing.image(from: pageManager.pageRect, scale: UIScreen.main.scale))
                    .resizable()
                    .scaledToFit()
            }
            
            // Coordinate label
            Text("\(page.positionX ?? 0), \(page.positionY ?? 0)")
                .font(.system(size: 14))
                .padding(2)
                .padding(.horizontal, 4)
                .foregroundColor(Color.primary.opacity(0.87))
                .background(Color(.systemGray5))
                .cornerRadius(7)
                .padding(.bottom, 18)
        }
        .frame(width: pageManager.pageRect.width, height: pageManager.pageRect.height)
        .environment(\.colorScheme, colorScheme)
    }
}

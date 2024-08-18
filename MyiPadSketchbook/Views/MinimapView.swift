//
//  MinimapView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import PencilKit

struct MiniMapView: View {
    @ObservedObject var pageManager: PageManager
    let pages: [Page]
    @Environment(\.colorScheme) var colorScheme
    var onPageSelected: (Page) -> Void
    @Binding var showMiniMap: Bool
    @State private var panOffset: CGSize = .zero
    @State private var draggedPage: Page?
    @State private var draggedPageOffset: CGSize = .zero
    @State private var isRearranging: Bool = false
    @GestureState private var dragGestureState: CGSize = .zero

    private var thumbnailSize: CGSize {
        let aspectRatio = pageManager.pageRect.width / pageManager.pageRect.height
        return CGSize(width: 120, height: 120 / aspectRatio)
    }
    private let spacing: CGFloat = 10

    private var pagePositions: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let xPositions = pages.map { $0.positionX }
        let yPositions = pages.map { $0.positionY }
        return (
            minX: xPositions.min() ?? 0,
            maxX: xPositions.max() ?? 0,
            minY: yPositions.min() ?? 0,
            maxY: yPositions.max() ?? 0
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground)
                    .contentShape(Rectangle())

                ZStack {
                    ForEach(pages) { page in
                        thumbnailView(for: page, in: geometry)
                    }
                }
                .offset(x: panOffset.width + dragGestureState.width,
                        y: panOffset.height + dragGestureState.height)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isRearranging.toggle()
                        }) {
                            Text(isRearranging ? "Done" : "Rearrange")
                                .padding(8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .gesture(
                DragGesture()
                    .updating($dragGestureState) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        self.panOffset = CGSize(
                            width: self.panOffset.width + value.translation.width,
                            height: self.panOffset.height + value.translation.height
                        )
                    }
            )
        }
        .onAppear {
            centerOnCurrentPage()
        }
    }

    private func thumbnailView(for page: Page, in geometry: GeometryProxy) -> some View {
        let isSelected = draggedPage?.id == page.id
        let appearance = isSelected && isRearranging ?
            ThumbnailAppearance.dragging(colorScheme: colorScheme) :
            ThumbnailAppearance.normal(colorScheme: colorScheme)

        return ThumbnailContent(page: page, thumbnailSize: thumbnailSize, colorScheme: colorScheme)
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(appearance.borderColor, lineWidth: appearance.borderWidth))
            .background(appearance.backgroundColor)
            .scaleEffect(appearance.scale)
            .opacity(appearance.opacity)
            .position(thumbnailPosition(for: page, in: geometry))
            .offset(isSelected && isRearranging ? draggedPageOffset : .zero)
            .zIndex(isSelected && isRearranging ? 1 : 0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if self.isRearranging {
                            self.draggedPage = page
                            self.draggedPageOffset = value.translation
                        } else if value.translation != .zero {
                            // Handle panning when not rearranging
                            self.panOffset.width += value.translation.width
                            self.panOffset.height += value.translation.height
                        }
                    }
                    .onEnded { value in
                        if self.isRearranging {
                            let gridMovement = self.calculateGridMovement(value.translation)
                            let newPosition = (
                                x: page.positionX + gridMovement.x,
                                y: page.positionY + gridMovement.y
                            )
                            if self.isValidMove(to: newPosition) {
                                page.positionX = newPosition.x
                                page.positionY = newPosition.y
                                self.pageManager.updatePagePosition(page)
                            }
                            self.draggedPage = nil
                            self.draggedPageOffset = .zero
                        } else if value.translation == .zero {
                            // Handle tap when not rearranging
                            self.onPageSelected(page)
                            self.showMiniMap = false
                        }
                    }
            )
    }

    private func calculateGridMovement(_ translation: CGSize) -> (x: Int, y: Int) {
        let xMovement = Int(round(translation.width / (thumbnailSize.width + spacing)))
        let yMovement = -Int(round(translation.height / (thumbnailSize.height + spacing)))
        return (x: xMovement, y: yMovement)
    }

    private func isValidMove(to position: (x: Int, y: Int)) -> Bool {
        !pages.contains { $0.id != draggedPage?.id && $0.positionX == position.x && $0.positionY == position.y }
    }

    private func thumbnailPosition(for page: Page, in geometry: GeometryProxy) -> CGPoint {
        let x = CGFloat(page.positionX - pagePositions.minX) * (thumbnailSize.width + spacing)
        let y = CGFloat(pagePositions.maxY - page.positionY) * (thumbnailSize.height + spacing)
        return CGPoint(x: x, y: y)
    }

    private func centerOnCurrentPage() {
        guard let currentPage = pageManager.getCurrentPage() else { return }
        let screenSize = UIScreen.main.bounds.size
        
        let currentPagePosition = CGPoint(
            x: CGFloat(currentPage.positionX - pagePositions.minX) * (thumbnailSize.width + spacing),
            y: CGFloat(pagePositions.maxY - currentPage.positionY) * (thumbnailSize.height + spacing)
        )
        
        panOffset = CGSize(
            width: screenSize.width / 2 - currentPagePosition.x - thumbnailSize.width / 2,
            height: screenSize.height / 2 - currentPagePosition.y - thumbnailSize.height / 2
        )
    }
}

// MARK: - ThumbnailAppearance

struct ThumbnailAppearance {
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let scale: CGFloat
    let opacity: Double
    let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)?

    static func normal(colorScheme: ColorScheme) -> ThumbnailAppearance {
        ThumbnailAppearance(
            backgroundColor: colorScheme == .dark ? Color.black : Color.white,
            borderColor: colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25),
            borderWidth: 1,
            scale: 1.0,
            opacity: 1.0,
            shadow: nil
        )
    }

    static func dragging(colorScheme: ColorScheme) -> ThumbnailAppearance {
        ThumbnailAppearance(
            backgroundColor: colorScheme == .dark ? Color.black : Color.white,
            borderColor: .blue,
            borderWidth: 2.5,
            scale: 1.075,
            opacity: 1.0,
            shadow: nil
        )
    }
}

struct ThumbnailContent: View {
    let page: Page
    let thumbnailSize: CGSize
    let colorScheme: ColorScheme
    
    var body: some View {
        Group {
            if let thumbnailData = page.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray)
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
    }
}

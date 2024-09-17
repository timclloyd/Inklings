//
//  MapView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import SwiftUI
import PencilKit
import SwiftData
import UIKit

// MARK: - MapView
struct MapView: View {
    // MARK: - Properties
    @ObservedObject var pageManager: PageManager
    let pages: [Page]
    @Environment(\.colorScheme) var colorScheme
    var onPageSelected: (Page) -> Void
    @Binding var showMiniMap: Bool
    var onCloseMap: () -> Void
    
    // MARK: - State
    @State private var panOffset: CGSize = .zero
    @State private var draggedPage: Page?
    @State private var draggedPageOffset: CGSize = .zero
    @GestureState private var dragGestureState: CGSize = .zero
    @State private var contentOffset: CGPoint = .zero
    
    @State private var isRearranging: Bool = false
    @GestureState private var dragLocation: CGPoint = .zero
    @State private var scrollViewProxy: ScrollViewProxy?
    
    // MARK: - Constants
    private let spacing: CGFloat = 6
    private let mapViewEdgePadding = 4
    
    // MARK: - Computed Properties
    private var thumbnailSize: CGSize {
        let aspectRatio = pageManager.pageRect.width / pageManager.pageRect.height
        return CGSize(width: 120, height: 120 / aspectRatio)
    }
    
    private var pagePositions: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let xPositions = pages.map { $0.positionX ?? 0 }
        let yPositions = pages.map { $0.positionY ?? 0 }
        return (
            minX: xPositions.min() ?? 0,
            maxX: xPositions.max() ?? 0,
            minY: yPositions.min() ?? 0,
            maxY: yPositions.max() ?? 0
        )
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var contentWidth: CGFloat {
        let pageCountX = pagePositions.maxX - pagePositions.minX + 1 + (2 * mapViewEdgePadding)
        return CGFloat(pageCountX) * (thumbnailSize.width + spacing) + spacing
    }
    
    private var contentHeight: CGFloat {
        let pageCountY = pagePositions.maxY - pagePositions.minY + 1 + (2 * mapViewEdgePadding)
        return CGFloat(pageCountY) * (thumbnailSize.height + spacing) + spacing
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        thumbnailsView(in: geometry)
                    }
                    .gesture(panGesture)
                    .onAppear {
                        self.scrollViewProxy = proxy
                        self.centreOnCurrentPage()
                    }
                }
                .edgesIgnoringSafeArea(.all)
                .zIndex(0)
                
                VStack {
                    HStack {
                        Spacer()
                        toolbarView
                    }
                    Spacer()
                }
                .zIndex(1)
            }
        }
        .onAppear(perform: centreOnCurrentPage)
        .onChange(of: colorScheme) {
            pageManager.updateAllThumbnails()
        }
    }
    
    // MARK: - Subviews
    private func thumbnailsView(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(pages) { page in
                thumbnailView(for: page, in: geometry)
            }
        }
        .frame(width: contentWidth, height: contentHeight)
    }
    
    private var toolbarView: some View {
        VStack(spacing: 0) {
            closeButton
            rearrangeButton
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
        .cornerRadius(14)
        .padding(.trailing, 10)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 14)
    }
    
    // MARK: - Buttons    
    private var closeButton: some View {
        Button(action: onCloseMap) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: toolbarButtonSize * 1.5, weight: .light))
                .padding(13) // Expand tappable area
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                )
        }
        .contentShape(Circle()) // Ensure the tappable area is circular
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: -1, leading: 0, bottom: -2, trailing: 0)) // Layout padding
    }
    
    private var rearrangeButton: some View {
        Button(action: { isRearranging.toggle() }) {
            Image(systemName: isRearranging ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: isRearranging ? toolbarButtonSize * 1.15 : toolbarButtonSize))
                .foregroundColor(isRearranging ? Color.accentColor : Color.primary)
                .padding(9)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 10, trailing: 7))
    }
    
    // MARK: - Thumbnail View
    private func thumbnailView(for page: Page, in geometry: GeometryProxy) -> some View {
        let isSelected = draggedPage?.id == page.id
        let isCurrentPage = page.id == pageManager.getCurrentPage()?.id
        let appearance = thumbnailAppearance(for: page, isSelected: isSelected && isRearranging, isCurrentPage: isCurrentPage)
        let overlappingPages = getOverlappingPages(for: page)
        let hasOverlap = overlappingPages.count > 1
        
        return ZStack {
            ThumbnailContent(page: page, thumbnailSize: thumbnailSize, colorScheme: colorScheme)
                .overlay(thumbnailBorder(appearance: appearance, isCurrentPage: isCurrentPage))
                .background(appearance.backgroundColor)
                .scaleEffect(appearance.scale)
                .opacity(appearance.opacity)
                .shadow(
                    color: isSelected && isRearranging ? Color.black.opacity(0.3) : Color.clear,
                    radius: isSelected && isRearranging ? 10 : 0,
                    x: 0,
                    y: 5
                )
                .id("page_\(page.id?.uuidString ?? "")")
            
            if hasOverlap {
                overlapIndicator(count: overlappingPages.count)
            }
        }
        .position(thumbnailPosition(for: page))
        .offset(isSelected && isRearranging ? draggedPageOffset : .zero)
        .zIndex(isSelected && isRearranging ? 1 : 0)
        .gesture(isRearranging ? dragGesture(for: page) : nil)
        .onTapGesture {
            if !isRearranging {
                onPageSelected(page)
                showMiniMap = false
            }
        }
    }
    
    private func thumbnailAppearance(for page: Page, isSelected: Bool, isCurrentPage: Bool) -> ThumbnailAppearance {
        if isSelected && isRearranging {
            return .dragging(colorScheme: colorScheme)
        } else if isCurrentPage {
            return .current(colorScheme: colorScheme)
        } else {
            return .normal(colorScheme: colorScheme)
        }
    }
    
    private func thumbnailBorder(appearance: ThumbnailAppearance, isCurrentPage: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                isRearranging ? .accentColor : appearance.borderColor,
                style: StrokeStyle(
                    lineWidth: appearance.borderWidth,
                    dash: isRearranging ? [5] : []
                )
            )
    }
    
    private func overlapIndicator(count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 16))
            .foregroundColor(.white)
            .padding(6)
            .background(Color.red)
            .clipShape(Circle())
            .offset(x: thumbnailSize.width / 2 - 16, y: -thumbnailSize.height / 2 + 16)
    }
    
    // MARK: - Gestures
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isRearranging {
                    contentOffset.x -= value.translation.width
                    contentOffset.y -= value.translation.height
                }
            }
    }
    
    private func dragGesture(for page: Page) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragLocation) { value, state, _ in
                state = value.location
            }
            .onChanged { value in
                if isRearranging {
                    draggedPage = page
                    draggedPageOffset = value.translation
                }
            }
            .onEnded { value in
                if isRearranging {
                    let gridMovement = calculateGridMovement(value.translation)
                    let newPosition = (
                        x: (page.positionX ?? 0) + gridMovement.x,
                        y: (page.positionY ?? 0) + gridMovement.y
                    )
                    if isValidMove(to: newPosition) {
                        page.positionX = newPosition.x
                        page.positionY = newPosition.y
                        pageManager.updatePagePosition(page)
                    }
                    draggedPage = nil
                    draggedPageOffset = .zero
                } else if value.translation == .zero {
                    onPageSelected(page)
                    showMiniMap = false
                }
            }
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChange(_ value: DragGesture.Value, for page: Page) {
        if isRearranging {
            draggedPage = page
            draggedPageOffset = value.translation
        } else if value.translation != .zero {
            // Pan the view
            contentOffset.x -= value.translation.width
            contentOffset.y -= value.translation.height
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value, for page: Page) {
        if isRearranging {
            let gridMovement = calculateGridMovement(value.translation)
            let newPosition = (
                x: (page.positionX ?? 0) + gridMovement.x,
                y: (page.positionY ?? 0) + gridMovement.y
            )
            if isValidMove(to: newPosition) {
                page.positionX = newPosition.x
                page.positionY = newPosition.y
                pageManager.updatePagePosition(page)
            }
            draggedPage = nil
            draggedPageOffset = .zero
        } else if value.translation == .zero {
            onPageSelected(page)
            showMiniMap = false
        }
    }
    
    // MARK: - Helper Methods
    private func thumbnailPosition(for page: Page) -> CGPoint {
        let x = CGFloat((page.positionX ?? 0) - pagePositions.minX + mapViewEdgePadding) * (thumbnailSize.width + spacing) + thumbnailSize.width / 2 + spacing
        let y = CGFloat(pagePositions.maxY - (page.positionY ?? 0) + mapViewEdgePadding) * (thumbnailSize.height + spacing) + thumbnailSize.height / 2 + spacing
        return CGPoint(x: x, y: y)
    }
    
    private func calculateGridMovement(_ translation: CGSize) -> (x: Int, y: Int) {
        let xMovement = Int(round(translation.width / (thumbnailSize.width + spacing)))
        let yMovement = -Int(round(translation.height / (thumbnailSize.height + spacing)))
        return (x: xMovement, y: yMovement)
    }
    
    private func isValidMove(to position: (x: Int, y: Int)) -> Bool {
        let minX = pagePositions.minX - mapViewEdgePadding
        let maxX = pagePositions.maxX + mapViewEdgePadding
        let minY = pagePositions.minY - mapViewEdgePadding
        let maxY = pagePositions.maxY + mapViewEdgePadding
        
        let isWithinBounds = position.x >= minX && position.x <= maxX && position.y >= minY && position.y <= maxY
        let isNotOccupied = !pages.contains { $0.id != draggedPage?.id && $0.positionX == position.x && $0.positionY == position.y }
        
        return isWithinBounds && isNotOccupied
    }
    
    private func centreOnCurrentPage() {
        guard let currentPage = pageManager.getCurrentPage(),
              let scrollViewProxy = scrollViewProxy else { return }
        
        let id = "page_\(currentPage.id?.uuidString ?? "")"
        
        withAnimation(nil) {
            scrollViewProxy.scrollTo(id, anchor: .center)
        }
    }
    
    private func getOverlappingPages(for page: Page) -> [Page] {
        pages.filter { $0.positionX == page.positionX && $0.positionY == page.positionY }
    }
    
    // MARK: - ThumbnailContent
    struct ThumbnailContent: View {
        let page: Page
        let thumbnailSize: CGSize
        let colorScheme: ColorScheme
        let cornerRadius: CGFloat = 14
        
        var body: some View {
            ZStack(alignment: .bottom) {
                thumbnailImage
                coordinateLabel
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.clear)
            )
        }
        
        private var thumbnailImage: some View {
            Group {
                if let thumbnailData = page.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.clear)
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipped()
        }
        
        private var coordinateLabel: some View {
            Text("\(page.positionX ?? 0), \(page.positionY ?? 0)")
                .font(.system(size: 10))
                .padding(2)
                .padding(.horizontal, 3)
                .foregroundColor(Color.primary.opacity(0.87))
                .background(Color(.systemGray5))
                .cornerRadius(5)
                .padding(.bottom, 3)
        }
    }
    
    // MARK: - ThumbnailAppearance
    struct ThumbnailAppearance {
        let backgroundColor: Color
        let borderColor: Color
        let borderWidth: CGFloat
        let scale: CGFloat
        let opacity: Double
        
        static func normal(colorScheme: ColorScheme) -> ThumbnailAppearance {
            ThumbnailAppearance(
                backgroundColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderWidth: 1,
                scale: 1.0,
                opacity: 1.0
            )
        }
        
        static func current(colorScheme: ColorScheme) -> ThumbnailAppearance {
            ThumbnailAppearance(
                backgroundColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderColor: .primary,
                borderWidth: 2,
                scale: 1.0,
                opacity: 1.0
            )
        }
        
        static func dragging(colorScheme: ColorScheme) -> ThumbnailAppearance {
            ThumbnailAppearance(
                backgroundColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderColor: .accentColor,
                borderWidth: 2,
                scale: 1.05,
                opacity: 1.0
            )
        }
    }
    
    struct ActivityViewController: UIViewControllerRepresentable {
        let activityItems: [Any]
        let applicationActivities: [UIActivity]?
        let filename: String
        
        func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
            let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
            
            controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
                if let url = activityItems.first as? URL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
    }
}

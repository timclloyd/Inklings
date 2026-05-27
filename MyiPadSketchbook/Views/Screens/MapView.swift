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
    @Environment(\.colorScheme) var colorScheme
    var onPageSelected: (Page) -> Void
    @Binding var showMap: Bool
    var onCloseMap: () -> Void
    
    // MARK: - State
    @State private var panOffset: CGSize = .zero
    @State private var draggedPage: Page?
    @State private var draggedPageOffset: CGSize = .zero
    @GestureState private var dragGestureState: CGSize = .zero
    @State private var contentOffset: CGPoint = .zero
    @State private var scrollTarget: CGPoint?
    @State private var scrollTargetAnimated: Bool = true
    
    @State private var isRearranging: Bool = false
    @State private var showNotebookView: Bool = false
    @GestureState private var dragLocation: CGPoint = .zero
    
    // MARK: - Constants
    private let spacing: CGFloat = 6
    private let mapViewEdgePadding = 4
    private let toolbarHeight: CGFloat = 64
    
    // MARK: - Computed Properties
    private var pages: [Page] {
        pageManager.pages
    }

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

    private var mapGridPositions: [MapGridPosition] {
        let xRange = (pagePositions.minX - mapViewEdgePadding)...(pagePositions.maxX + mapViewEdgePadding)
        let yRange = (pagePositions.minY - mapViewEdgePadding)...(pagePositions.maxY + mapViewEdgePadding)

        return xRange.flatMap { x in
            yRange.map { y in MapGridPosition(x: x, y: y) }
        }
    }

    private var mapContentRevision: String {
        let pageRevision = pages
            .map { page in
                "\(page.id?.uuidString ?? ""):\(page.positionX ?? 0):\(page.positionY ?? 0):\(page.thumbnailData?.count ?? 0)"
            }
            .joined(separator: "|")

        return "\(pageRevision)|\(isRearranging)|\(colorScheme)"
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                Group {
                    if showNotebookView {
                        NotebookView(
                            pageManager: pageManager,
                            topInset: geometry.safeAreaInsets.top + toolbarHeight + 24,
                            onNotebookSelected: { notebook in
                                pageManager.switchToNotebook(notebook)
                                showNotebookView = false
                            }
                        )
                            .transition(.opacity)
                    } else {
                        MapScrollView(
                            contentSize: CGSize(width: contentWidth, height: contentHeight),
                            contentRevision: mapContentRevision,
                            contentOffset: $contentOffset,
                            scrollTarget: $scrollTarget,
                            scrollTargetAnimated: $scrollTargetAnimated
                        ) {
                            thumbnailsView(in: geometry)
                        }
                        .edgesIgnoringSafeArea(.all)
                    }
                }
                .zIndex(0)
                
                VStack(spacing: 0) {
                    toolbarView
                        .padding(.top, geometry.safeAreaInsets.top)
                    Spacer()
                }
                .zIndex(1)

                if !showNotebookView {
                    notebookMiniMap(in: geometry)
                        .zIndex(2)
                }
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

    private func notebookMiniMap(in geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()

            HStack {
                NotebookMapPreview(
                    pages: pages,
                    colorScheme: colorScheme,
                    edgePadding: mapViewEdgePadding,
                    innerPadding: 10,
                    pageSpacing: 2,
                    viewport: miniMapViewport(for: geometry.size),
                    onContentPointChanged: { contentPoint in
                        scrollToMiniMapPoint(contentPoint, viewportSize: geometry.size, animated: false)
                    },
                    onContentPointSelected: { contentPoint in
                        scrollToMiniMapPoint(contentPoint, viewportSize: geometry.size, animated: true)
                    }
                )
                .padding(8)
                .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemBackground).opacity(0.92))
                )

                Spacer()
            }
            .padding(.leading, 12)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 12)
        }
        .allowsHitTesting(!isRearranging)
    }
    
    private var toolbarView: some View {
        HStack {
            if showNotebookView {
                addNotebookButton
            } else {
                notebooksButton
                    .padding(.leading, 10)

                Spacer()

                HStack(spacing: 18) {
                    rearrangeButton
                    ShareButton(pageManager: pageManager)
                }
                .padding(.trailing, 10)
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Buttons
    private var notebooksButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.16)) {
                showNotebookView = true
            }
        }) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: toolbarButtonSize))
                .foregroundColor(Color.primary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
    }

    private var rearrangeButton: some View {
        Button(action: { isRearranging.toggle() }) {
            Image(systemName: isRearranging ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: toolbarButtonSize, weight: .light))
                .foregroundColor(isRearranging ? Color.orange : Color.primary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
    }

    private var addNotebookButton: some View {
        Button(action: {
            _ = pageManager.createNotebook()
            showNotebookView = false
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: toolbarButtonSize))
                .foregroundColor(Color.primary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                )
        }
        .contentShape(Circle())
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(.leading, 10)
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
                showMap = false
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
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                isRearranging ? .orange : appearance.borderColor,
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
                    showMap = false
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
            showMap = false
        }
    }
    
    // MARK: - Helper Methods
    private func thumbnailPosition(for page: Page) -> CGPoint {
        let x = CGFloat((page.positionX ?? 0) - pagePositions.minX + mapViewEdgePadding) * (thumbnailSize.width + spacing) + thumbnailSize.width / 2 + spacing
        let y = CGFloat(pagePositions.maxY - (page.positionY ?? 0) + mapViewEdgePadding) * (thumbnailSize.height + spacing) + thumbnailSize.height / 2 + spacing
        return CGPoint(x: x, y: y)
    }

    private func thumbnailPosition(for position: MapGridPosition) -> CGPoint {
        let x = CGFloat(position.x - pagePositions.minX + mapViewEdgePadding) * (thumbnailSize.width + spacing) + thumbnailSize.width / 2 + spacing
        let y = CGFloat(pagePositions.maxY - position.y + mapViewEdgePadding) * (thumbnailSize.height + spacing) + thumbnailSize.height / 2 + spacing
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

    private func miniMapViewport(for visibleSize: CGSize) -> CGRect {
        let width = min(1, visibleSize.width / max(1, contentWidth))
        let height = min(1, visibleSize.height / max(1, contentHeight))
        let x = min(max(0, contentOffset.x / max(1, contentWidth)), max(0, 1 - width))
        let y = min(max(0, contentOffset.y / max(1, contentHeight)), max(0, 1 - height))

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func scrollToGridPosition(_ position: (x: Int, y: Int), viewportSize: CGSize, animated: Bool) {
        let targetPosition = thumbnailPosition(for: MapGridPosition(x: position.x, y: position.y))
        let unclampedOffset = CGPoint(
            x: targetPosition.x - viewportSize.width / 2,
            y: targetPosition.y - viewportSize.height / 2
        )

        scrollTargetAnimated = animated
        scrollTarget = clampedContentOffset(unclampedOffset, viewportSize: viewportSize)
    }

    private func scrollToMiniMapPoint(_ point: CGPoint, viewportSize: CGSize, animated: Bool) {
        let unclampedOffset = CGPoint(
            x: point.x * contentWidth - viewportSize.width / 2,
            y: point.y * contentHeight - viewportSize.height / 2
        )

        scrollTargetAnimated = animated
        scrollTarget = clampedContentOffset(unclampedOffset, viewportSize: viewportSize)
    }
    
    private func centreOnCurrentPage() {
        guard let currentPage = pageManager.getCurrentPage() else { return }

        let visibleSize = UIScreen.main.bounds.size
        let targetPosition = thumbnailPosition(for: MapGridPosition(
            x: currentPage.positionX ?? 0,
            y: currentPage.positionY ?? 0
        ))
        let unclampedOffset = CGPoint(
            x: targetPosition.x - visibleSize.width / 2,
            y: targetPosition.y - visibleSize.height / 2
        )

        scrollTarget = clampedContentOffset(unclampedOffset, viewportSize: visibleSize)
    }

    private func clampedContentOffset(_ offset: CGPoint, viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, offset.x), max(0, contentWidth - viewportSize.width)),
            y: min(max(0, offset.y), max(0, contentHeight - viewportSize.height))
        )
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
                borderWidth: 1.5,
                scale: 1.0,
                opacity: 1.0
            )
        }
        
        static func current(colorScheme: ColorScheme) -> ThumbnailAppearance {
            ThumbnailAppearance(
                backgroundColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderColor: .primary,
                borderWidth: 1.5,
                scale: 1.0,
                opacity: 1.0
            )
        }
        
        static func dragging(colorScheme: ColorScheme) -> ThumbnailAppearance {
            ThumbnailAppearance(
                backgroundColor: colorScheme == .dark ? Color.clear : Color.clear,
                borderColor: .orange,
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

private struct MapGridPosition: Identifiable, Hashable {
    let x: Int
    let y: Int

    var id: String {
        "\(x)_\(y)"
    }
}

private struct MapScrollView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let contentRevision: String
    @Binding var contentOffset: CGPoint
    @Binding var scrollTarget: CGPoint?
    @Binding var scrollTargetAnimated: Bool
    let content: Content

    init(
        contentSize: CGSize,
        contentRevision: String,
        contentOffset: Binding<CGPoint>,
        scrollTarget: Binding<CGPoint?>,
        scrollTargetAnimated: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.contentSize = contentSize
        self.contentRevision = contentRevision
        _contentOffset = contentOffset
        _scrollTarget = scrollTarget
        _scrollTargetAnimated = scrollTargetAnimated
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentOffset: $contentOffset, scrollTarget: $scrollTarget)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.addSubview(hostingController.view)
        scrollView.contentSize = contentSize

        context.coordinator.hostingController = hostingController
        context.coordinator.contentRevision = contentRevision
        context.coordinator.contentSize = contentSize

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if context.coordinator.contentRevision != contentRevision {
            context.coordinator.hostingController?.rootView = content
            context.coordinator.contentRevision = contentRevision
        }

        if context.coordinator.contentSize != contentSize {
            context.coordinator.hostingController?.view.frame = CGRect(origin: .zero, size: contentSize)
            scrollView.contentSize = contentSize
            context.coordinator.contentSize = contentSize
        }

        if let scrollTarget {
            let clampedTarget = CGPoint(
                x: min(max(0, scrollTarget.x), max(0, contentSize.width - scrollView.bounds.width)),
                y: min(max(0, scrollTarget.y), max(0, contentSize.height - scrollView.bounds.height))
            )

            if abs(scrollView.contentOffset.x - clampedTarget.x) > 0.5 ||
                abs(scrollView.contentOffset.y - clampedTarget.y) > 0.5 {
                scrollView.setContentOffset(clampedTarget, animated: scrollTargetAnimated)
            }

            DispatchQueue.main.async {
                self.contentOffset = clampedTarget
                self.scrollTarget = nil
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        var contentRevision: String = ""
        var contentSize: CGSize = .zero
        var contentOffset: Binding<CGPoint>
        var scrollTarget: Binding<CGPoint?>
        private var lastPublishedOffset: CGPoint = .zero
        private var lastPublishTime: CFTimeInterval = 0

        init(contentOffset: Binding<CGPoint>, scrollTarget: Binding<CGPoint?>) {
            self.contentOffset = contentOffset
            self.scrollTarget = scrollTarget
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let now = CACurrentMediaTime()
            let offset = scrollView.contentOffset
            let movedEnough = abs(offset.x - lastPublishedOffset.x) > 4 || abs(offset.y - lastPublishedOffset.y) > 4
            let enoughTimePassed = now - lastPublishTime > 1.0 / 15.0

            guard movedEnough && enoughTimePassed else { return }

            lastPublishedOffset = offset
            lastPublishTime = now
            contentOffset.wrappedValue = offset
        }
    }
}

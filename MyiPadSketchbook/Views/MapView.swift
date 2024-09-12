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
    @State private var isRearranging: Bool = false
    @State private var isSharePresented: Bool = false
    @GestureState private var dragGestureState: CGSize = .zero
    
    // MARK: - Constants
    private let spacing: CGFloat = 10
    private let panDebouncer = Debouncer(delay: 0.001)
    
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
        colorScheme == .dark ? Color.black : Color.white
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)

                thumbnailsView(in: geometry)
                toolbarView
            }
            .gesture(panGesture)
            .sheet(isPresented: $isSharePresented) {
                if let (url, filename) = prepareImageForSharing() {
                    ActivityViewController(activityItems: [url], applicationActivities: nil, filename: filename)
                }
            }
        }
        .onAppear(perform: centerOnCurrentPage)
    }

    // MARK: - Subviews
    private func thumbnailsView(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(pages) { page in
                thumbnailView(for: page, in: geometry)
            }
        }
        .offset(x: panOffset.width + dragGestureState.width,
                y: panOffset.height + dragGestureState.height)
    }

    private var toolbarView: some View {
        VStack {
            HStack {
                Spacer()
                HStack {
                    rearrangeButton
                    exportButton
                    closeButton
                }
            }
            .padding(.top, -22)
            Spacer()
        }
    }

    private var rearrangeButton: some View {
        Button(action: { isRearranging.toggle() }) {
            Image(systemName: isRearranging ? "checkmark.circle" : "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: isRearranging ? toolbarButtonSize * 1.25 : toolbarButtonSize))
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .foregroundColor(isRearranging ? Color.blue : Color.primary)
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 32, leading: 0, bottom: 0, trailing: 5))
    }

    private var exportButton: some View {
        Button(action: { isSharePresented = true }) {
            Image(systemName: "square.and.arrow.up.on.square")
                .offset(y: -3)
                .font(.system(size: toolbarButtonSize))
                .symbolRenderingMode(.hierarchical)
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .foregroundColor(Color.primary)
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 32, leading: 0, bottom: 0, trailing: 5))
    }

    private var closeButton: some View {
        Button(action: onCloseMap) {
            Image(systemName: "square.on.square")
                .font(.system(size: toolbarButtonSize * 1.5, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .frame(width: toolbarButtonSize, height: toolbarButtonSize)
                .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .padding(EdgeInsets(top: 32, leading: 0, bottom: 0, trailing: 20.5))
    }

    // MARK: - Thumbnail View
    private func thumbnailView(for page: Page, in geometry: GeometryProxy) -> some View {
        let isSelected = draggedPage?.id == page.id
        let appearance = thumbnailAppearance(for: page, isSelected: isSelected)
        let overlappingPages = getOverlappingPages(for: page)
        let hasOverlap = overlappingPages.count > 1

        return ZStack {
            ThumbnailContent(page: page, thumbnailSize: thumbnailSize, colorScheme: colorScheme)
                .overlay(thumbnailBorder(appearance: appearance))
                .background(appearance.backgroundColor)
                .scaleEffect(appearance.scale)
                .opacity(appearance.opacity)
                .shadow(
                    color: isSelected && isRearranging ? Color.black.opacity(0.1) : Color.clear,
                    radius: isSelected && isRearranging ? 12 : 0,
                    x: 0,
                    y: 0
                )
            
            if hasOverlap {
                overlapIndicator(count: overlappingPages.count)
            }
        }
        .position(thumbnailPosition(for: page, in: geometry))
        .offset(isSelected && isRearranging ? draggedPageOffset : .zero)
        .zIndex(isSelected && isRearranging ? 1 : 0)
        .gesture(dragGesture(for: page))
    }

    private func thumbnailAppearance(for page: Page, isSelected: Bool) -> ThumbnailAppearance {
        if isSelected && isRearranging {
            return .dragging(colorScheme: colorScheme)
        } else {
            return .normal(colorScheme: colorScheme)
        }
    }

    private func thumbnailBorder(appearance: ThumbnailAppearance) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .stroke(
                isRearranging ? .blue : appearance.borderColor,
                style: StrokeStyle(lineWidth: appearance.borderWidth, dash: isRearranging ? [5] : [])
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
            .updating($dragGestureState) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                self.panOffset = CGSize(
                    width: self.panOffset.width + value.translation.width,
                    height: self.panOffset.height + value.translation.height
                )
            }
    }

    private func dragGesture(for page: Page) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                panDebouncer.debounce {
                    handleDragChange(value, for: page)
                }
            }
            .onEnded { value in
                handleDragEnd(value, for: page)
            }
    }

    // MARK: - Gesture Handlers
    private func handleDragChange(_ value: DragGesture.Value, for page: Page) {
        if isRearranging {
            draggedPage = page
            draggedPageOffset = value.translation
        } else if value.translation != .zero {
            panOffset.width += value.translation.width
            panOffset.height += value.translation.height
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
    private func thumbnailPosition(for page: Page, in geometry: GeometryProxy) -> CGPoint {
        let x = CGFloat((page.positionX ?? 0) - pagePositions.minX) * (thumbnailSize.width + spacing)
        let y = CGFloat(pagePositions.maxY - (page.positionY ?? 0)) * (thumbnailSize.height + spacing)
        return CGPoint(x: x, y: y)
    }

    private func calculateGridMovement(_ translation: CGSize) -> (x: Int, y: Int) {
        let xMovement = Int(round(translation.width / (thumbnailSize.width + spacing)))
        let yMovement = -Int(round(translation.height / (thumbnailSize.height + spacing)))
        return (x: xMovement, y: yMovement)
    }

    private func isValidMove(to position: (x: Int, y: Int)) -> Bool {
        !pages.contains { $0.id != draggedPage?.id && $0.positionX == position.x && $0.positionY == position.y }
    }

    private func centerOnCurrentPage() {
        guard let currentPage = pageManager.getCurrentPage() else { return }
        let screenSize = UIScreen.main.bounds.size

        let currentPagePosition = CGPoint(
            x: CGFloat((currentPage.positionX ?? 0) - pagePositions.minX) * (thumbnailSize.width + spacing),
            y: CGFloat(pagePositions.maxY - (currentPage.positionY ?? 0)) * (thumbnailSize.height + spacing)
        )

        panOffset = CGSize(
            width: screenSize.width / 2 - currentPagePosition.x - thumbnailSize.width / 2,
            height: screenSize.height / 2 - currentPagePosition.y - thumbnailSize.height / 2
        )
    }
    
    private func getOverlappingPages(for page: Page) -> [Page] {
        pages.filter { $0.positionX == page.positionX && $0.positionY == page.positionY }
    }

    // MARK: - Image sharing methods
    private func generateFullScaleThumbnail(for page: Page) -> UIImage {
        guard let drawing = try? PKDrawing(data: page.drawingData!) else {
            return UIImage() // Return an empty image if drawing can't be loaded
        }
        
        let fullScaleThumbnailSize = pageManager.pageRect.size
        let cornerRadius: CGFloat = 15
        
        let renderer = UIGraphicsImageRenderer(size: fullScaleThumbnailSize)
        let thumbnailImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: fullScaleThumbnailSize)
            
            // Create rounded rectangle path
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()
            
            // Set background color based on color scheme
            let backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? .black : .white
            }
            context.cgContext.setFillColor(backgroundColor.cgColor)
            context.cgContext.fill(rect)
            
            // Draw the full-scale drawing
            let fullScaleImage = drawing.image(from: pageManager.pageRect, scale: 1.0)
            fullScaleImage.draw(in: rect)
            
            // Draw border
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(4)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()
            
            // Draw page coordinates
            let text = "\(page.positionX ?? 0), \(page.positionY ?? 0)"
            let scaleFactor = fullScaleThumbnailSize.width / thumbnailSize.width
            let fontSize = 5 * scaleFactor
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.label.withAlphaComponent(0.87)
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)
            
            let padding: CGFloat = 2 * scaleFactor
            let textRect = CGRect(
                x: (fullScaleThumbnailSize.width / 2) - textSize.width,
                y: fullScaleThumbnailSize.height - textSize.height - padding - (3 * scaleFactor) - 8,
                width: textSize.width + (padding * 2),
                height: textSize.height + (padding * 2)
            )
            
            let textBackgroundPath = UIBezierPath(roundedRect: textRect, cornerRadius: 2 * scaleFactor)
            UIColor.systemGray6.setFill()
            textBackgroundPath.fill()
            
            context.cgContext.setStrokeColor(UIColor.systemGray5.cgColor)
            context.cgContext.setLineWidth(2 * scaleFactor)
            textBackgroundPath.stroke()
            
            text.draw(in: textRect.insetBy(dx: padding, dy: padding), withAttributes: attributes)
        }
        
        return thumbnailImage
    }
    
    private func generateMapImage() -> UIImage {
        let pagePositions = self.pagePositions
        let horizontalPages = pagePositions.maxX - pagePositions.minX + 1
        let verticalPages = pagePositions.maxY - pagePositions.minY + 1
        
        let fullScaleThumbnailSize = pageManager.pageRect.size
        let spacing: CGFloat = 20 // Use the same spacing as in the live Map view
        let fullSize = CGSize(
            width: CGFloat(horizontalPages) * (fullScaleThumbnailSize.width + spacing) + spacing,
            height: CGFloat(verticalPages) * (fullScaleThumbnailSize.height + spacing) + spacing
        )
        
        let renderer = UIGraphicsImageRenderer(size: fullSize)
        
        return renderer.image { context in
            // Fill background
            if colorScheme == .dark {
                UIColor.black.setFill()
            } else {
                UIColor.white.setFill()
            }
            context.fill(CGRect(origin: .zero, size: fullSize))
            
            // Draw thumbnails
            for page in pages {
                let x = spacing + CGFloat((page.positionX ?? 0) - pagePositions.minX) * (fullScaleThumbnailSize.width + spacing)
                let y = spacing + CGFloat(pagePositions.maxY - (page.positionY ?? 0)) * (fullScaleThumbnailSize.height + spacing)
                
                let fullScaleThumbnail = generateFullScaleThumbnail(for: page)
                fullScaleThumbnail.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: fullScaleThumbnailSize))
            }
        }
    }
    
    private func getShareFileName() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        let dateString = dateFormatter.string(from: Date())
        
        let appDisplayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "GridNotes"
        
        return "\(appDisplayName)_\(dateString).jpg"
    }
    
    private func prepareImageForSharing() -> (URL, String)? {
        let image = generateMapImage()
        let filename = getShareFileName()
        
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let fileURL = tempDirectoryURL.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return (fileURL, filename)
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
}

// MARK: - ThumbnailContent
struct ThumbnailContent: View {
    let page: Page
    let thumbnailSize: CGSize
    let colorScheme: ColorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            thumbnailImage
            coordinateLabel
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
    }

    private var thumbnailImage: some View {
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
        .clipped()
    }

    private var coordinateLabel: some View {
        Text("\(page.positionX ?? 0), \(page.positionY ?? 0)")
            .font(.system(size: 10))
            .padding(2)
            .foregroundColor(Color.primary.opacity(0.87))
            .border(Color(.systemGray5), width: 0.5)
            .background(Color(.systemGray6))
            .cornerRadius(2)
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
            backgroundColor: colorScheme == .dark ? Color.black : Color.white,
            borderColor: colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray2),
            borderWidth: 1,
            scale: 1.0,
            opacity: 1.0
        )
    }

    static func dragging(colorScheme: ColorScheme) -> ThumbnailAppearance {
        ThumbnailAppearance(
            backgroundColor: colorScheme == .dark ? Color.black : Color.white,
            borderColor: .blue,
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

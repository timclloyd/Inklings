//
//  ContentView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-06.
//

import SwiftUI
import PencilKit
import SwiftData

// MARK: - Data Model
@Model
final class Page {
    var id: UUID
    var drawingData: Data
    var positionX: Int
    var positionY: Int
    var thumbnailData: Data?
    
    init(id: UUID = UUID(), drawing: PKDrawing = PKDrawing(), position: (x: Int, y: Int)) {
        self.id = id
        self.drawingData = drawing.dataRepresentation()
        self.positionX = position.x
        self.positionY = position.y
    }
}

// MARK: - Page Manager
@MainActor
class PageManager: ObservableObject {
    @Published var currentPageID: UUID?
    @Published var pages: [Page] = []
    let pageRect: CGRect
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let screenSize = UIScreen.main.bounds.size
        self.pageRect = CGRect(origin: .zero, size: screenSize)
        
        let descriptor = FetchDescriptor<Page>()
        self.pages = (try? modelContext.fetch(descriptor)) ?? []
        
        // Load saved position
        let savedX = UserDefaults.standard.integer(forKey: "CurrentPageX")
        let savedY = UserDefaults.standard.integer(forKey: "CurrentPageY")
        
        if let savedPage = pages.first(where: { $0.positionX == savedX && $0.positionY == savedY }) {
            currentPageID = savedPage.id
        } else if let firstPage = pages.first {
            currentPageID = firstPage.id
        } else {
            let initialPage = createPage(position: (0, 0))
            currentPageID = initialPage.id
        }
    }
    
    func createPage(position: (x: Int, y: Int)) -> Page {
        let newPage = Page(position: position)
        modelContext.insert(newPage)
        pages.append(newPage)
        return newPage
    }
    
    func setCurrentPage(_ page: Page) {
        currentPageID = page.id
        // Save current page position
        UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
        UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
    }
    
    func addPage(translation: CGSize) {
        guard let currentPage = getCurrentPage() else { return }
        
        var newPosition = (x: currentPage.positionX, y: currentPage.positionY)
        
        if abs(translation.width) > abs(translation.height) {
            // Horizontal movement
            newPosition.x += translation.width > 0 ? -1 : 1
        } else {
            // Vertical movement
            newPosition.y += translation.height < 0 ? -1 : 1
        }
        
        let existingPage = pages.first { $0.positionX == newPosition.x && $0.positionY == newPosition.y }
        
        if let existingPage = existingPage {
            setCurrentPage(existingPage)
        } else {
            let newPage = createPage(position: newPosition)
            setCurrentPage(newPage)
        }
    }
    
    func getCurrentPage() -> Page? {
        guard let currentPageID = currentPageID else { return nil }
        return pages.first { $0.id == currentPageID }
    }
    
    func updateDrawing(_ drawing: PKDrawing) {
        guard let currentPage = getCurrentPage() else { return }
        currentPage.drawingData = drawing.dataRepresentation()
        updateThumbnail(for: currentPage)
    }
    
    func updateThumbnail(for page: Page) {
        guard let drawing = try? PKDrawing(data: page.drawingData) else { return }
        let thumbnail = drawing.image(from: pageRect, scale: 1)
        let aspectRatio = pageRect.size.width / pageRect.size.height
        let thumbnailSize = CGSize(width: 120, height: 120 / aspectRatio)
        
        let thumbnailImage = UIGraphicsImageRenderer(size: thumbnailSize).image { context in
            thumbnail.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
        
        page.thumbnailData = thumbnailImage.pngData()
    }
    
    func updateAllThumbnails() {
        for page in pages {
            updateThumbnail(for: page)
        }
    }
    
    func updatePagePosition(_ page: Page) {
        objectWillChange.send()
        try? modelContext.save()
        // Update saved position if this is the current page
        if page.id == currentPageID {
            UserDefaults.standard.set(page.positionX, forKey: "CurrentPageX")
            UserDefaults.standard.set(page.positionY, forKey: "CurrentPageY")
        }
    }
}

extension PageManager {
    func movePage(_ page: Page, to newPosition: (x: Int, y: Int)) {
        page.positionX = newPosition.x
        page.positionY = newPosition.y
        try? modelContext.save()
    }
}

// MARK: - Views
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

enum EdgeDirection: Equatable {
    case left, right, top, bottom
}

enum DragState: Equatable {
    case inactive
    case dragging(translation: CGSize)
}

struct DottedBackgroundView: View {
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
    
    var dotColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var largeDotColor: Color {
        colorScheme == .dark ? .blue : .blue
    }
    
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
                animationProgress = swipeProgress.progress
                animationDirection = swipeProgress.direction
            case .dragging(let translation):
                animationProgress = min(1.0, max(abs(translation.width), abs(translation.height)) / (size.width / 4))
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

// Helper extension for color interpolation
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [Page]
    @StateObject private var pageManager: PageManager
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var showMiniMap = false
    @GestureState private var magnifyBy = CGFloat(1.0)
    @State private var swipeProgress = SwipeProgress(direction: nil, progress: 0)
    @GestureState private var dragState = DragState.inactive
    
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    var body: some View {
        ZStack {
            if !showMiniMap {
                DottedBackgroundView(pageRect: pageManager.pageRect, adjacentPages: getAdjacentPages(), swipeProgress: swipeProgress, dragState: dragState)
                    .ignoresSafeArea()

                PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.getCurrentPage()?.drawingData ?? Data(), onDrawingChange: pageManager.updateDrawing, pageRect: pageManager.pageRect, onSwipe: handleSwipe)
                    .ignoresSafeArea()
                
                VStack { // Show page coordinates for debugging
                    Spacer()
                    if let currentPage = pageManager.getCurrentPage() {
                        Text("Page \(currentPage.positionX), \(currentPage.positionY)")
                            .padding()
                            .background(Color(UIColor.systemBackground).opacity(0.7))
                            .cornerRadius(10)
                    }
                }
            } else {
                MiniMapView(pageManager: pageManager, pages: pages, onPageSelected: { selectedPage in
                    pageManager.setCurrentPage(selectedPage)
                    if let drawing = try? PKDrawing(data: selectedPage.drawingData) {
                        canvasView.drawing = drawing
                    }
                    showMiniMap = false
                }, showMiniMap: $showMiniMap)
            }
        }
        .gesture(makeMagnificationGesture())
    }
    
    private func makeMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                if !showMiniMap && value < 0.8 {
                    pageManager.updateAllThumbnails()
                    showMiniMap = true
                } else if showMiniMap && value > 1.2 {
                    showMiniMap = false
                }
            }
    }
    
    private func updateSwipeProgress(for gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let progress = min(1.0, max(abs(translation.x), abs(translation.y)) / (UIScreen.main.bounds.width / 4))
        
        let direction: EdgeDirection
        if abs(translation.x) > abs(translation.y) {
            direction = translation.x > 0 ? .left : .right
        } else {
            direction = translation.y > 0 ? .top : .bottom
        }
        
        swipeProgress = SwipeProgress(direction: direction, progress: progress)
    }
    
    private func handleSwipe(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let progress = min(1.0, max(abs(translation.x), abs(translation.y)) / (UIScreen.main.bounds.width / 4))
        
        let direction: EdgeDirection
        if abs(translation.x) > abs(translation.y) {
            direction = translation.x > 0 ? .left : .right
        } else {
            direction = translation.y > 0 ? .top : .bottom
        }
        
        switch gesture.state {
        case .changed:
            swipeProgress = SwipeProgress(direction: direction, progress: progress)
        case .ended:
            if progress >= 1.0 {
                pageManager.addPage(translation: CGSize(width: translation.x, height: translation.y))
                if let currentPage = pageManager.getCurrentPage(),
                   let drawing = try? PKDrawing(data: currentPage.drawingData) {
                    canvasView.drawing = drawing
                }
            }
            // Always reset the swipe progress when the gesture ends
            withAnimation(.linear(duration: 0.2)) {
                swipeProgress = SwipeProgress(direction: nil, progress: 0)
            }
        default:
            break
        }
    }
    
    private func getAdjacentPages() -> AdjacentPages {
        guard let currentPage = pageManager.getCurrentPage() else {
            return AdjacentPages(left: false, right: false, top: false, bottom: false)
        }
        
        return AdjacentPages(
            left: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX - 1 && $0.positionY == currentPage.positionY }),
            right: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX + 1 && $0.positionY == currentPage.positionY }),
            top: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == currentPage.positionY + 1 }),
            bottom: pageManager.pages.contains(where: { $0.positionX == currentPage.positionX && $0.positionY == currentPage.positionY - 1 })
        )
    }
}

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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if self.isRearranging {
                            self.draggedPage = page
                            self.draggedPageOffset = value.translation
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
                        }
                    }
            )
            .onTapGesture {
                if !self.isRearranging {
                    self.onPageSelected(page)
                    self.showMiniMap = false
                }
            }
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

struct PencilKitView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var drawing: Data
    var onDrawingChange: (PKDrawing) -> Void
    var pageRect: CGRect
    var onSwipe: (UIPanGestureRecognizer) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawing = try! PKDrawing(data: drawing)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.contentSize = pageRect.size
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        canvasView.zoomScale = 1

        // Set drawing policy to pencil only
        canvasView.drawingPolicy = .pencilOnly

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        canvasView.addGestureRecognizer(panGesture)

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let pkDrawing = try? PKDrawing(data: drawing), uiView.drawing != pkDrawing {
            uiView.drawing = pkDrawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitView

        init(_ parent: PencilKitView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChange(canvasView.drawing)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            parent.onSwipe(gesture)
        }
    }
}

// MARK: - App Entry Point
@main
struct MyiPadSketchbookApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Page.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: sharedModelContainer.mainContext)
        }
        .modelContainer(sharedModelContainer)
    }
}

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
    var isSelected: Bool
    
    init(id: UUID = UUID(), drawing: PKDrawing = PKDrawing(), position: (x: Int, y: Int), isSelected: Bool = false) {
        self.id = id
        self.drawingData = drawing.dataRepresentation()
        self.positionX = position.x
        self.positionY = position.y
        self.isSelected = isSelected
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
        
        if let selectedPage = pages.first(where: { $0.isSelected }) {
            currentPageID = selectedPage.id
        } else if let firstPage = pages.first {
            currentPageID = firstPage.id
            firstPage.isSelected = true
        } else {
            let initialPage = createPage(position: (0, 0))
            currentPageID = initialPage.id
            initialPage.isSelected = true
        }
    }
    
    func createPage(position: (x: Int, y: Int)) -> Page {
        let newPage = Page(position: position)
        modelContext.insert(newPage)
        pages.append(newPage)
        return newPage
    }
    
    func addPage(direction: DragGesture.Value) {
            guard let currentPage = getCurrentPage() else { return }
            
            var newPosition = (x: currentPage.positionX, y: currentPage.positionY)
            
            if abs(direction.translation.width) > abs(direction.translation.height) {
                // Horizontal movement
                newPosition.x += direction.translation.width > 0 ? -1 : 1
            } else {
                // Vertical movement
                newPosition.y += direction.translation.height < 0 ? -1 : 1
            }
            
            let existingPage = pages.first { $0.positionX == newPosition.x && $0.positionY == newPosition.y }
            
            if let existingPage = existingPage {
                setCurrentPage(existingPage)
            } else {
                let newPage = createPage(position: newPosition)
                setCurrentPage(newPage)
            }
        }
    
    func setCurrentPage(_ page: Page) {
        if let currentPage = getCurrentPage() {
            currentPage.isSelected = false
        }
        page.isSelected = true
        currentPageID = page.id
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
        let descriptor = FetchDescriptor<Page>()
        if let pages = try? modelContext.fetch(descriptor) {
            for page in pages {
                updateThumbnail(for: page)
            }
        }
    }
    
    func getCurrentPage() -> Page? {
        guard let currentPageID = currentPageID else { return nil }
        let descriptor = FetchDescriptor<Page>(predicate: #Predicate {
            $0.id == currentPageID
        })
        return try? modelContext.fetch(descriptor).first
    }
    
    func deleteAllPages() {
        let descriptor = FetchDescriptor<Page>()
        if let pages = try? modelContext.fetch(descriptor) {
            for page in pages {
                modelContext.delete(page)
            }
        }
        self.pages.removeAll()
        
        // Create a new initial page
        let initialPage = createPage(position: (0, 0))
        currentPageID = initialPage.id
        initialPage.isSelected = true
    }
}

// MARK: - Views
struct DottedBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    let pageRect: CGRect
    let dotSize: CGFloat = 2
    let dotOpacity: CGFloat = 0.2
    let targetSpacing: CGFloat = 28 // Target spacing between dots
    
    var body: some View {
        Canvas { context, size in
            let dotColor = (colorScheme == .dark ? Color.white : Color.black).opacity(dotOpacity)
            
            // Calculate the number of spaces (gaps between dots, including edges)
            let horizontalSpaces = max(2, Int((size.width / targetSpacing).rounded()))
            let verticalSpaces = max(2, Int((size.height / targetSpacing).rounded()))
            
            // Calculate actual spacing to fit the size perfectly
            let horizontalSpacing = size.width / CGFloat(horizontalSpaces)
            let verticalSpacing = size.height / CGFloat(verticalSpaces)
            
            // Number of dots is one less than the number of spaces
            let horizontalDots = horizontalSpaces - 1
            let verticalDots = verticalSpaces - 1
            
            for x in 0..<horizontalDots {
                for y in 0..<verticalDots {
                    let dotRect = CGRect(
                        x: CGFloat(x + 1) * horizontalSpacing - dotSize/2,
                        y: CGFloat(y + 1) * verticalSpacing - dotSize/2,
                        width: dotSize,
                        height: dotSize
                    )
                    let dotPath = Path(ellipseIn: dotRect)
                    context.fill(dotPath, with: .color(dotColor))
                }
            }
        }
        .frame(width: pageRect.width, height: pageRect.height)
        .background(colorScheme == .dark ? Color.black : Color.white)
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
    
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    var body: some View {
        ZStack {
            if !showMiniMap {
                DottedBackgroundView(pageRect: pageManager.pageRect)
                    .ignoresSafeArea()
                
                PencilKitView(canvasView: $canvasView, toolPicker: $toolPicker, drawing: pageManager.getCurrentPage()?.drawingData ?? Data(), onDrawingChange: pageManager.updateDrawing, pageRect: pageManager.pageRect)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .updating($magnifyBy) { currentState, gestureState, transaction in
                                gestureState = currentState
                            }
                            .onEnded { value in
                                if value < 0.8 {
                                    pageManager.updateAllThumbnails()
                                    showMiniMap = true
                                }
                            }
                    )
            
                VStack {
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
                .gesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { currentState, gestureState, transaction in
                            gestureState = currentState
                        }
                        .onEnded { value in
                            if value > 1.2 {
                                showMiniMap = false
                            }
                        }
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if max(abs(value.translation.width), abs(value.translation.height)) > UIScreen.main.bounds.width / 4 {
                        pageManager.addPage(direction: value)
                        if let currentPage = pageManager.getCurrentPage(),
                           let drawing = try? PKDrawing(data: currentPage.drawingData) {
                            canvasView.drawing = drawing
                        }
                    }
                }
        )
    }
}

struct MiniMapView: View {
    @ObservedObject var pageManager: PageManager
    let pages: [Page]
    @Environment(\.colorScheme) var colorScheme
    var onPageSelected: (Page) -> Void
    @State private var showingDeleteConfirmation = false
    @Binding var showMiniMap: Bool
    @State private var panOffset: CGSize = .zero
    @State private var initialOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

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
                    .contentShape(Rectangle())  // This makes the entire background interactive
                
                ZStack {
                    ForEach(pages) { page in
                        thumbnailView(for: page)
                            .position(thumbnailPosition(for: page, in: geometry))
                    }
                }
                .offset(x: panOffset.width + dragOffset.width, y: panOffset.height + dragOffset.height)
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        panOffset.width += value.translation.width
                        panOffset.height += value.translation.height
                    }
            )
            .overlay(
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Text("Delete All Pages")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(),
                alignment: .topTrailing
            )
        }
        .alert("Delete All Pages", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                pageManager.deleteAllPages()
                showMiniMap = false
            }
        } message: {
            Text("Delete all pages? This cannot be undone.")
        }
        .onAppear {
            centerOnCurrentPage()
        }
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
        
        initialOffset = panOffset
    }

    private func thumbnailView(for page: Page) -> some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(page.isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onPageSelected(page)
        }
    }
}

struct PencilKitView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var drawing: Data
    var onDrawingChange: (PKDrawing) -> Void
    var pageRect: CGRect
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.delegate = context.coordinator
        
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        if let pkDrawing = try? PKDrawing(data: drawing) {
            canvasView.drawing = pkDrawing
        }
        canvasView.contentSize = pageRect.size
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1  // Disable zooming
        canvasView.zoomScale = 1
        
        // Disable the built-in gestures
        canvasView.isScrollEnabled = false
        for gesture in canvasView.gestureRecognizers ?? [] {
            gesture.isEnabled = false
        }
        
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

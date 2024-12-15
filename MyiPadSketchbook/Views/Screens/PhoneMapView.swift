//
//  PhoneMapView.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-12-15.
//


import SwiftUI
import SwiftData

struct PhoneMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pages: [Page]
    @StateObject private var pageManager: PageManager
    @State private var zoomScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1.0
    
    init(modelContext: ModelContext) {
        _pageManager = StateObject(wrappedValue: PageManager(modelContext: modelContext))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        ForEach(pages) { page in
                            thumbnailView(for: page)
                        }
                    }
                    .frame(width: contentWidth * zoomScale, 
                           height: contentHeight * zoomScale)
                }
                .gesture(SimultaneousGesture(
                    dragGesture,
                    magnificationGesture
                ))
            }
        }
    }
    
    private var contentWidth: CGFloat {
        let pageRect = pageManager.pageRect
        let positions = pages.map { $0.positionX ?? 0 }
        let minX = CGFloat(positions.min() ?? 0)
        let maxX = CGFloat(positions.max() ?? 0)
        return (maxX - minX + 3) * (pageRect.width + 6)
    }
    
    private var contentHeight: CGFloat {
        let pageRect = pageManager.pageRect
        let positions = pages.map { $0.positionY ?? 0 }
        let minY = CGFloat(positions.min() ?? 0)
        let maxY = CGFloat(positions.max() ?? 0)
        return (maxY - minY + 3) * (pageRect.height + 6)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { _ in
                dragOffset = .zero
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureZoom) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                zoomScale = min(max(zoomScale * value, 0.5), 3.0)
            }
    }
    
    private func thumbnailView(for page: Page) -> some View {
        let aspectRatio = pageManager.pageRect.width / pageManager.pageRect.height
        let thumbnailWidth: CGFloat = 120
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailWidth / aspectRatio)
        
        return ZStack(alignment: .bottom) {
            if let thumbnailData = page.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
            
            Text("\(page.positionX ?? 0), \(page.positionY ?? 0)")
                .font(.system(size: 10))
                .padding(2)
                .padding(.horizontal, 3)
                .foregroundColor(Color.primary.opacity(0.87))
                .background(Color(.systemGray5))
                .cornerRadius(5)
                .padding(.bottom, 3)
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .position(thumbnailPosition(for: page, size: thumbnailSize))
        .scaleEffect(gestureZoom)
    }
    
    private func thumbnailPosition(for page: Page, size: CGSize) -> CGPoint {
        let spacing: CGFloat = 6
        let x = CGFloat((page.positionX ?? 0)) * (size.width + spacing) + size.width / 2 + spacing
        let y = CGFloat((page.positionY ?? 0)) * (size.height + spacing) + size.height / 2 + spacing
        return CGPoint(x: x, y: y)
    }
}

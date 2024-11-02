//
//  ShareButton.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-11-02.
//

import Foundation
import SwiftUI
import PencilKit
import UIKit

// MARK: - ShareButton
struct ShareButton: View {
    @StateObject private var exportManager: ExportManager
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @Environment(\.colorScheme) private var colorScheme
    
    init(pageManager: PageManager) {
        _exportManager = StateObject(wrappedValue: ExportManager(pageManager: pageManager, colorScheme: .light))
    }
    
    var body: some View {
        Button(action: startExport) {
            if exportManager.isExporting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: toolbarButtonSize * 1.15, weight: .light))
                    .padding(9) // Expand tappable area
                    .background(
                        Circle()
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.white))
                    )
            }
        }
        .buttonStyle(ToolbarButtonStyle(isEnabled: true))
        .disabled(exportManager.isExporting)
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL = exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .padding(EdgeInsets(top: -14, leading: 8, bottom: 10, trailing: 7))
    }
    
    private func startExport() {
        Task {
            do {
                exportURL = try await exportManager.exportPages()
                showingShareSheet = true
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        controller.completionWithItemsHandler = { _, _, _, _ in
            // Clean up temp files after sharing
            if let url = items.first as? URL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

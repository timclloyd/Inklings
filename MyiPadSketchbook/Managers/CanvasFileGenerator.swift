//
//  CanvasFileGenerator.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-11-02.
//

import Foundation
import SwiftUI
import PencilKit
import UIKit

struct CanvasNode: Codable {
    let id: String
    let type: String
    let file: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    
    init(id: String, file: String, x: Int, y: Int) {
        self.id = id
        self.type = "file"
        self.file = file
        self.x = x
        self.y = y
        self.width = 279
        self.height = 399
    }
}

struct CanvasFile: Codable {
    let nodes: [CanvasNode]
    let edges: [String]
    
    init(nodes: [CanvasNode]) {
        self.nodes = nodes
        self.edges = []
    }
}

class CanvasFileGenerator {
    private let nodeSpacing = 279
    private let verticalSpacing = 400
    private let baseX = -180
    private let baseY = -200
    
    func generateCanvasFile(pages: [Page], appName: String) throws -> String {
        let nodes = pages.map { page -> CanvasNode in
            let pageX = page.positionX ?? 0
            let pageY = page.positionY ?? 0
            
            return CanvasNode(
                id: generateRandomId(),
                file: "\(appName)/\(pageX),\(pageY).jpeg",
                x: baseX + (pageX * nodeSpacing),
                y: baseY - (pageY * verticalSpacing)
            )
        }
        
        let canvasFile = CanvasFile(nodes: nodes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        let jsonData = try encoder.encode(canvasFile)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func generateRandomId() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<16).map { _ in characters.randomElement()! })
    }
}

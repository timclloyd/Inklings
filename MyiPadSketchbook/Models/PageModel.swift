//
//  Models.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-08-18.
//

import Foundation
import SwiftUI
import PencilKit
import SwiftData

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

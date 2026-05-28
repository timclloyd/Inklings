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
final class Notebook {
    var id: UUID?
    var createdAt: Date?
    var name: String?
    var lastSelectedPageID: UUID?
    var deletedAt: Date?

    init(id: UUID = UUID(), createdAt: Date = Date(), name: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.lastSelectedPageID = nil
        self.deletedAt = nil
    }
}

@Model
final class Page {
    static let legacyIPadPro11PageSize = CGSize(width: 834, height: 1194)

    var id: UUID?
    var drawingData: Data?
    var positionX: Int?
    var positionY: Int?
    var thumbnailData: Data?
    var pageWidth: Double?
    var pageHeight: Double?
    var notebookID: UUID?
    
    init(id: UUID = UUID(), drawingData: Data = PKDrawing().dataRepresentation(), positionX: Int = 0, positionY: Int = 0, pageSize: CGSize = Page.legacyIPadPro11PageSize, notebookID: UUID? = nil) {
        self.id = id
        self.drawingData = drawingData
        self.positionX = positionX
        self.positionY = positionY
        self.pageWidth = pageSize.width
        self.pageHeight = pageSize.height
        self.notebookID = notebookID
    }

    var pageSize: CGSize {
        CGSize(
            width: pageWidth ?? Page.legacyIPadPro11PageSize.width,
            height: pageHeight ?? Page.legacyIPadPro11PageSize.height
        )
    }

    func setPageSize(_ size: CGSize) {
        pageWidth = size.width
        pageHeight = size.height
    }
}

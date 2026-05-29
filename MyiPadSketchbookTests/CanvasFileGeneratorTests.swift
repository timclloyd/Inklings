//
//  CanvasFileGeneratorTests.swift
//  MyiPadSketchbookTests
//
//  Created by Tim Lloyd on 2024-08-06.
//

import Foundation
import XCTest
@testable import MyiPadSketchbook

final class CanvasFileGeneratorTests: XCTestCase {
    func testCanvasFileGeneratorProducesCoordinateBasedNodes() throws {
        let pages = [
            Page(positionX: 0, positionY: 0),
            Page(positionX: 2, positionY: -1),
            Page(positionX: -1, positionY: 3)
        ]
        let json = try CanvasFileGenerator().generateCanvasFile(pages: pages, appName: "Inklings")
        let canvasFile = try JSONDecoder().decode(CanvasFile.self, from: Data(json.utf8))

        XCTAssertEqual(canvasFile.edges, [])
        XCTAssertEqual(canvasFile.nodes.count, 3)

        let originNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/0,0.jpeg" })
        XCTAssertEqual(originNode.type, "file")
        XCTAssertEqual(originNode.x, -180)
        XCTAssertEqual(originNode.y, -200)
        XCTAssertEqual(originNode.width, 279)
        XCTAssertEqual(originNode.height, 399)

        let positiveXNegativeYNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/2,-1.jpeg" })
        XCTAssertEqual(positiveXNegativeYNode.x, 378)
        XCTAssertEqual(positiveXNegativeYNode.y, 200)

        let negativeXPositiveYNode = try XCTUnwrap(canvasFile.nodes.first { $0.file == "Inklings/-1,3.jpeg" })
        XCTAssertEqual(negativeXPositiveYNode.x, -459)
        XCTAssertEqual(negativeXPositiveYNode.y, -1400)
    }
}

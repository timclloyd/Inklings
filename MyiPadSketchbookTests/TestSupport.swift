//
//  TestSupport.swift
//  MyiPadSketchbookTests
//
//  Created by Tim Lloyd on 2024-08-06.
//

import SwiftData
import XCTest
@testable import MyiPadSketchbook

@MainActor
class SketchbookTestCase: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        clearPersistentSelection()
        container = try makeModelContainer()
    }

    override func tearDownWithError() throws {
        clearPersistentSelection()
        container = nil
        try super.tearDownWithError()
    }

    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Notebook.self,
            Page.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func clearPersistentSelection() {
        UserDefaults.standard.removeObject(forKey: "CurrentNotebookID")
        UserDefaults.standard.removeObject(forKey: "CurrentPageX")
        UserDefaults.standard.removeObject(forKey: "CurrentPageY")
    }
}

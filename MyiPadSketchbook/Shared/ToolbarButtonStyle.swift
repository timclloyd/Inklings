//
//  Styles.swift
//  MyiPadSketchbook
//
//  Created by Tim Lloyd on 2024-09-11.
//

import Foundation
import SwiftUI

let toolbarButtonSize: CGFloat = 20

struct ToolbarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isEnabled ? .primary.opacity(configuration.isPressed ? 0.57 : 0.87) : .primary.opacity(0.2)
            )
    }
}

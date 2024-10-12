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
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                (color ?? .primary).opacity(
                    isEnabled
                        ? (configuration.isPressed ? 0.57 : 0.87) // Enabled
                        : 0.2 // Disabled
                )
            )
            .animation(.easeInOut, value: isEnabled)
    }
}

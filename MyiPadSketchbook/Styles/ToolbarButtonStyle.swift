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
    var highlightBackground: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                (color ?? .primary).opacity(
                    isEnabled
                    ? (configuration.isPressed ? 0.57 : 1.5) // Enabled
                    : highlightBackground ? 0.87 : 0.3 // Disabled
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(highlightBackground && isEnabled
                          ? Color(UIColor.systemGray5)
                        : Color(UIColor.systemBackground))
                    .padding(1)
            )
            .animation(.easeInOut, value: isEnabled)
    }
}

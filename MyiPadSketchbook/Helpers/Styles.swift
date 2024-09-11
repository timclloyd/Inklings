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
            .background(Circle().fill((colorScheme == .dark ? Color.black : Color.white)))
            .foregroundColor(isEnabled ? .primary.opacity(0.87) : .primary.opacity(0.2))
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

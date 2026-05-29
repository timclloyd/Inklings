//
//  AppTheme.swift
//  MyiPadSketchbook
//

import SwiftUI
import UIKit

enum AppTheme {
    enum Surface {
        static func pageSwiftUIColor(for colorScheme: ColorScheme) -> Color {
            Color(pageUIKitColor(for: colorScheme))
        }

        static func pageUIKitColor(for colorScheme: ColorScheme) -> UIColor {
            pageUIKitColor(isDark: colorScheme == .dark)
        }

        // SwiftUI views use Color; thumbnail rendering and UIKit/CoreGraphics paths use UIColor.
        static func pageUIKitColor(for userInterfaceStyle: UIUserInterfaceStyle) -> UIColor {
            pageUIKitColor(isDark: userInterfaceStyle == .dark)
        }

        private static func pageUIKitColor(isDark: Bool) -> UIColor {
            isDark ? .systemGray6 : .white
        }
    }
}

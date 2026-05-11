import SwiftUI

enum UB {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 10
        static let window: CGFloat = 11
        static let tile: CGFloat = 6
        static let bar: CGFloat = 5
        static let control: CGFloat = 5
        static let pill: CGFloat = 999
    }

    enum Font {
        static let cardTitle = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let popoverTitle = SwiftUI.Font.system(size: 13.5, weight: .semibold)
        static let paneTitle = SwiftUI.Font.system(size: 19, weight: .bold)
        static let paneSubtitle = SwiftUI.Font.system(size: 12)
        static let detailTitle = SwiftUI.Font.system(size: 15, weight: .bold)
        static let formLabel = SwiftUI.Font.system(size: 12.5)
        static let countdown = SwiftUI.Font.system(size: 11, design: .default)
            .monospacedDigit()
        static let summaryBig = SwiftUI.Font.system(size: 18, weight: .bold)
            .monospacedDigit()
    }

    enum Canvas {
        static let popoverBackground = Color(nsColor: .windowBackgroundColor)
        static let canvasBackground = Color(red: 0.961, green: 0.961, blue: 0.969)
        static let cardBackground = Color(nsColor: .textBackgroundColor)
        static let separator = Color(nsColor: .separatorColor)
    }
}

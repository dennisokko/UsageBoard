import SwiftUI

struct PlanTag: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(foreground)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(background)
            )
    }

    private var palette: (bg: Color, fg: Color) {
        switch text.uppercased() {
        case "PRO":
            return (Color.blue.opacity(0.16), Color.blue)
        case "PLUS":
            return (Color.teal.opacity(0.16), Color.teal)
        case "TEAM":
            return (Color.purple.opacity(0.18), Color.purple)
        case "FREE":
            return (Color.gray.opacity(0.18), Color.gray)
        case "MAX", "MAX 5X", "MAX 20X":
            return (Color.orange.opacity(0.18), Color.orange)
        default:
            return (Color.gray.opacity(0.16), Color.secondary)
        }
    }

    private var background: Color { palette.bg }
    private var foreground: Color { palette.fg }
}

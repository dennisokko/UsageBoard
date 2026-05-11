import SwiftUI

struct AppIconSquircle: View {
    var size: CGFloat = 22

    var body: some View {
        let radius = size * 0.2237
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.353, green: 0.784, blue: 0.980),
                        Color(red: 0.039, green: 0.518, blue: 1.000),
                        Color(red: 0.369, green: 0.361, blue: 0.902),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                ))
            bars
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.10), radius: size * 0.04, y: size * 0.02)
    }

    private var bars: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let barW = w * 0.14
            let baseY = h * 0.82
            Path { path in
                path.move(to: CGPoint(x: w * 0.10, y: baseY))
                path.addLine(to: CGPoint(x: w * 0.90, y: baseY))
            }
            .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: max(1, h * 0.04), lineCap: .round))

            ForEach(Array([0.55, 0.78, 1.0, 0.65].enumerated()), id: \.offset) { idx, heightRatio in
                let x = w * (0.16 + Double(idx) * 0.20)
                let barH = h * 0.62 * heightRatio
                RoundedRectangle(cornerRadius: barW * 0.25, style: .continuous)
                    .fill(Color.white.opacity(0.55 + Double(idx) * 0.12))
                    .frame(width: barW, height: barH)
                    .position(x: x, y: baseY - barH / 2)
            }
        }
    }
}

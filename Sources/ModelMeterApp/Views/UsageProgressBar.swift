import SwiftUI

struct UsageProgressBar: View {
    let progress: Double
    let color: Color
    let trackColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
                    .animation(.easeOut(duration: 0.2), value: progress)
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

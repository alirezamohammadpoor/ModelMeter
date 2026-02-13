import SwiftUI

struct UsageProgressBar: View {
    let progress: Double
    let color: Color
    let trackColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ModelMeterLayout.progressRadius)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: ModelMeterLayout.progressRadius)
                    .fill(color)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
                    .animation(ModelMeterMotion.progressChange, value: progress)
            }
        }
        .frame(height: ModelMeterLayout.progressHeight)
        .clipShape(RoundedRectangle(cornerRadius: ModelMeterLayout.progressRadius))
    }
}

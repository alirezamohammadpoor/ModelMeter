import SwiftUI
import ModelMeterCore

struct MenuView: View {
    @Bindable var viewModel: MenuViewModel

    var body: some View {
        UsagePopoverView(viewModel: viewModel)
    }
}

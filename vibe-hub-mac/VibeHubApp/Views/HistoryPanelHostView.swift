import SwiftUI

struct HistoryPanelHostView: View {
    @StateObject private var viewModel = VibeHubViewModel()

    var body: some View {
        HistoryPanelView(entries: viewModel.historyEntries)
            .padding(18)
            .background(Color.clear)
    }
}

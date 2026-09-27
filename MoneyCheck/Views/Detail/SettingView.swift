import SwiftUI

public struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BudgetViewModel

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            SettingsHubView(viewModel: viewModel)
                .safeAreaInset(edge: .top, spacing: 0) {
                    DetailHeader(title: "환경 및 재정 설정") { dismiss() }
                }
        }
    }
}


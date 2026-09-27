import SwiftUI
import SwiftData

@main
struct MoneyCheckApp: App {
    private let modelContainer: ModelContainer
    @State private var viewModel: BudgetViewModel
    @StateObject private var themeManager: ThemeManager

    init() {
        do {
            let container = try ModelContainer(for:
                Transaction.self,
                MonthlyConfig.self,
                UserSettings.self,
                CategoryDefinition.self,
                SavingsAccount.self
            )
            modelContainer = container
            let initialViewModel = BudgetViewModel(modelContext: container.mainContext)
            _viewModel = State(initialValue: initialViewModel)
            _themeManager = StateObject(wrappedValue: ThemeManager(theme: initialViewModel.theme, fontName: initialViewModel.userSettings?.fontName ?? AppFontStyle.system.rawValue))
        } catch {
            fatalError("SwiftData 컨테이너를 생성할 수 없습니다: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .preferredColorScheme(viewModel.resolvedColorScheme)
                .font(viewModel.appFont)
                .environmentObject(themeManager)
        }
        .modelContainer(modelContainer)
    }
}

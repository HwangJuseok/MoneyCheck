import SwiftUI

public struct DashboardView: View {
    var viewModel: BudgetViewModel
    
    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let targetDate = viewModel.currentDate
        let totalExp = viewModel.totalExpense(for: targetDate)
        let totalInc = viewModel.totalIncome(for: targetDate)
        let monthlySum = viewModel.cumulativeMonthlySum(for: targetDate)
        let yearlySum = viewModel.yearlySum(for: targetDate)

        HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    dashboardRow(title: "수입", amount: totalInc)
                    dashboardRow(title: "지출", amount: totalExp)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 10) {
                    dashboardRow(title: "월간 합계", amount: monthlySum, alignRight: true)
                    dashboardRow(title: "연간 합계", amount: yearlySum, alignRight: true)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func dashboardRow(title: String, amount: Double, alignRight: Bool = false) -> some View {
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appSecondary)
            Text("\(Int(amount).formatted())원")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

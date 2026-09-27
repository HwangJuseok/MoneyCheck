import SwiftUI

public enum GraphPeriod: String, CaseIterable, Identifiable {
    case weekly = "주간"
    case monthly = "월간"
    case yearly = "년간"

    public var id: String { self.rawValue }
}

public struct GraphView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BudgetViewModel

    @State private var selectedPeriod: GraphPeriod = .monthly
    @State private var isIncomeMode: Bool = false

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    struct CategorySummary: Identifiable {
        let id = UUID()
        let category: CategoryType
        let amount: Double
        let percentage: Double
    }

    private var chartData: [CategorySummary] {
        let calendar = Calendar.current
        let targetDate = viewModel.currentDate

        let filtered: [Transaction]
        switch selectedPeriod {
        case .weekly:
            guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: targetDate) else { return [] }
            filtered = viewModel.transactions.filter {
                $0.date >= weekRange.start && $0.date < weekRange.end
            }
        case .monthly:
            filtered = viewModel.transactions.filter {
                calendar.isDate($0.date, equalTo: targetDate, toGranularity: .month)
            }
        case .yearly:
            filtered = viewModel.transactions.filter {
                calendar.isDate($0.date, equalTo: targetDate, toGranularity: .year)
            }
        }

        let typeFiltered = filtered.filter { transaction in
            if isIncomeMode {
                return transaction.type == .income
            } else {
                return transaction.type == .expense || transaction.type == .fixedExpense
            }
        }

        let grouped = Dictionary(grouping: typeFiltered, by: { $0.category })
        let totalAmount = typeFiltered.reduce(0) { $0 + $1.amount }

        guard totalAmount > 0 else { return [] }

        return grouped.map { (category, txs) in
            let amt = txs.reduce(0) { $0 + $1.amount }
            let pct = amt / totalAmount
            return CategorySummary(category: category, amount: amt, percentage: pct)
        }.sorted(by: { $0.amount > $1.amount })
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    reportHeader
                    modePicker
                    periodNavigatorHeader

                    ScrollView {
                        VStack(spacing: 20) {
                            let summaries = chartData

                            if summaries.isEmpty {
                                Text("작성된 내역이 없어요")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 100)
                            } else {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("카테고리별 상세 비율")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .padding(.leading, 4)

                                    ForEach(summaries) { summary in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(summary.category.color)
                                                .frame(width: 12, height: 12)

                                            Image(systemName: summary.category.iconName)
                                                .font(.footnote)
                                                .foregroundColor(summary.category.color)

                                            Text(summary.category.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)

                                            Spacer()

                                            Text("\(Int(summary.percentage * 100))%")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.gray)

                                            Text("\(Int(summary.amount).formatted())원")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                                .frame(width: 90, alignment: .trailing)
                                        }
                                        .padding(.vertical, 4)
                                        Divider().background(Color.appDivider)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
    }

    private var reportHeader: some View {
        HStack {
            CircularBackButton {
                dismiss()
            }

            Spacer()

            Menu {
                Picker("기간 설정", selection: $selectedPeriod) {
                    ForEach(GraphPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedPeriod.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var modePicker: some View {
        Picker("수입 지출 선택", selection: $isIncomeMode) {
            Text("지출").tag(false)
            Text("수입").tag(true)
        }
        .pickerStyle(.segmented)
        .tint(Color(red: 0.92, green: 0.45, blue: 0.38))
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var periodNavigatorHeader: some View {
        HStack {
            Button {
                navigatePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .padding()
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            Text(periodTitle)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            Button {
                navigatePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .padding()
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .background(Color.appBackground)
    }

    private var periodTitle: String {
        let calendar = Calendar.current
        let date = viewModel.currentDate

        switch selectedPeriod {
        case .weekly:
            guard let range = calendar.dateInterval(of: .weekOfYear, for: date) else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "M월 d일"
            return "\(formatter.string(from: range.start)) ~ \(formatter.string(from: range.end))"
        case .monthly:
            return date.koreanYearMonthString
        case .yearly:
            return "\(date.year)년"
        }
    }

    private func navigatePeriod(by value: Int) {
        let calendar = Calendar.current
        let current = viewModel.currentDate

        var dateComponent = DateComponents()
        switch selectedPeriod {
        case .weekly:
            dateComponent.weekOfYear = value
        case .monthly:
            dateComponent.month = value
        case .yearly:
            dateComponent.year = value
        }

        if let newDate = calendar.date(byAdding: dateComponent, to: current) {
            viewModel.currentDate = newDate
        }
    }
}

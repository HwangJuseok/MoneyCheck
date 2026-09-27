import SwiftUI

public struct ListView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BudgetViewModel

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    monthSelectorHeader

                    let monthTransactions = viewModel.transactions(for: viewModel.currentDate)

                    if monthTransactions.isEmpty {
                        Text("작성된 내역이 없어요")
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(monthTransactions) { transaction in
                                TransactionListRow(transaction: transaction)
                                    .listRowBackground(Color.appBackground)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTransaction(transaction)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.appBackground)
                        .listStyle(.plain)
                    }
                }
            }
        }
    }

    private var monthSelectorHeader: some View {
        HStack {
            CircularBackButton {
                dismiss()
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("이전 달")

                Text(viewModel.currentDate.koreanYearMonthString)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("다음 달")
            }

            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.appBackground)
    }

    private func changeMonth(by amount: Int) {
        if let nextMonth = Calendar.current.date(byAdding: .month, value: amount, to: viewModel.currentDate) {
            viewModel.currentDate = nextMonth
        }
    }
}

public struct TransactionListRow: View {
    var transaction: Transaction

    public init(transaction: Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(transaction.category.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.category.iconName)
                    .font(.title3)
                    .foregroundColor(transaction.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if transaction.isRecurring {
                        Text("반복")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.emerald)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.emerald.opacity(0.12))
                            .cornerRadius(4)
                    }

                    if transaction.type == .fixedExpense {
                        Text("고정")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(4)
                    }
                }

                Text(transaction.memo.isEmpty ? "메모 없음" : transaction.memo)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.type == .income ? "+\(Int(transaction.amount).formatted())원" : "-\(Int(transaction.amount).formatted())원")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == .income ? .blue : .red)

                Text(formatShortDate(transaction.date))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.clear)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}


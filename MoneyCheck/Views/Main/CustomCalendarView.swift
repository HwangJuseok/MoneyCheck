import SwiftUI

public struct CustomCalendarView: View {
    @Bindable var viewModel: BudgetViewModel
    
    private let sundayFirstWeekdays = ["일", "월", "화", "수", "목", "금", "토"]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    
    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .padding(.horizontal, 8)

            let dates = viewModel.currentDate.generateCalendarDates(startingWeekday: viewModel.userSettings?.calendarStartWeekday ?? 1)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(dates, id: \.self) { date in
                    calendarCell(for: date)
                        .onTapGesture {
                            viewModel.selectedDate = date
                        }
                }
            }
            .id(viewModel.currentDate.yearMonthString)
            .transition(.opacity)
            .gesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onEnded { value in
                        let calendar = Calendar.current
                        if value.translation.height < -30 {
                            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: viewModel.currentDate) {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    viewModel.currentDate = nextMonth
                                }
                            }
                        } else if value.translation.height > 30 {
                            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: viewModel.currentDate) {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    viewModel.currentDate = prevMonth
                                }
                            }
                        }
                    }
            )
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.28), value: viewModel.currentDate)
    }

    private var weekdays: [String] {
        let start = viewModel.userSettings?.calendarStartWeekday ?? 1
        return Array(sundayFirstWeekdays[(start - 1)...]) + Array(sundayFirstWeekdays[..<(start - 1)])
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isCurrentMonth = date.month == viewModel.currentDate.month

        let dailyTransactions = viewModel.transactions(on: date)
        let incomeSum = dailyTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenseSum = dailyTransactions.filter { $0.type == .expense || $0.type == .fixedExpense }.reduce(0) { $0 + $1.amount }

        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appSurface)
                        .frame(width: 36, height: 34)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSecondary, lineWidth: 1)
                        .frame(width: 36, height: 34)
                }

                Text("\(date.day)")
                    .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundColor(isCurrentMonth ? .primary : .secondary.opacity(0.35))
            }
            .frame(height: 32)

            VStack(spacing: 2) {
                if incomeSum > 0 {
                    Text("+\(formatCompact(incomeSum))")
                        .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.appSecondary)
                        .lineLimit(1)
                } else {
                    Spacer().frame(height: 10)
                }

                if expenseSum > 0 {
                    Text("-\(formatCompact(expenseSum))")
                        .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.appSecondary)
                        .lineLimit(1)
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .frame(height: 18)
        }
        .frame(height: 52)
        .contentShape(Rectangle())
        .background(Color.clear)
    }

    private func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)

        if absValue >= 1_000_000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            formatter.roundingMode = .halfUp
            formatter.positiveSuffix = "M"
            formatter.negativeSuffix = "M"
            return formatter.string(from: NSNumber(value: value / 1_000_000)) ?? "0"
        } else if absValue >= 1_000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            formatter.roundingMode = .halfUp
            formatter.positiveSuffix = "K"
            formatter.negativeSuffix = "K"
            return formatter.string(from: NSNumber(value: value / 1_000)) ?? "0"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
    }
}

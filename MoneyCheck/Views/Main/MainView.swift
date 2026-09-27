import SwiftUI

public struct MainView: View {
    @Bindable private var viewModel: BudgetViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var isShowingAddTransaction = false
    @State private var isShowingOCRImport = false
    @State private var isShowingList = false
    @State private var isShowingGraph = false
    @State private var isShowingSearch = false
    @State private var isShowingSettings = false
    @State private var transactionToEdit: Transaction?

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    topAppBar
                    DashboardView(viewModel: viewModel)
                    CustomCalendarView(viewModel: viewModel)
                    selectedDateTransactions
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, 72)

                floatingActions
            }
            .sheet(isPresented: $isShowingAddTransaction) {
                TransactionFormView(viewModel: viewModel)
            }
            .sheet(item: $transactionToEdit) { transaction in
                TransactionFormView(viewModel: viewModel, transactionToEdit: transaction)
            }
            .sheet(isPresented: $isShowingOCRImport) {
                OCRImportView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingList) {
                ListView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingGraph) {
                GraphView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingSearch) {
                SearchView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingView(viewModel: viewModel)
            }
        }
        .id(themeManager.theme)
    }

    private var topAppBar: some View {
        HStack {
            HStack(spacing: 10) {
                navigationButton(systemImage: "list.bullet") {
                    isShowingList = true
                }
                navigationButton(systemImage: "chart.bar.xaxis") {
                    isShowingGraph = true
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("이전 달")

                Text("\(viewModel.currentDate.month)월")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 42)

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("다음 달")
            }

            Spacer()

            HStack(spacing: 10) {
                navigationButton(systemImage: "magnifyingglass") {
                    isShowingSearch = true
                }
                navigationButton(systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var selectedDateTransactions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("선택한 날짜")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(viewModel.selectedDate.koreanDateAndWeekdayString)
                        .font(.headline)
                }

                Spacer()

                Text("\(selectedTransactions.count)건")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }

            if selectedTransactions.isEmpty {
                Text("등록된 내역이 없습니다.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(selectedTransactions) { transaction in
                            Button {
                                transactionToEdit = transaction
                            } label: {
                                TransactionListRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)

                            if transaction.id != selectedTransactions.last?.id {
                                Divider().background(Color.appDivider)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var floatingActions: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button {
                isShowingOCRImport = true
            } label: {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
                    .background(Theme.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .accessibilityLabel("영수증 OCR 가져오기")

            Button {
                isShowingAddTransaction = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(Theme.primaryTextColor)
                    .frame(width: 58, height: 58)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .accessibilityLabel("내역 추가")
        }
        .padding(.trailing, 16)
        .padding(.bottom, 14)
    }

    private var selectedTransactions: [Transaction] {
        viewModel.transactions(on: viewModel.selectedDate)
            .sorted { $0.date < $1.date }
    }

    private func navigationButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 38, height: 38)
                .background(Color.appSurface)
                .clipShape(Circle())
        }
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: viewModel.currentDate) {
            withAnimation(.easeInOut(duration: 0.28)) {
                viewModel.currentDate = newDate
            }
        }
    }
}
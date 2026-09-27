import SwiftUI

public struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: BudgetViewModel

    @State private var searchQuery: String = ""
    @State private var isCustomDateEnabled: Bool = false
    @State private var startDate: Date = Date().startOfMonth
    @State private var endDate: Date = Date()
    @State private var minAmount: String = ""
    @State private var maxAmount: String = ""
    @State private var selectedCategories: Set<CategoryType> = []

    @State private var searchResults: [Transaction] = []
    @State private var hasSearched: Bool = false

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("메모 검색")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("검색어를 입력하세요(예: 점심, 월급)", text: $searchQuery)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.none)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("날짜 선택")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                Spacer()
                                Toggle("", isOn: $isCustomDateEnabled)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }

                            if isCustomDateEnabled {
                                VStack(spacing: 12) {
                                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                                        .environment(\.locale, Locale(identifier: "ko_KR"))
                                        .tint(.blue)
                                    DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                                        .environment(\.locale, Locale(identifier: "ko_KR"))
                                        .tint(.blue)
                                }
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                Text("전체 기간 대상 검색")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.appSurface)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut, value: isCustomDateEnabled)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("금액 범위 설정")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            HStack(spacing: 10) {
                                amountField(placeholder: "최소 금액", text: $minAmount)
                                Text("~")
                                    .foregroundColor(.gray)
                                amountField(placeholder: "최대 금액", text: $maxAmount)
                            }
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("카테고리 다중 선택")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(CategoryType.allCases) { category in
                                        let isSelected = selectedCategories.contains(category)
                                        Button {
                                            if isSelected {
                                                selectedCategories.remove(category)
                                            } else {
                                                selectedCategories.insert(category)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: category.iconName)
                                                Text(category.rawValue)
                                            }
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? category.color : Color.appSurface)
                                            .foregroundColor(isSelected ? .primary : .primary)
                                            .cornerRadius(20)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal)

                        Divider().background(Color.appDivider).padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("검색 결과 (\(searchResults.count)건)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)

                            if searchResults.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text(hasSearched ? "일치하는 결과가 없습니다." : "원하는 조건으로 검색해 보세요.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(searchResults) { transaction in
                                        TransactionListRow(transaction: transaction)
                                            .padding(.horizontal)
                                        Divider().background(Color.appDivider).padding(.horizontal)
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.vertical)
                }

                VStack(spacing: 0) {
                    Divider().background(Color.appDivider)
                    Button {
                        performSearch()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("조건으로 검색하기")
                                .fontWeight(.bold)
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        .padding()
                    }
                    .background(Color.appBackground)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                DetailHeader(title: "필터 및 검색") { dismiss() }
            }
        }
    }

    private func performSearch() {
        hasSearched = true

        let minimum = parsedAmount(minAmount)
        let maximum = parsedAmount(maxAmount)

        let filtered = viewModel.transactions.filter { tx in
            if !searchQuery.isEmpty {
                let lowercasedQuery = searchQuery.lowercased()
                let matchMemo = tx.memo.lowercased().contains(lowercasedQuery)
                let matchCat = tx.category.rawValue.lowercased().contains(lowercasedQuery)
                if !matchMemo && !matchCat {
                    return false
                }
            }

            if isCustomDateEnabled {
                let startOfDay = startDate.startOfDay
                let endOfDay = endDate.endOfDay
                if tx.date < startOfDay || tx.date > endOfDay {
                    return false
                }
            }

            if !selectedCategories.isEmpty {
                if !selectedCategories.contains(tx.category) {
                    return false
                }
            }

            if let minimum, tx.amount < minimum {
                return false
            }

            if let maximum, tx.amount > maximum {
                return false
            }

            return true
        }

        self.searchResults = filtered
    }

    private func amountField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .font(.subheadline)
            .foregroundColor(.primary)
            .padding(.leading, 12)
            .padding(.trailing, 32)
            .frame(height: 44)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onChange(of: text.wrappedValue) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                let formatted = Int(digits).map { $0.formatted() } ?? ""
                if formatted != newValue {
                    text.wrappedValue = formatted
                }
            }
            .overlay(alignment: .trailing) {
                Text("원")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 12)
            }
    }

    private func parsedAmount(_ value: String) -> Double? {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Double(digits)
    }
}


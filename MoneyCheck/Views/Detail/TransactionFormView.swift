import SwiftUI
import PhotosUI
import SwiftData

public struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: BudgetViewModel
    var transactionToEdit: Transaction?
    private let ocrItem: OcrTempItem?
    private let onOCRSave: ((OcrTempItem) -> Void)?

    @State private var amount: Double = 0.0
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: CategoryType = .food
    @State private var memo: String = ""
    @State private var isRecurring: Bool = false
    @State private var photoData: Data? = nil

    @State private var isMultiDateEnabled: Bool = false
    @State private var singleDate: Date = Date()
    @State private var selectedDates: Set<DateComponents> = []

    @State private var isCalculatorPresented: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init(
        viewModel: BudgetViewModel,
        transactionToEdit: Transaction? = nil,
        ocrItem: OcrTempItem? = nil,
        onOCRSave: ((OcrTempItem) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.transactionToEdit = transactionToEdit
        self.ocrItem = ocrItem
        self.onOCRSave = onOCRSave

        if let t = transactionToEdit {
            _amount = State(initialValue: t.amount)
            _selectedType = State(initialValue: t.type)
            _selectedCategory = State(initialValue: t.category)
            _memo = State(initialValue: t.memo)
            _isRecurring = State(initialValue: t.isRecurring)
            _photoData = State(initialValue: t.photoData)
            _singleDate = State(initialValue: t.date)
            _isMultiDateEnabled = State(initialValue: false)
            _selectedDates = State(initialValue: [])
        } else if let item = ocrItem {
            _amount = State(initialValue: item.amount)
            _selectedType = State(initialValue: item.type)
            _selectedCategory = State(initialValue: item.category)
            _memo = State(initialValue: item.memo)
            _isRecurring = State(initialValue: false)
            _photoData = State(initialValue: nil)
            _singleDate = State(initialValue: item.date)
            _isMultiDateEnabled = State(initialValue: false)
            _selectedDates = State(initialValue: [])
        } else {
            _amount = State(initialValue: 0.0)
            _selectedType = State(initialValue: .expense)
            _selectedCategory = State(initialValue: .food)
            _memo = State(initialValue: "")
            _isRecurring = State(initialValue: false)
            _photoData = State(initialValue: nil)
            _singleDate = State(initialValue: viewModel.selectedDate)
            _isMultiDateEnabled = State(initialValue: false)
            _selectedDates = State(initialValue: [])
        }
    }

    private var filteredCategories: [CategoryType] {
        switch selectedType {
        case .income:
            return [.salary, .bonus, .etc]
        case .expense, .fixedExpense:
            return [.food, .transport, .medical, .culture, .mart, .education, .subscription, .etc]
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        typeSelectorCard
                        amountCard
                        categoryGridCard
                        datePickerCard
                        additionalInfoCard

                        if showValidationError {
                            Text(validationMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        saveButton
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(ocrItem != nil || transactionToEdit != nil ? "내역 편집" : "내역 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("취소")
                        }
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $isCalculatorPresented) {
                CalculatorPad(isPresented: $isCalculatorPresented, amount: $amount)
                    .presentationDetents([.fraction(0.55)])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedType) { _, newType in
                if newType == .income {
                    if ![.salary, .bonus, .etc].contains(selectedCategory) {
                        selectedCategory = .salary
                    }
                } else {
                    if [.salary, .bonus].contains(selectedCategory) {
                        selectedCategory = .food
                    }
                }
            }
        }
    }

    private func cardStyle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
        )
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }

    private var typeSelectorCard: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases) { type in
                let isSelected = selectedType == type
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedType = type
                    }
                } label: {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isSelected ? type.color : Color.clear)
                        .foregroundColor(isSelected ? .primary : .gray)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color.appSurface)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var amountCard: some View {
        cardStyle {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("금액")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    Text("\(Int(amount).formatted())원")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(selectedType.color)
                }

                Spacer()

                Button {
                    isCalculatorPresented = true
                } label: {
                    Image(systemName: "calculator")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(selectedType.color)
                        .clipShape(Circle())
                        .shadow(color: selectedType.color.opacity(0.3), radius: 6, y: 3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isCalculatorPresented = true
            }
        }
    }

    private var categoryGridCard: some View {
        cardStyle {
            Text("카테고리 선택")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.bottom, 2)

            LazyVGrid(columns: categoryColumns, spacing: 16) {
                ForEach(filteredCategories) { category in
                    let isSelected = selectedCategory == category

                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? category.color : Color.appSurface)
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(isSelected ? 1.05 : 1.0)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(isSelected ? .primary : category.color)
                            }

                            Text(category.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .primary : .gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var datePickerCard: some View {
        cardStyle {
            if transactionToEdit == nil {
                HStack {
                    Label {
                        Text("여러 날짜 한 번에 추가")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Toggle("", isOn: $isMultiDateEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.bottom, 4)

                                Divider().background(Color.appDivider)
            }

            if isMultiDateEnabled && transactionToEdit == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("다중 날짜 선택")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    MultiDatePicker("날짜 선택", selection: $selectedDates)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .padding(8)
                        .background(Color.appSurface)
                        .cornerRadius(12)

                    if !selectedDates.isEmpty {
                        Text("선택된 날짜 개수: \(selectedDates.count)일")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                DatePicker(
                    "날짜 선택",
                    selection: $singleDate,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .font(.subheadline)
                .fontWeight(.medium)
                .tint(.blue)
            }
        }
        .animation(.easeInOut, value: isMultiDateEnabled)
    }

    private var additionalInfoCard: some View {
        cardStyle {
            Text("추가 정보")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.bottom, 2)

            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.gray)
                TextField("메모를 입력하세요", text: $memo)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color.appSurface)
            .cornerRadius(12)

            Divider().background(Color.appDivider).padding(.vertical, 4)

            Toggle(isOn: $isRecurring) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("매달 자동 반복 등록")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("다음 달 동일 일자에 자동으로 해당 내역을 복제합니다.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } icon: {
                    Image(systemName: "arrow.3.trianglepath")
                        .foregroundColor(.emerald)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .emerald))

            Divider().background(Color.appDivider).padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text("영수증 및 사진 첨부")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(photoData == nil ? "사진 찾기" : "사진 변경")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appSurface)
                            .foregroundColor(.purple)
                            .cornerRadius(10)
                    }
                }

                if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .cornerRadius(10)
                            .clipped()

                        Button {
                            self.photoData = nil
                            self.selectedPhotoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.appSurface))
                        }
                        .offset(x: 6, y: -6)
                    }
                    .padding(.top, 4)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.photoData = data
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            Text(transactionToEdit == nil && ocrItem == nil ? "저장하기" : "수정 완료")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(amount > 0 ? selectedType.color : Color.gray)
                .cornerRadius(16)
                .shadow(color: (amount > 0 ? selectedType.color : Color.gray).opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .disabled(amount <= 0)
    }

    private func saveTransaction() {
        guard amount > 0 else {
            showValidationError = true
            validationMessage = "금액은 0원보다 커야 합니다."
            return
        }

        if let ocrItem, let onOCRSave {
            var updatedItem = OcrTempItem(
                id: ocrItem.id,
                date: singleDate,
                type: selectedType,
                amount: amount,
                category: selectedCategory,
                memo: memo
            )
            updatedItem.isChecked = ocrItem.isChecked
            onOCRSave(updatedItem)
        } else if transactionToEdit == nil {
            if isMultiDateEnabled {
                guard !selectedDates.isEmpty else {
                    showValidationError = true
                    validationMessage = "추가할 날짜를 하나 이상 선택해 주세요."
                    return
                }

                let calendar = Calendar.current
                let dates = selectedDates.compactMap { calendar.date(from: $0) }

                for date in dates {
                    viewModel.addTransaction(
                        date: date,
                        type: selectedType,
                        amount: amount,
                        category: selectedCategory,
                        memo: memo,
                        photoData: photoData,
                        isRecurring: isRecurring
                    )
                }
            } else {
                viewModel.addTransaction(
                    date: singleDate,
                    type: selectedType,
                    amount: amount,
                    category: selectedCategory,
                    memo: memo,
                    photoData: photoData,
                    isRecurring: isRecurring
                )
            }
        } else {
            guard let editItem = transactionToEdit else { return }
            editItem.amount = amount
            editItem.type = selectedType
            editItem.category = selectedCategory
            editItem.memo = memo
            editItem.date = singleDate
            editItem.isRecurring = isRecurring
            editItem.photoData = photoData

            if !isRecurring {
                editItem.isAppliedRecurring = false
            }

            viewModel.updateTransaction(editItem)
        }

        dismiss()
    }
}


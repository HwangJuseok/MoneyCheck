import SwiftUI
import PhotosUI
import UIKit

public struct OCRItem: Identifiable {
    public let id: UUID
    public var date: Date
    public var type: TransactionType
    public var amount: Double
    public var category: CategoryType
    public var memo: String
    public var isSelected: Bool

    public init(id: UUID = UUID(), date: Date, type: TransactionType = .expense, amount: Double, category: CategoryType = .etc, memo: String, isSelected: Bool = true) {
        self.id = id
        self.date = date
        self.type = type
        self.amount = amount
        self.category = category
        self.memo = memo
        self.isSelected = isSelected
    }

    fileprivate init(result: ParsedOCRResult) {
        self.init(date: result.date, type: result.type, amount: result.amount, category: result.category, memo: result.merchant)
    }
}

public struct OCRImportView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: BudgetViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var ocrItems: [OCRItem] = []
    @State private var editingItem: OCRItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    private let ocrService = OCRService()
    private let parser = OCRParserService()

    public init(viewModel: BudgetViewModel) { self.viewModel = viewModel }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                thumbnailStrip
                if isProcessing {
                    ProgressView("선택한 사진을 분석하고 있습니다...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if ocrItems.isEmpty {
                    emptyState
                } else {
                    resultList
                }
                if !ocrItems.isEmpty { saveButton }
            }
            .navigationTitle("영수증 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("닫기") { dismiss() } }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await process(items: Array(items.prefix(5))) }
            }
            .sheet(item: $editingItem) { item in
                TransactionFormView(viewModel: viewModel, ocrItem: toLegacy(item), onOCRSave: { updated in
                    guard let index = ocrItems.firstIndex(where: { $0.id == item.id }) else { return }
                    ocrItems[index] = OCRItem(id: item.id, date: updated.date, type: updated.type, amount: updated.amount, category: updated.category, memo: updated.memo, isSelected: item.isSelected)
                    editingItem = nil
                })
            }
            .alert("OCR 안내", isPresented: errorAlertBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "인식된 거래가 없습니다.") }
        }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 64, height: 64)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                ForEach(Array(imageData.enumerated()), id: \.offset) { _, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder").font(.system(size: 52)).foregroundColor(.appSecondary)
            Text("영수증 또는 카드 내역 사진을 최대 5장 선택해 주세요").font(.headline).multilineTextAlignment(.center)
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                Label("사진 선택", systemImage: "photo.on.rectangle.angled")
                    .foregroundColor(.primary).padding(.horizontal, 20).frame(height: 48)
                    .background(Color.appSurface).clipShape(Capsule())
            }
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultList: some View {
        List {
            Section("인식된 내역") {
                ForEach($ocrItems) { $item in
                    HStack(spacing: 10) {
                        Button { item.isSelected.toggle() } label: {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(item.isSelected ? .blue : .appSecondary)
                        }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.memo.isEmpty ? "인식된 거래" : item.memo).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(item.date.koreanDateAndWeekdayString).font(.caption).foregroundColor(.appSecondary)
                        }
                        Spacer()
                        Text("\(item.type == .income ? "+" : "-")\(Int(item.amount).formatted())원")
                            .font(.subheadline.weight(.bold)).foregroundColor(item.type == .income ? .blue : .red)
                        Button("수정") { editingItem = item }.font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var saveButton: some View {
        Button {
            for item in ocrItems where item.isSelected {
                viewModel.addTransaction(date: item.date, type: item.type, amount: item.amount, category: item.category, memo: item.memo)
            }
            dismiss()
        } label: {
            Text("\(selectedCount)개 내역 선택하여 추가하기")
                .font(.headline.weight(.bold)).foregroundColor(.primary)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(selectedCount > 0 ? Color.appSurface : Color.appSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14)).padding()
        }
        .disabled(selectedCount == 0)
    }

    private var selectedCount: Int { ocrItems.filter(\.isSelected).count }
    private var errorAlertBinding: Binding<Bool> { Binding(get: { errorMessage != nil && !isProcessing }, set: { if !$0 { errorMessage = nil } }) }

    private func process(items: [PhotosPickerItem]) async {
        await MainActor.run { isProcessing = true; errorMessage = nil; ocrItems = []; imageData = [] }
        var parsed: [OCRItem] = []
        var loadedData: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            do {
                let lines = try await ocrService.recognize(data: data)
                parsed.append(contentsOf: parser.parse(lines: lines, defaultDate: viewModel.selectedDate).map(OCRItem.init))
                loadedData.append(data)
            } catch {
                continue
            }
        }
        await MainActor.run {
            imageData = loadedData
            ocrItems = parsed
            isProcessing = false
            if parsed.isEmpty { errorMessage = "날짜나 금액을 인식하지 못했습니다. 더 선명한 사진을 선택해 주세요." }
        }
    }

    private func toLegacy(_ item: OCRItem) -> OcrTempItem {
        var legacy = OcrTempItem(id: item.id, date: item.date, type: item.type, amount: item.amount, category: item.category, memo: item.memo)
        legacy.isChecked = item.isSelected
        return legacy
    }
}

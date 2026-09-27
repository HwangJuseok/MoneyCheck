import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications
import PhotosUI
import UIKit

private enum SettingsTheme {
    static var background: Color { Theme.backgroundColor }
    static var surface: Color { Theme.cardBackgroundColor }
    static var secondary: Color { Theme.secondaryTextColor }
    static var accent: Color { Theme.accentColor }
}

struct SettingsHubView: View {
    @Bindable var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var notificationTime = Date()
    @State private var budgetAmount = 0.0
    @State private var salaryDayDate = Date()
    @State private var showingBudgetSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                generalSection
                managementSection
                budgetSection
                securitySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(Theme.backgroundColor.ignoresSafeArea())
        .tint(.primary)
        .onAppear {
            notificationsEnabled = viewModel.userSettings?.notificationsEnabled ?? true
            notificationTime = viewModel.userSettings?.notificationTime ?? Date()
            let config = viewModel.getMonthlyConfig(for: viewModel.currentDate)
            budgetAmount = config.budget
            salaryDayDate = config.salaryDay
            updateNotificationSchedule()
        }
        .onChange(of: notificationsEnabled) { _, value in
            viewModel.userSettings?.notificationsEnabled = value
            viewModel.saveUserSettings()
            updateNotificationSchedule()
        }
        .onChange(of: notificationTime) { _, value in
            viewModel.userSettings?.notificationTime = value
            viewModel.saveUserSettings()
            updateNotificationSchedule()
        }
        .alert("설정 저장 완료", isPresented: $showingBudgetSaved) { Button("확인", role: .cancel) {} }
    }

    @ViewBuilder
    private var generalSection: some View {
        VStack(spacing: 1) {
            ToggleRow(title: "알림", icon: "bell.fill", isOn: $notificationsEnabled)
            DatePickerRow(title: "알림 시간", icon: "clock.fill", date: $notificationTime)
            NavigationLink { ThemeSettingsView(viewModel: viewModel) } label: { SettingsRow(title: "테마 설정", icon: "circle.lefthalf.filled") }
            NavigationLink { FontSettingsView(viewModel: viewModel) } label: { SettingsRow(title: "글자 스타일", icon: "textformat") }
        }
        .settingsGroupCard()
    }

    @ViewBuilder
    private var managementSection: some View {
            VStack(alignment: .leading, spacing: 12) {
            settingsSectionTitle("관리")
            VStack(spacing: 1) {
            NavigationLink { CategoryManagementView() } label: { SettingsRow(title: "카테고리 관리", icon: "square.grid.2x2.fill") }
            NavigationLink { RecurringManagementView(viewModel: viewModel) } label: { SettingsRow(title: "반복 관리", icon: "repeat") }
            NavigationLink { SavingsManagementView() } label: { SettingsRow(title: "저축 관리", icon: "banknote.fill") }
            NavigationLink { CalendarSettingsView(viewModel: viewModel) } label: { SettingsRow(title: "캘린더 설정", icon: "calendar") }
            }
            .settingsGroupCard()
        }
    }

    @ViewBuilder
    private var budgetSection: some View {
            VStack(alignment: .leading, spacing: 12) {
            settingsSectionTitle("이번 달 재정 목표")
            VStack(spacing: 8) {
            HStack {
                Text("목표 예산").foregroundColor(.primary)
                Spacer()
                TextField("금액", value: $budgetAmount, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                Text("원").foregroundColor(SettingsTheme.secondary)
            }
            .listRowBackground(SettingsTheme.surface)
            DatePicker("기준 월급날", selection: $salaryDayDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .listRowBackground(SettingsTheme.surface)
            Button("설정 저장") {
                viewModel.updateMonthlyConfig(yearMonth: viewModel.currentDate.yearMonthString, budget: budgetAmount, salaryDay: salaryDayDate)
                showingBudgetSaved = true
            }
            .foregroundColor(SettingsTheme.accent)
            .frame(maxWidth: .infinity)
            .listRowBackground(SettingsTheme.surface)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 22).fill(SettingsTheme.surface))
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSectionTitle("보안 및 백업")
            VStack(spacing: 8) {
            NavigationLink { ScreenLockSettingsView(viewModel: viewModel) } label: { SettingsRow(title: "화면 잠금", icon: "lock.fill") }
            NavigationLink { CloudSyncView(viewModel: viewModel) } label: { SettingsRow(title: "iCloud 동기화", icon: "icloud.fill") }
            NavigationLink { BackupRestoreView(viewModel: viewModel) } label: { SettingsRow(title: "수동 백업/복원", icon: "arrow.up.arrow.down") }
            }
            .settingsGroupCard()
        }
    }

    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundColor(SettingsTheme.secondary)
            .padding(.leading, 2)
    }

    private func updateNotificationSchedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["moneycheck-daily-reminder"])
        guard notificationsEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let components = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "MoneyCheck"
            content.body = "오늘의 지출을 기록해보세요."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "moneycheck-daily-reminder", content: content, trigger: trigger)
            center.add(request)
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 24).foregroundColor(.primary.opacity(0.8))
            Text(title).foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .frame(minHeight: 54)
        .listRowBackground(Color.clear)
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 24).foregroundColor(.primary.opacity(0.8))
            Text(title).foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(SettingsTheme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .frame(minHeight: 54)
        .listRowBackground(Color.clear)
    }
}

struct DatePickerRow: View {
    let title: String
    let icon: String
    @Binding var date: Date
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 24).foregroundColor(.primary.opacity(0.8))
            Text(title).foregroundColor(.primary)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute).labelsHidden().tint(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .frame(minHeight: 54)
        .listRowBackground(Color.clear)
    }
}

struct ThemeSettingsView: View {
    @Bindable var viewModel: BudgetViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        List {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    viewModel.updateTheme(theme)
                    themeManager.apply(theme: theme)
                } label: {
                    HStack {
                        Text(theme.rawValue).foregroundColor(.primary)
                        Spacer()
                        if viewModel.userSettings?.theme == theme { Image(systemName: "checkmark").foregroundColor(SettingsTheme.accent) }
                    }
                }
                .listRowBackground(SettingsTheme.surface)
            }
        }
        .screenSettingsStyle(title: "테마 설정")
    }
}

struct FontSettingsView: View {
    @Bindable var viewModel: BudgetViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    private let fonts = AppFontStyle.allCases
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling.fill").font(.system(size: 48)).foregroundColor(SettingsTheme.accent)
                    Text("2026.09.17 목요일").font(.caption).foregroundColor(SettingsTheme.secondary)
                    Text("꼬박꼬박 오늘의 지출을 기록해보세요.").font(viewModel.appFont).foregroundColor(.primary)
                    Text("글꼴을 변경할 수 있어요!").font(.subheadline).foregroundColor(SettingsTheme.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 22).listRowBackground(SettingsTheme.surface)
            }
            Section("글꼴 선택") {
                ForEach(fonts) { font in
                    Button {
                        viewModel.userSettings?.fontName = font.rawValue
                        themeManager.apply(fontName: font.rawValue)
                        viewModel.saveUserSettings()
                    } label: {
                        HStack {
                            Text(font.rawValue).font(font.font).foregroundColor(.primary)
                            Spacer()
                            if viewModel.userSettings?.fontName == font.rawValue { Image(systemName: "checkmark.circle.fill").foregroundColor(SettingsTheme.accent) }
                        }
                    }.listRowBackground(SettingsTheme.surface)
                }
            }
        }.screenSettingsStyle(title: "글자 스타일")
    }
}

struct CalendarSettingsView: View {
    @Bindable var viewModel: BudgetViewModel
    var body: some View {
        List {
            Section("캘린더 시작 요일") {
                weekdayButton("일요일", value: 1)
                weekdayButton("월요일", value: 2)
            }
        }.screenSettingsStyle(title: "캘린더 설정")
    }
    private func weekdayButton(_ title: String, value: Int) -> some View {
                Button {
                    viewModel.userSettings?.calendarStartWeekday = value
                    viewModel.saveUserSettings()
                } label: {
            HStack { Text(title).foregroundColor(.primary); Spacer(); if viewModel.userSettings?.calendarStartWeekday == value { Image(systemName: "checkmark.circle.fill").foregroundColor(SettingsTheme.accent) } }
        }.listRowBackground(SettingsTheme.surface)
    }
}

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [CategoryDefinition]
    @State private var kind: ManagedCategoryKind = .expense
    @State private var showingAdd = false
    @State private var editingCategory: CategoryDefinition?

    var body: some View {
        List {
            Picker("종류", selection: $kind) { ForEach(ManagedCategoryKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).listRowBackground(SettingsTheme.background)
            ForEach(categories.filter { $0.kind == kind }) { category in
                HStack(spacing: 14) {
                    categoryIcon(for: category)
                    Text(category.name).foregroundColor(.primary)
                    Spacer()
                    Button { editingCategory = category } label: { Image(systemName: "pencil").foregroundColor(SettingsTheme.secondary) }
                }
                .swipeActions { Button(role: .destructive) { modelContext.delete(category); try? modelContext.save() } label: { Label("삭제", systemImage: "trash") } }
                .listRowBackground(SettingsTheme.surface)
            }

            Section("카테고리 아이콘") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 12)], spacing: 12) {
                    ForEach(CategoryType.allCases.filter { kind == .income ? ($0 == .salary || $0 == .bonus) : ($0 != .salary && $0 != .bonus) }) { category in
                        VStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.title3)
                                .foregroundColor(SettingsTheme.accent)
                            Text(category.rawValue)
                                .font(.caption2)
                                .foregroundColor(SettingsTheme.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(SettingsTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .listRowBackground(SettingsTheme.background)
            }
        }
        .screenSettingsStyle(title: "카테고리 관리")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingAdd) { CategoryEditorView(kind: kind) }
        .sheet(item: $editingCategory) { category in CategoryEditorView(category: category) }
    }

    @ViewBuilder
    private func categoryIcon(for category: CategoryDefinition) -> some View {
        if let data = category.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 34, height: 34).clipShape(Circle())
        } else {
            Image(systemName: category.iconName).frame(width: 34, height: 34).foregroundColor(SettingsTheme.accent)
        }
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var category: CategoryDefinition?
    @State private var name = ""
    @State private var icon = "circle.fill"
    @State private var kind: ManagedCategoryKind = .expense
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    init(category: CategoryDefinition? = nil, kind: ManagedCategoryKind = .expense) { self.category = category; _kind = State(initialValue: kind) }
    var body: some View {
        NavigationStack { Form {
            TextField("카테고리 이름", text: $name)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Text("카테고리 사진")
                    Spacer()
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle())
                    } else {
                        Image(systemName: "photo.circle").font(.title2)
                    }
                }
            }
            Picker("종류", selection: $kind) { ForEach(ManagedCategoryKind.allCases) { Text($0.rawValue).tag($0) } }
        }.navigationTitle(category == nil ? "카테고리 추가" : "카테고리 수정").toolbar { ToolbarItem(placement: .confirmationAction) { Button("저장") { if let category { category.name = name; category.kind = kind; category.photoData = photoData } else { modelContext.insert(CategoryDefinition(name: name, iconName: icon, kind: kind, photoData: photoData)) }; try? modelContext.save(); dismiss() } } }.onAppear { if let category { name = category.name; icon = category.iconName; kind = category.kind; photoData = category.photoData } }.onChange(of: selectedPhoto) { _, item in Task { photoData = try? await item?.loadTransferable(type: Data.self) } } }
    }
}

struct SavingsManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [SavingsAccount]
    @State private var showingAdd = false
    private var total: Double { accounts.reduce(0) { $0 + $1.amount } }
    var body: some View {
        List {
            Section { VStack(alignment: .leading, spacing: 8) { Text("총 자산").font(.caption).foregroundColor(SettingsTheme.secondary); HStack { Circle().fill(SettingsTheme.accent).frame(width: 8, height: 8); Text("\(Int(total).formatted())원").font(.title2.weight(.semibold)).foregroundColor(.primary) } }.padding(.vertical, 10).listRowBackground(SettingsTheme.surface) }
            Section("계좌 목록") {
                ForEach(accounts) { account in HStack(spacing: 14) { Image(systemName: account.kind.iconName).frame(width: 26).foregroundColor(SettingsTheme.accent); VStack(alignment: .leading) { Text(account.kind.rawValue).foregroundColor(.primary); Text(account.name).font(.caption).foregroundColor(SettingsTheme.secondary) }; Spacer(); Text("\(Int(account.amount).formatted())원").foregroundColor(.primary) }.listRowBackground(SettingsTheme.surface) }
                .onDelete { offsets in offsets.map { accounts[$0] }.forEach(modelContext.delete); try? modelContext.save() }
            }
            Button { showingAdd = true } label: { Label("계좌 추가", systemImage: "plus").frame(maxWidth: .infinity).foregroundColor(SettingsTheme.accent) }.listRowBackground(SettingsTheme.surface)
        }.screenSettingsStyle(title: "저축").sheet(isPresented: $showingAdd) { SavingsEditorView() }
    }
}

struct SavingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var amount = ""
    @State private var kind: SavingsAccountKind = .deposit
    var body: some View { NavigationStack { Form { Picker("종류", selection: $kind) { ForEach(SavingsAccountKind.allCases) { Text($0.rawValue).tag($0) } }; TextField("계좌 이름", text: $name); TextField("금액", text: $amount).keyboardType(.numberPad) }.navigationTitle("계좌 추가").toolbar { ToolbarItem(placement: .confirmationAction) { Button("저장") { modelContext.insert(SavingsAccount(name: name.isEmpty ? kind.rawValue : name, kind: kind, amount: Double(amount.filter(\.isNumber) ) ?? 0)); try? modelContext.save(); dismiss() } } } } }
}

struct RecurringManagementView: View {
    var viewModel: BudgetViewModel
    @State private var showingAdd = false
    private var recurring: [Transaction] { viewModel.transactions.filter(\.isRecurring) }
    var body: some View {
        List {
            if recurring.isEmpty {
                Text("반복중인 데이터가 없습니다.").foregroundColor(SettingsTheme.secondary).frame(maxWidth: .infinity).padding(.vertical, 80).listRowBackground(SettingsTheme.background)
            } else {
                ForEach(recurring) { transaction in TransactionListRow(transaction: transaction).listRowBackground(SettingsTheme.surface) }
            }
            Button { showingAdd = true } label: { Label("반복 내역 추가", systemImage: "plus") }.listRowBackground(SettingsTheme.surface)
        }
        .screenSettingsStyle(title: "반복 관리")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingAdd) { RecurringEditorView(viewModel: viewModel) }
    }
}

struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: BudgetViewModel
    @State private var date = Date()
    @State private var amount = ""
    @State private var memo = ""
    @State private var category: CategoryType = .food

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("반복 시작일", selection: $date, displayedComponents: .date)
                TextField("금액", text: $amount).keyboardType(.numberPad)
                Picker("카테고리", selection: $category) {
                    ForEach(CategoryType.allCases.filter { $0 != .salary && $0 != .bonus }) { Text($0.rawValue).tag($0) }
                }
                TextField("메모", text: $memo)
            }
            .navigationTitle("반복 내역 추가")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let value = Double(amount.filter(\.isNumber)) ?? 0
                        guard value > 0 else { return }
                        viewModel.addTransaction(date: date, type: .expense, amount: value, category: category, memo: memo, isRecurring: true)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ScreenLockSettingsView: View {
    @Bindable var viewModel: BudgetViewModel
    @State private var showingUnavailable = false
    var body: some View {
        List {
            Text("비밀번호를 잃어버리면 찾을 수 없습니다. 비밀번호, 생체인증을 모두 활성화하면 생체인증을 우선합니다.")
                .font(.footnote).foregroundColor(SettingsTheme.secondary).padding(.vertical, 8).listRowBackground(SettingsTheme.background)
            unavailableRow(title: "비밀번호", icon: "number.square.fill")
            unavailableRow(title: "생체인증", icon: "faceid")
        }
        .screenSettingsStyle(title: "화면 잠금")
        .alert("아직 구현 중입니다", isPresented: $showingUnavailable) { Button("확인", role: .cancel) {} }
    }

    private func unavailableRow(title: String, icon: String) -> some View {
        Button { showingUnavailable = true } label: {
            HStack {
                Image(systemName: icon).frame(width: 24).foregroundColor(.primary.opacity(0.8))
                Text(title).foregroundColor(.primary)
                Spacer()
                Text("준비 중").font(.caption).foregroundColor(SettingsTheme.secondary)
            }
        }
        .listRowBackground(SettingsTheme.surface)
    }
}

struct CloudSyncView: View {
    @Bindable var viewModel: BudgetViewModel
    @State private var showingUnavailable = false
    var body: some View {
        List {
            Text("iCloud 동기화를 사용하면 이 기기의 설정과 가계부 데이터를 개인 iCloud 계정에 안전하게 보관합니다.")
                .font(.footnote).foregroundColor(SettingsTheme.secondary).padding(.vertical, 8).listRowBackground(SettingsTheme.background)
            Button { showingUnavailable = true } label: {
                HStack {
                    Image(systemName: "icloud.fill").frame(width: 24).foregroundColor(.primary.opacity(0.8))
                    Text("iCloud 동기화").foregroundColor(.primary)
                    Spacer()
                    Text("준비 중").font(.caption).foregroundColor(SettingsTheme.secondary)
                }
            }.listRowBackground(SettingsTheme.surface)
        }
        .screenSettingsStyle(title: "iCloud 동기화")
        .alert("아직 구현 중입니다", isPresented: $showingUnavailable) { Button("확인", role: .cancel) {} }
    }
}

struct BackupRestoreView: View {
    @Bindable var viewModel: BudgetViewModel
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument = BackupDocument()
    @State private var showingUnavailable = false
    var body: some View {
        List {
            Text("데이터를 파일로 백업하거나 복원할 수 있습니다. Google Drive 연동은 계정 인증 후 사용할 수 있습니다.")
                .font(.footnote).foregroundColor(SettingsTheme.secondary).padding(.vertical, 8).listRowBackground(SettingsTheme.background)
            Button {
                exportDocument = BackupDocument(data: viewModel.makeBackupData())
                showingExporter = true
            } label: { SettingsRow(title: "데이터 백업", icon: "arrow.up.circle.fill") }.listRowBackground(SettingsTheme.surface)
            Button { showingImporter = true } label: { SettingsRow(title: "데이터 복원", icon: "arrow.down.circle.fill") }.listRowBackground(SettingsTheme.surface)
            Button { showingUnavailable = true } label: {
                HStack {
                    Image(systemName: "externaldrive.fill").frame(width: 24).foregroundColor(.primary.opacity(0.8))
                    Text("Google Drive 연동").foregroundColor(.primary)
                    Spacer()
                    Text("준비 중").font(.caption).foregroundColor(SettingsTheme.secondary)
                }
            }.listRowBackground(SettingsTheme.surface)
        }
        .screenSettingsStyle(title: "수동 백업/복원")
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "MoneyCheck-Backup.json") { _ in }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result, let data = try? Data(contentsOf: url) else { return }
            viewModel.restoreBackup(from: data)
        }
        .alert("아직 구현 중입니다", isPresented: $showingUnavailable) { Button("확인", role: .cancel) {} }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    init(data: Data = Data()) { self.data = data }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private extension View {
    func settingsGroupCard() -> some View {
        self
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 22).fill(SettingsTheme.surface))
    }

    func screenSettingsStyle(title: String) -> some View {
        self.scrollContentBackground(.hidden).background(Theme.backgroundColor.ignoresSafeArea()).listStyle(.insetGrouped).navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbarBackground(Theme.backgroundColor, for: .navigationBar)
    }
}

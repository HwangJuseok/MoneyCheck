import Foundation
import SwiftData
import SwiftUI
import Observation

private struct BackupTransaction: Codable {
    let id: UUID
    let date: Date
    let type: String
    let amount: Double
    let category: String
    let memo: String
    let isRecurring: Bool
}

private struct BackupCategory: Codable {
    let name: String
    let iconName: String
    let kind: String
}

private struct BackupSavingsAccount: Codable {
    let name: String
    let kind: String
    let amount: Double
}

private struct BackupSettings: Codable {
    let theme: String
    let notificationsEnabled: Bool
    let notificationTime: Date
    let fontName: String
    let calendarStartWeekday: Int
    let showYearlyTotal: Bool
}

private struct BackupPayload: Codable {
    let transactions: [BackupTransaction]
    let categories: [BackupCategory]
    let savingsAccounts: [BackupSavingsAccount]
    let settings: BackupSettings?
}

@Observable
public final class BudgetViewModel {
    private var modelContext: ModelContext
    
    // InMemory or Real database sync properties
    public var transactions: [Transaction] = []
    public var monthlyConfigs: [MonthlyConfig] = []
    public var userSettings: UserSettings?
    
    public var resolvedColorScheme: ColorScheme? {
        userSettings?.theme.colorScheme
    }

    public var theme: AppTheme {
        userSettings?.theme ?? .system
    }
    
    // UI Selected States
    public var currentDate: Date = Date()
    public var selectedDate: Date = Date()
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
        Theme.activeTheme = userSettings?.theme ?? .system
        processRecurringTransactions()
    }
    
    // MARK: - Data Fetching & Sync
    public func fetchData() {
        do {
            // Fetch Transactions
            let transactionDescriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            self.transactions = try modelContext.fetch(transactionDescriptor)
            
            // Fetch Monthly Configs
            let configDescriptor = FetchDescriptor<MonthlyConfig>()
            self.monthlyConfigs = try modelContext.fetch(configDescriptor)
            
            // Fetch User Settings
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let settings = try modelContext.fetch(settingsDescriptor)
            if let existingSettings = settings.first {
                self.userSettings = existingSettings
                Theme.activeTheme = existingSettings.theme
            } else {
                let defaultSettings = UserSettings(theme: .system)
                modelContext.insert(defaultSettings)
                try modelContext.save()
                self.userSettings = defaultSettings
            }
        } catch {
            print("Failed to fetch data from SwiftData: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transaction Operations
    public func addTransaction(
        date: Date,
        type: TransactionType,
        amount: Double,
        category: CategoryType,
        memo: String,
        photoData: Data? = nil,
        isRecurring: Bool = false
    ) {
        let newTransaction = Transaction(
            date: date,
            type: type,
            amount: amount,
            category: category,
            memo: memo,
            photoData: photoData,
            isRecurring: isRecurring
        )
        modelContext.insert(newTransaction)
        
        do {
            try modelContext.save()
            fetchData()
            // 새로운 내역이 추가되었을 때 즉시 반복 처리 여부 체크
            processRecurringTransactions()
        } catch {
            print("Error saving transaction: \(error)")
        }
    }
    
    public func updateTransaction(_ transaction: Transaction) {
        do {
            try modelContext.save()
            fetchData()
            processRecurringTransactions()
        } catch {
            print("Error updating transaction: \(error)")
        }
    }
    
    public func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
            fetchData()
        } catch {
            print("Error deleting transaction: \(error)")
        }
    }
    
    // MARK: - Recurring System Logic
    /// 반복 지출 체크 시, 다음 달 동일 날짜에 내역을 자동 생성하는 로직
    public func processRecurringTransactions() {
        let calendar = Calendar.current
        var changesMade = false
        
        // 반복 체크되어 있고, 아직 다음 달에 적용하지 않은 트랜잭션을 필터링
        let recurringPending = transactions.filter { $0.isRecurring && !$0.isAppliedRecurring }
        
        for transaction in recurringPending {
            let originalDate = transaction.date
            
            // 다음 달 동일 날짜 계산
            var components = DateComponents()
            components.month = 1
            
            guard let nextMonthDate = calendar.date(byAdding: components, to: originalDate) else { continue }
            
            // 만약 다음 달에 동일한 일자가 존재하지 않을 경우(예: 31일인데 다음달이 30일까지인 경우), 해당 월의 마지막 날로 보정합니다.
            let originalDay = calendar.component(.day, from: originalDate)
            let nextMonthLastDay = calendar.component(.day, from: nextMonthDate.endOfMonth)
            
            var targetDate = nextMonthDate
            if originalDay > nextMonthLastDay {
                var correctionComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
                correctionComponents.day = nextMonthLastDay
                if let correctedDate = calendar.date(from: correctionComponents) {
                    targetDate = correctedDate
                }
            } else {
                var correctionComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
                correctionComponents.day = originalDay
                if let correctedDate = calendar.date(from: correctionComponents) {
                    targetDate = correctedDate
                }
            }
            
            // 중복 생성 방지를 위해 다음 달 동일 날짜에 동일 내역(금액, 카테고리, 메모가 동일한)이 이미 있는지 체크
            let isAlreadyCreated = transactions.contains { item in
                calendar.isDate(item.date, inSameDayAs: targetDate) &&
                item.amount == transaction.amount &&
                item.category == transaction.category &&
                item.memo == "[반복] " + transaction.memo
            }
            
            if !isAlreadyCreated {
                // 새로운 복제 트랜잭션 추가
                let duplicatedTransaction = Transaction(
                    date: targetDate,
                    type: transaction.type,
                    amount: transaction.amount,
                    category: transaction.category,
                    memo: "[반복] " + transaction.memo,
                    photoData: transaction.photoData,
                    isRecurring: true, // 연속 반복을 위해 true 설정
                    isAppliedRecurring: false // 다음 단계 복제를 위해 false
                )
                modelContext.insert(duplicatedTransaction)
            }
            
            // 원본 거래의 적용 완료 플래그 활성화
            transaction.isAppliedRecurring = true
            changesMade = true
        }
        
        if changesMade {
            do {
                try modelContext.save()
                // 리스트 갱신
                let transactionDescriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                self.transactions = try modelContext.fetch(transactionDescriptor)
            } catch {
                print("Error saving recurring transactions: \(error)")
            }
        }
    }
    
    // MARK: - Budget & SalaryDay Operations
    public func getMonthlyConfig(for date: Date) -> MonthlyConfig {
        let key = date.yearMonthString
        if let config = monthlyConfigs.first(where: { $0.yearMonth == key }) {
            return config
        }
        
        // 없다면 디폴트 설정 생성 (예산: 1,000,000원, 월급날: 매월 25일 기준)
        let calendar = Calendar.current
        var salaryDayComponents = calendar.dateComponents([.year, .month], from: date)
        salaryDayComponents.day = 25
        let defaultSalaryDate = calendar.date(from: salaryDayComponents) ?? date
        
        let newConfig = MonthlyConfig(yearMonth: key, salaryDay: defaultSalaryDate, budget: 1000000.0)
        modelContext.insert(newConfig)
        do {
            try modelContext.save()
            fetchData()
        } catch {
            print("Error creating monthly config: \(error)")
        }
        return newConfig
    }
    
    public func updateMonthlyConfig(yearMonth: String, budget: Double, salaryDay: Date) {
        if let config = monthlyConfigs.first(where: { $0.yearMonth == yearMonth }) {
            config.budget = budget
            config.salaryDay = salaryDay
        } else {
            let newConfig = MonthlyConfig(yearMonth: yearMonth, salaryDay: salaryDay, budget: budget)
            modelContext.insert(newConfig)
        }
        
        do {
            try modelContext.save()
            fetchData()
        } catch {
            print("Error updating monthly config: \(error)")
        }
    }
    
    public func updateTheme(_ theme: AppTheme) {
        Theme.activeTheme = theme
        if let settings = userSettings {
            settings.theme = theme
        } else {
            let settings = UserSettings(theme: theme)
            modelContext.insert(settings)
            self.userSettings = settings
        }
        
        do {
            try modelContext.save()
            fetchData()
        } catch {
            print("Error updating theme: \(error)")
        }
    }

    public func saveUserSettings() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving user settings: \(error)")
        }
    }

    public func makeBackupData() -> Data {
        let savedCategories = (try? modelContext.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        let savedAccounts = (try? modelContext.fetch(FetchDescriptor<SavingsAccount>())) ?? []
        let payload = BackupPayload(
            transactions: transactions.map {
                BackupTransaction(id: $0.id, date: $0.date, type: $0.type.rawValue, amount: $0.amount, category: $0.category.rawValue, memo: $0.memo, isRecurring: $0.isRecurring)
            },
            categories: savedCategories.map { BackupCategory(name: $0.name, iconName: $0.iconName, kind: $0.kind.rawValue) },
            savingsAccounts: savedAccounts.map { BackupSavingsAccount(name: $0.name, kind: $0.kind.rawValue, amount: $0.amount) },
            settings: userSettings.map {
                BackupSettings(theme: $0.theme.rawValue, notificationsEnabled: $0.notificationsEnabled, notificationTime: $0.notificationTime, fontName: $0.fontName, calendarStartWeekday: $0.calendarStartWeekday, showYearlyTotal: $0.showYearlyTotal)
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }

    public func restoreBackup(from data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else { return }

        for transaction in transactions { modelContext.delete(transaction) }
        if let savedCategories = try? modelContext.fetch(FetchDescriptor<CategoryDefinition>()) {
            for category in savedCategories { modelContext.delete(category) }
        }
        if let savedAccounts = try? modelContext.fetch(FetchDescriptor<SavingsAccount>()) {
            for account in savedAccounts { modelContext.delete(account) }
        }
        for category in payload.categories {
            guard let kind = ManagedCategoryKind(rawValue: category.kind) else { continue }
            modelContext.insert(CategoryDefinition(name: category.name, iconName: category.iconName, kind: kind))
        }
        for account in payload.savingsAccounts {
            guard let kind = SavingsAccountKind(rawValue: account.kind) else { continue }
            modelContext.insert(SavingsAccount(name: account.name, kind: kind, amount: account.amount))
        }
        for transaction in payload.transactions {
            guard let type = TransactionType(rawValue: transaction.type), let category = CategoryType(rawValue: transaction.category) else { continue }
            modelContext.insert(Transaction(id: transaction.id, date: transaction.date, type: type, amount: transaction.amount, category: category, memo: transaction.memo, isRecurring: transaction.isRecurring))
        }
        if let backupSettings = payload.settings, let settings = userSettings {
            settings.theme = AppTheme(rawValue: backupSettings.theme) ?? .system
            settings.notificationsEnabled = backupSettings.notificationsEnabled
            settings.notificationTime = backupSettings.notificationTime
            settings.fontName = backupSettings.fontName
            settings.calendarStartWeekday = backupSettings.calendarStartWeekday
            settings.showYearlyTotal = backupSettings.showYearlyTotal
        }
        do {
            try modelContext.save()
            fetchData()
        } catch {
            print("Error restoring backup: \(error)")
        }
    }
    
    // MARK: - Financial Calculations (for the target date's month)
    
    // 지정된 달의 트랜잭션 필터
    public func transactions(for date: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
    }
    
    // 특정 날짜의 트랜잭션 필터
    public func transactions(on date: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    // 이번 달 지출 총액 (고정 지출 포함한 모든 지출)
    public func totalExpense(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .expense || $0.type == .fixedExpense }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 이번 달 수입 총액
    public func totalIncome(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 고정 지출 내역 합계
    public func totalFixedExpense(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .fixedExpense }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 이번 달 저축액 (수입 총액 - 지출 총액)
    public func savings(for date: Date) -> Double {
        totalIncome(for: date) - totalExpense(for: date)
    }
    
    // 월간 누적 합계 (순자산 증감 수입 - 지출)
    public func cumulativeMonthlySum(for date: Date) -> Double {
        return savings(for: date)
    }
    
    // 연간 합계 (해당 년도의 모든 수입 - 지출)
    public func yearlySum(for date: Date) -> Double {
        let calendar = Calendar.current
        let yearTransactions = transactions.filter { calendar.component(.year, from: $0.date) == calendar.component(.year, from: date) }
        let income = yearTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = yearTransactions.filter { $0.type == .expense || $0.type == .fixedExpense }.reduce(0) { $0 + $1.amount }
        return income - expense
    }
    
    // 월급날(기준일)과 예산을 바탕으로 이번 달 예산 대비 현재 지출률 계산
    // 기준일 정산 주기(예: 8/25 ~ 9/24)에 발생한 지출 총합과 이번 달 예산 비교
    public func budgetProgress(for date: Date) -> Double {
        let config = getMonthlyConfig(for: date)
        let salaryDayNumber = Calendar.current.component(.day, from: config.salaryDay)
        
        let period = Date.budgetPeriod(for: date, salaryDayNumber: salaryDayNumber)
        
        // 정산 주기에 해당하는 지출 합산
        let periodExpenses = transactions.filter {
            $0.date >= period.start && $0.date <= period.end && ($0.type == .expense || $0.type == .fixedExpense)
        }.reduce(0) { $0 + $1.amount }
        
        guard config.budget > 0 else { return 0.0 }
        return periodExpenses / config.budget
    }
    
    // 정산 주기 내 발생한 실제 지출 총합
    public func periodExpenseSum(for date: Date) -> Double {
        let config = getMonthlyConfig(for: date)
        let salaryDayNumber = Calendar.current.component(.day, from: config.salaryDay)
        let period = Date.budgetPeriod(for: date, salaryDayNumber: salaryDayNumber)
        
        return transactions.filter {
            $0.date >= period.start && $0.date <= period.end && ($0.type == .expense || $0.type == .fixedExpense)
        }.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - OCR Batch Import
    public func saveOcrCheckedTransactions(ocrItems: [OcrTempItem]) {
        for item in ocrItems where item.isChecked {
            addTransaction(
                date: item.date,
                type: item.type,
                amount: item.amount,
                category: item.category,
                memo: item.memo
            )
        }
    }
}

// OCR 일시 저장용 아이템 구조체
public struct OcrTempItem: Identifiable, Equatable {
    public let id: UUID
    public var isChecked: Bool = true
    public var date: Date
    public var type: TransactionType
    public var amount: Double
    public var category: CategoryType
    public var memo: String
    
    public init(
        id: UUID = UUID(),
        date: Date,
        type: TransactionType,
        amount: Double,
        category: CategoryType,
        memo: String
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.amount = amount
        self.category = category
        self.memo = memo
    }
}

import Foundation
import SwiftData
import SwiftUI

public enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case pink = "Pink"
    case blackPink = "BlackPink"
    
    public var id: String { self.rawValue }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .pink: return .light
        case .blackPink: return .dark
        }
    }
}

@Model
public final class UserSettings {
    public var id: UUID = UUID()
    private var themeRawValue: String
    public var notificationsEnabled: Bool = true
    public var notificationTime: Date = Calendar.current.date(from: DateComponents(hour: 0, minute: 0)) ?? Date()
    public var fontName: String = AppFontStyle.system.rawValue
    public var calendarStartWeekday: Int = 1
    public var showYearlyTotal: Bool = true
    public var screenLockEnabled: Bool = false
    public var biometricEnabled: Bool = true
    public var iCloudSyncEnabled: Bool = true
    
    // Default initial settings
    public init(theme: AppTheme = .system) {
        self.themeRawValue = theme.rawValue
    }
    
    public var theme: AppTheme {
        get {
            AppTheme(rawValue: themeRawValue) ?? .system
        }
        set {
            themeRawValue = newValue.rawValue
        }
    }
}

public enum ManagedCategoryKind: String, Codable, CaseIterable, Identifiable {
    case expense = "지출"
    case income = "수입"

    public var id: String { rawValue }
}

@Model
public final class CategoryDefinition {
    public var id: UUID = UUID()
    public var name: String
    public var iconName: String
    @Attribute(.externalStorage) public var photoData: Data?
    private var kindRawValue: String

    public init(name: String, iconName: String, kind: ManagedCategoryKind = .expense, photoData: Data? = nil) {
        self.name = name
        self.iconName = iconName
        self.kindRawValue = kind.rawValue
        self.photoData = photoData
    }

    public var kind: ManagedCategoryKind {
        get { ManagedCategoryKind(rawValue: kindRawValue) ?? .expense }
        set { kindRawValue = newValue.rawValue }
    }
}

public enum SavingsAccountKind: String, Codable, CaseIterable, Identifiable {
    case deposit = "예금"
    case installment = "적금"
    case emergency = "비상금"
    case investment = "투자"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .deposit: return "building.columns.fill"
        case .installment: return "banknote.fill"
        case .emergency: return "envelope.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        }
    }
}

@Model
public final class SavingsAccount {
    public var id: UUID = UUID()
    public var name: String
    private var kindRawValue: String
    public var amount: Double

    public init(name: String, kind: SavingsAccountKind, amount: Double) {
        self.name = name
        self.kindRawValue = kind.rawValue
        self.amount = amount
    }

    public var kind: SavingsAccountKind {
        get { SavingsAccountKind(rawValue: kindRawValue) ?? .deposit }
        set { kindRawValue = newValue.rawValue }
    }
}

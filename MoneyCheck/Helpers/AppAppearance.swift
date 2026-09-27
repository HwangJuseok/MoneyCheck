import SwiftUI
import UIKit
import Combine

public final class ThemeManager: ObservableObject {
    @Published public private(set) var theme: AppTheme
    @Published public private(set) var fontName: String

    public init(theme: AppTheme = .system, fontName: String = AppFontStyle.system.rawValue) {
        self.theme = theme
        self.fontName = fontName
        Theme.activeTheme = theme
    }

    public func apply(theme: AppTheme) {
        self.theme = theme
        Theme.activeTheme = theme
    }

    public func apply(fontName: String) {
        self.fontName = fontName
    }
}

public enum AppFontStyle: String, CaseIterable, Identifiable {
    case system = "시스템 폰트"
    case serif = "명조체"
    case rounded = "둥근 고딕"
    case monospaced = "고정폭 폰트"
    case caption = "얇은 캡션"

    public var id: String { rawValue }

    public var font: Font {
        switch self {
        case .system: return .body
        case .serif: return registeredFont(family: "Georgia", fallback: .system(.body, design: .serif))
        case .rounded: return registeredFont(family: "Avenir Next", fallback: .system(.body, design: .rounded))
        case .monospaced: return registeredFont(family: "Menlo", fallback: .system(.body, design: .monospaced))
        case .caption: return registeredFont(family: "Helvetica Neue", fallback: .system(.body, weight: .light))
        }
    }

    private func registeredFont(family: String, fallback: Font) -> Font {
        UIFont.familyNames.contains(family) ? .custom(family, size: 17) : fallback
    }
}

public extension Color {
    static var appBackground: Color {
        Theme.backgroundColor
    }

    static var appSurface: Color {
        Theme.cardBackgroundColor
    }

    static var appPrimary: Color { Theme.primaryTextColor }
    static var appSecondary: Color { Theme.secondaryTextColor }
    static var appDivider: Color { appSecondary.opacity(0.22) }
}

public enum Theme {
    public static var activeTheme: AppTheme = .system

    public static var backgroundColor: Color {
        switch activeTheme {
        case .pink: return Color(red: 1.0, green: 0.961, blue: 0.969)
        case .blackPink: return .black
        case .dark: return Color(red: 0.17, green: 0.18, blue: 0.20)
        case .system, .light: return Color(red: 0.97, green: 0.95, blue: 0.90)
        }
    }

    public static var cardBackgroundColor: Color {
        switch activeTheme {
        case .pink, .light: return .white
        case .blackPink: return Color(red: 0.094, green: 0.094, blue: 0.11)
        case .system: return Color(red: 0.92, green: 0.89, blue: 0.83)
        case .dark: return Color(red: 0.23, green: 0.24, blue: 0.27)
        }
    }

    public static var primaryTextColor: Color {
        activeTheme == .pink ? Color(red: 0.173, green: 0.102, blue: 0.173) : activeTheme == .blackPink ? .white : Color(uiColor: .label)
    }

    public static var secondaryTextColor: Color {
        activeTheme == .pink ? Color(red: 0.541, green: 0.482, blue: 0.549) : activeTheme == .blackPink ? Color(red: 0.62, green: 0.55, blue: 0.60) : Color(uiColor: .secondaryLabel)
    }

    public static var accentColor: Color {
        activeTheme == .pink ? Color(red: 1.0, green: 0.42, blue: 0.545) : activeTheme == .blackPink ? Color(red: 1.0, green: 0.09, blue: 0.47) : .blue
    }

    public static var secondaryAccentColor: Color {
        activeTheme == .pink ? Color(red: 1.0, green: 0.718, blue: 0.773) : activeTheme == .blackPink ? Color(red: 1.0, green: 0.522, blue: 0.702) : .blue.opacity(0.7)
    }
}

public extension BudgetViewModel {
    var appFont: Font {
        AppFontStyle(rawValue: userSettings?.fontName ?? AppFontStyle.system.rawValue)?.font ?? AppFontStyle.system.font
    }
}

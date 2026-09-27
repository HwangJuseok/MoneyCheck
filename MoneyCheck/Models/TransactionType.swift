import Foundation
import SwiftUI

public enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income = "수입"
    case expense = "지출"
    case fixedExpense = "고정 지출"
    
    public var id: String { self.rawValue }
    
    public var color: Color {
        if Theme.activeTheme == .pink {
            switch self {
            case .income: return Theme.secondaryAccentColor
            case .expense: return Theme.accentColor
            case .fixedExpense: return Theme.accentColor.opacity(0.78)
            }
        }
        switch self {
        case .income:
            return .blue
        case .expense:
            return .red
        case .fixedExpense:
            return .orange
        }
    }
}

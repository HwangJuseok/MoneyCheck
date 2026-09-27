import Foundation
import SwiftUI

public enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case food = "식비"
    case transport = "교통/차량"
    case medical = "의료비"
    case culture = "문화생활"
    case mart = "마트/생필품"
    case education = "교육"
    case subscription = "구독비"
    case salary = "월급" // 수입용 기본 카테고리
    case bonus = "보너스"  // 수입용 기본 카테고리
    case etc = "기타"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .medical: return "heart.text.square.fill"
        case .culture: return "popcorn.fill"
        case .mart: return "cart.fill"
        case .education: return "book.closed.fill"
        case .subscription: return "creditcard.and.123"
        case .salary: return "wonsign.circle.fill"
        case .bonus: return "gift.fill"
        case .etc: return "ellipsis.circle.fill"
        }
    }
    
    public var color: Color {
        if Theme.activeTheme == .pink {
            switch self {
            case .transport, .salary, .education: return Theme.secondaryAccentColor
            case .food, .bonus: return Theme.accentColor
            case .medical, .culture: return Theme.accentColor.opacity(0.82)
            case .mart, .subscription: return Theme.accentColor.opacity(0.62)
            case .etc: return Theme.secondaryTextColor
            }
        }
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .medical: return .red
        case .culture: return .purple
        case .mart: return .green
        case .education: return .teal
        case .subscription: return .indigo
        case .salary: return .emerald
        case .bonus: return .pink
        case .etc: return .gray
        }
    }
}

// Color extension to support standard iOS colors nicely
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
}

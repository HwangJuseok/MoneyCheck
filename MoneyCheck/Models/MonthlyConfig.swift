import Foundation
import SwiftData

@Model
public final class MonthlyConfig {
    @Attribute(.unique) public var yearMonth: String // Format: "yyyy-MM" (e.g. "2026-09")
    public var salaryDay: Date
    public var budget: Double
    
    public init(yearMonth: String, salaryDay: Date, budget: Double) {
        self.yearMonth = yearMonth
        self.salaryDay = salaryDay
        self.budget = budget
    }
}

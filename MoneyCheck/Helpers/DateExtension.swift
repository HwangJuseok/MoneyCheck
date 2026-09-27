import Foundation

extension Date {
    public var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    public var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    public var day: Int {
        Calendar.current.component(.day, from: self)
    }
    
    public var yearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
    
    public var koreanYearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월"
        return formatter.string(from: self)
    }
    
    public var koreanDateAndWeekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 eeee"
        return formatter.string(from: self)
    }
    
    public var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self)))!
    }
    
    public var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth)!
    }
    
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    public var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: self.startOfDay)!
    }
    
    // 캘린더 화면용 그리드 날짜들 생성 (일~토 그리드)
    public func generateCalendarDates(startingWeekday: Int = 1) -> [Date] {
        let calendar = Calendar.current
        let start = self.startOfMonth
        let end = self.endOfMonth
        
        let monthWeekday = calendar.component(.weekday, from: start)
        let daysToSubtract = (monthWeekday - startingWeekday + 7) % 7
        
        guard let calendarStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: start) else { return [] }
        
        var dates: [Date] = []
        var currentDate = calendarStart
        
        // 6주 분량(42일)을 표시하여 캘린더 크기를 항상 일정하게 유지
        for _ in 0..<42 {
            dates.append(currentDate)
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }
        return dates
    }
    
    // 월급날(Date) 기준으로 해당 날짜가 속한 정산 기간(Start, End)을 반환합니다.
    // 예: 월급날이 25일이고 타겟 날짜가 9월 16일이면, 기간은 8월 25일 ~ 9월 24일입니다.
    // 월급날이 25일이고 타겟 날짜가 9월 28일이면, 기간은 9월 25일 ~ 10월 24일입니다.
    public static func budgetPeriod(for targetDate: Date, salaryDayNumber: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.component(.day, from: targetDate)
        
        var startComponents = calendar.dateComponents([.year, .month], from: targetDate)
        startComponents.day = salaryDayNumber
        
        guard var baseSalaryDate = calendar.date(from: startComponents) else {
            return (targetDate.startOfMonth, targetDate.endOfMonth)
        }
        
        // 만약 해당 월에 그 날짜가 없다면(예: 31일인데 2월인 경우) 해당 월의 마지막 날로 보정
        if calendar.component(.month, from: baseSalaryDate) != targetDate.month {
            baseSalaryDate = targetDate.endOfMonth
        }
        
        var startDate: Date
        var endDate: Date
        
        if targetDay >= salaryDayNumber {
            // 이번 달 월급날 이후 -> 이번 달 월급날 ~ 다음 달 월급날 전날
            startDate = baseSalaryDate
            
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.day = -1
            endDate = calendar.date(byAdding: endComponents, to: startDate) ?? targetDate.endOfMonth
        } else {
            // 이번 달 월급날 이전 -> 지난 달 월급날 ~ 이번 달 월급날 전날
            var prevComponents = DateComponents()
            prevComponents.month = -1
            let prevMonthDate = calendar.date(byAdding: prevComponents, to: targetDate) ?? targetDate
            
            var prevSalaryComponents = calendar.dateComponents([.year, .month], from: prevMonthDate)
            prevSalaryComponents.day = salaryDayNumber
            startDate = calendar.date(from: prevSalaryComponents) ?? targetDate.startOfMonth
            
            if calendar.component(.month, from: startDate) != prevMonthDate.month {
                startDate = prevMonthDate.endOfMonth
            }
            
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.day = -1
            endDate = calendar.date(byAdding: endComponents, to: startDate) ?? targetDate.endOfMonth
        }
        
        return (startDate.startOfDay, endDate.endOfDay)
    }
}

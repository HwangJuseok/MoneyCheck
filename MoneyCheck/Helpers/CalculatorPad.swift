import SwiftUI

public struct CalculatorPad: View {
    @Binding public var isPresented: Bool
    @Binding public var amount: Double
    @State private var expression: String = ""
    @State private var displayText: String = "0"
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public init(isPresented: Binding<Bool>, amount: Binding<Double>) {
        self._isPresented = isPresented
        self._amount = amount
        // 시작 시 기존 금액 표시
        self._displayText = State(initialValue: amount.wrappedValue > 0 ? String(Int(amount.wrappedValue)) : "0")
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 상단 인디케이터 바
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // 디스플레이 영역
            VStack(alignment: .trailing, spacing: 4) {
                if !expression.isEmpty {
                    Text(expression)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                HStack {
                    Text(formatDisplayNumber(displayText))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("원")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            
            // 키패드 그리드
            LazyVGrid(columns: columns, spacing: 12) {
                // 첫번째 줄
                keyButton("C", color: .red.opacity(0.15), textColor: .red) { clear() }
                keyButton("÷", color: .orange.opacity(0.15), textColor: .orange) { addOperator("/") }
                keyButton("×", color: .orange.opacity(0.15), textColor: .orange) { addOperator("*") }
                keyButton("⌫", color: .gray.opacity(0.15), textColor: .primary) { backspace() }
                
                // 두번째 줄
                keyButton("7") { appendNumber("7") }
                keyButton("8") { appendNumber("8") }
                keyButton("9") { appendNumber("9") }
                keyButton("−", color: .orange.opacity(0.15), textColor: .orange) { addOperator("-") }
                
                // 세번째 줄
                keyButton("4") { appendNumber("4") }
                keyButton("5") { appendNumber("5") }
                keyButton("6") { appendNumber("6") }
                keyButton("+", color: .orange.opacity(0.15), textColor: .orange) { addOperator("+") }
                
                // 네번째 줄
                keyButton("1") { appendNumber("1") }
                keyButton("2") { appendNumber("2") }
                keyButton("3") { appendNumber("3") }
                keyButton("=", color: .orange, textColor: .white) { calculate() }
                
                // 다섯번째 줄
                keyButton("0", span: 2) { appendNumber("0") }
                keyButton("00") { appendNumber("00") }
                keyButton("입력 완료", color: .blue, textColor: .white, span: 1) {
                    calculate()
                    amount = Double(displayText) ?? 0.0
                    isPresented = false
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(radius: 10)
    }
    
    // 버튼 템플릿
    @ViewBuilder
    private func keyButton(
        _ text: String,
        color: Color = Color(.quaternarySystemFill),
        textColor: Color = .primary,
        span: Int = 1,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(color)
                .cornerRadius(12)
        }
        .gridCellColumns(span)
    }
    
    // MARK: - 계산기 로직
    private func appendNumber(_ num: String) {
        if displayText == "0" && num != "00" {
            displayText = num
        } else if displayText == "0" && num == "00" {
            // 아무것도 안함
        } else {
            displayText += num
        }
    }
    
    private func addOperator(_ op: String) {
        calculate() // 현재 입력되던 값 먼저 반영
        expression = displayText + " " + op + " "
        displayText = "0"
    }
    
    private func backspace() {
        if displayText.count > 1 {
            displayText.removeLast()
        } else {
            displayText = "0"
        }
    }
    
    private func clear() {
        displayText = "0"
        expression = ""
    }
    
    private func calculate() {
        guard !expression.isEmpty else { return }
        
        let components = expression.split(separator: " ")
        guard components.count >= 2 else { return }
        
        let firstVal = Double(components[0]) ?? 0.0
        let op = String(components[1])
        let secondVal = Double(displayText) ?? 0.0
        
        var result: Double = 0.0
        
        switch op {
        case "+": result = firstVal + secondVal
        case "-": result = firstVal - secondVal
        case "*": result = firstVal * secondVal
        case "/": result = secondVal != 0 ? firstVal / secondVal : 0
        default: result = secondVal
        }
        
        // 정수면 소수점 제거
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            displayText = String(Int(result))
        } else {
            displayText = String(format: "%.1f", result)
        }
        
        expression = ""
    }
    
    private func formatDisplayNumber(_ val: String) -> String {
        guard let num = Double(val) else { return val }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? val
    }
}

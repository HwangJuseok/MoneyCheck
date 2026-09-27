import Foundation
import CoreGraphics

public struct ParsedOCRResult: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let amount: Double
    public let merchant: String
    public let type: TransactionType
    public let category: CategoryType
    public init(date: Date, amount: Double, merchant: String, type: TransactionType, category: CategoryType) { self.date = date; self.amount = amount; self.merchant = merchant; self.type = type; self.category = category }
}

public final class OCRParserService {
    private struct Candidate { let value: Double; let x: CGFloat; let y: CGFloat; let height: CGFloat; let text: String; let currency: Bool; let keyword: Bool; let signed: Bool }
    private let threshold: CGFloat = 0.035
    private let keywords = ["합계", "결제금액", "승인금액", "총액", "일시불", "원", "₩", "total", "amount", "payment"]
    public init() {}

    public func parse(lines: [OCRLine], defaultDate: Date = Date()) -> [ParsedOCRResult] {
        let ordered = lines.filter { $0.boundingBox.midY > 0.08 && $0.boundingBox.midY < 0.92 }.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[OCRLine]] = []
        for line in ordered {
            if let index = rows.firstIndex(where: { abs(($0.first?.boundingBox.midY ?? 0) - line.boundingBox.midY) <= threshold }) { rows[index].append(line) } else { rows.append([line]) }
        }
        rows = mergeVerticalAmountRows(rows.map { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } })
        let results = rows.compactMap { parseRow($0, defaultDate: defaultDate) }
        return results.isEmpty ? parseReceipt(ordered, defaultDate: defaultDate) : results
    }

    private func parseRow(_ row: [OCRLine], defaultDate: Date) -> ParsedOCRResult? {
        let rowHeight = row.map { $0.boundingBox.height }.max() ?? 0
        let candidates = row.flatMap(candidates(in:)).filter {
            $0.x >= 0.42 && !isTimeOrDate($0.value, text: $0.text) && (rowHeight == 0 || $0.height >= rowHeight * 0.55)
        }
        guard let candidate = candidates.max(by: { score($0) < score($1) }) else { return nil }
        return makeResult(text: row.map(\.text).joined(separator: " "), amount: candidate.value, lines: row, defaultDate: defaultDate)
    }

    private func mergeVerticalAmountRows(_ rows: [[OCRLine]]) -> [[OCRLine]] {
        var merged: [[OCRLine]] = []
        for row in rows {
            let amountLines = row.filter { !candidates(in: $0).isEmpty && $0.boundingBox.minX > 0.5 }
            let isNumericRightRow = !amountLines.isEmpty && row.allSatisfy { line in
                line.boundingBox.minX > 0.5 || !merchantText(line.text)
            }
            if isNumericRightRow, let previousIndex = merged.indices.last,
               let previousLine = merged[previousIndex].first,
               previousLine.boundingBox.midY - (row.first?.boundingBox.midY ?? 0) < 0.14 {
                merged[previousIndex].append(contentsOf: row)
            } else {
                merged.append(row)
            }
        }
        return merged
    }

    private func parseReceipt(_ lines: [OCRLine], defaultDate: Date) -> [ParsedOCRResult] {
        let text = lines.map(\.text).joined(separator: " ")
        guard let candidate = lines.flatMap(candidates(in:)).filter({ !isTimeOrDate($0.value, text: $0.text) }).max(by: { score($0) < score($1) }) else { return [] }
        return [makeResult(text: text, amount: candidate.value, lines: lines, defaultDate: defaultDate)]
    }

    private func makeResult(text: String, amount: Double, lines: [OCRLine], defaultDate: Date) -> ParsedOCRResult {
        let normalized = text.lowercased()
        let income = ["입금", "수입", "급여", "월급", "보너스", "income", "deposit", "credit"].contains { normalized.contains($0) }
        let type: TransactionType = income ? .income : .expense
        let merchant = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }.map(\.text).first { merchantText($0) && candidates(in: OCRLine(text: $0, confidence: 1, boundingBox: .zero)).isEmpty && parseDate($0, defaultDate: defaultDate) == nil } ?? "인식된 거래"
        return ParsedOCRResult(date: parseDate(text, defaultDate: defaultDate) ?? defaultDate, amount: amount, merchant: String(merchant.prefix(80)), type: type, category: category(normalized, type: type))
    }

    private func merchantText(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [#"^\d{1,2}:\d{2}$"#, #"^\d{1,2}[./-]\d{1,2}$"#, #"^LTE$"#, #"^\d{1,3}%$"#]
        return !patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
            return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
    }

    private func candidates(in line: OCRLine) -> [Candidate] {
        let pattern = #"(?<!\d)([+-]?)(?:₩\s*)?(\d{1,3}(?:,\d{3})+|\d{3,})(?:\s*원)?(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)).compactMap { match in
            guard let signRange = Range(match.range(at: 1), in: line.text), let range = Range(match.range(at: 2), in: line.text), let value = Double(line.text[range].replacingOccurrences(of: ",", with: "")), value > 0, value < 100_000_000, line.text[range].count != 10 else { return nil }
            let prefix = String(line.text[..<signRange.lowerBound])
            let hasCurrency = prefix.contains("₩") || line.text[range.upperBound...].contains("원")
            let hasKeyword = keywords.contains { line.text.lowercased().contains($0.lowercased()) }
            let x = line.boundingBox.minX + CGFloat(match.range.location) / CGFloat(max(line.text.utf8.count, 1)) * line.boundingBox.width
            return Candidate(value: value, x: x, y: line.boundingBox.midY, height: line.boundingBox.height, text: line.text, currency: hasCurrency, keyword: hasKeyword, signed: !line.text[signRange].isEmpty)
        }
    }

    private func score(_ candidate: Candidate) -> Int { Int(candidate.y * 500) + Int(candidate.height * 300) + Int(min(candidate.value / 1000, 80)) + (candidate.signed ? 220 : 0) + (candidate.currency ? 100 : 0) + (candidate.keyword ? 80 : 0) + (candidate.x > 0.65 ? 25 : 0) }
    private func isTimeOrDate(_ value: Double, text: String) -> Bool { if let regex = try? NSRegularExpression(pattern: #"(^|\s)\d{1,2}[:.]\d{2}($|\s)"#), regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil { return true }; let number = Int(value); return number >= 19000101 && number <= 20991231 }

    private func parseDate(_ text: String, defaultDate: Date) -> Date? {
        let patterns = [#"(20\d{2}|\d{2})[.\-/년]\s*(\d{1,2})[.\-/월]\s*(\d{1,2})"#, #"(\d{1,2})/(\d{1,2})\s*\d{1,2}:\d{2}"#]
        for pattern in patterns { guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { continue }; let values = (1..<match.numberOfRanges).compactMap { index -> Int? in guard let range = Range(match.range(at: index), in: text) else { return nil }; return Int(text[range]) }; guard values.count >= 2 else { continue }; var components = DateComponents(); if values.count == 3 { components.year = values[0] < 100 ? values[0] + 2000 : values[0]; components.month = values[1]; components.day = values[2] } else { components.year = Calendar.current.component(.year, from: defaultDate); components.month = values[0]; components.day = values[1] }; if let date = Calendar.current.date(from: components) { return date } }; return nil
    }

    private func category(_ text: String, type: TransactionType) -> CategoryType { if type == .income { return text.contains("월급") || text.contains("급여") ? .salary : text.contains("보너스") ? .bonus : .etc }; if text.contains("카페") || text.contains("식당") || text.contains("커피") { return .food }; if text.contains("택시") || text.contains("버스") || text.contains("주유") { return .transport }; if text.contains("병원") || text.contains("약국") { return .medical }; if text.contains("마트") || text.contains("편의점") { return .mart }; if text.contains("구독") { return .subscription }; return .etc }
}

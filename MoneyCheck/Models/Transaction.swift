import Foundation
import SwiftData

@Model
public final class Transaction {
    public var id: UUID = UUID()
    public var date: Date
    private var typeRawValue: String
    public var amount: Double
    private var categoryRawValue: String
    public var memo: String
    @Attribute(.externalStorage) public var photoData: Data?
    public var isRecurring: Bool
    public var isAppliedRecurring: Bool // 다음달 내역이 자동 생성되었는지 여부
    
    public init(
        id: UUID = UUID(),
        date: Date,
        type: TransactionType,
        amount: Double,
        category: CategoryType,
        memo: String,
        photoData: Data? = nil,
        isRecurring: Bool = false,
        isAppliedRecurring: Bool = false
    ) {
        self.id = id
        self.date = date
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.categoryRawValue = category.rawValue
        self.memo = memo
        self.photoData = photoData
        self.isRecurring = isRecurring
        self.isAppliedRecurring = isAppliedRecurring
    }
    
    // Enum wrapper computed properties for safety & convenience in SwiftData
    public var type: TransactionType {
        get {
            TransactionType(rawValue: typeRawValue) ?? .expense
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }
    
    public var category: CategoryType {
        get {
            CategoryType(rawValue: categoryRawValue) ?? .etc
        }
        set {
            categoryRawValue = newValue.rawValue
        }
    }
}

import SwiftUI

public struct CircularBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.primaryTextColor)
                .frame(width: 44, height: 44)
                .background(Theme.cardBackgroundColor)
                .clipShape(Circle())
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("뒤로")
    }
}

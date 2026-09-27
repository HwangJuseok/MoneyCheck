import SwiftUI

public struct DetailHeader: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 0) {
            CircularBackButton(action: action)
            Spacer()
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Theme.primaryTextColor)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.backgroundColor)
    }
}

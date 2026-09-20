//
//  SwiftUISupport.swift
//  TrueType
//
//  SwiftUI 侧的接入支持。
//
//  说明：
//  - 对「UIKit 承载 SwiftUI」的架构，swizzle 已让宿主 trait 固定，
//    SwiftUI 会自动继承，通常无需额外代码。
//  - 对「纯 SwiftUI App（@main App）」，SwiftUI 无法被全局 swizzle 拦截，
//    因此提供 `.blockDynamicType()`：在根视图注入固定的 `sizeCategory`
//    环境值，一行接入即可，并会随全局开关实时刷新。
//

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// 把全局屏蔽配置桥接到 SwiftUI 的 `\.sizeCategory` 环境值上。
///
/// 该 modifier 会订阅 `DynamicTypeBlocker.didChangeNotification`，
/// 在开关或档位变化时自动更新，无需手动刷新。
@available(iOS 14.0, tvOS 14.0, *)
public struct BlockDynamicTypeModifier: ViewModifier {

    @State private var isEnabled: Bool = MainActor.assumeIsolated { DynamicTypeBlocker.shared.isEnabled }
    @State private var category: UIContentSizeCategory = MainActor.assumeIsolated { DynamicTypeBlocker.shared.fixedCategory }

    public init() {}

    public func body(content: Content) -> some View {
        content
            .modifier(ApplySizeCategory(isEnabled: isEnabled, category: category))
            .onReceive(NotificationCenter.default.publisher(for: DynamicTypeBlocker.didChangeNotification)) { _ in
                let blocker = DynamicTypeBlocker.shared
                isEnabled = blocker.isEnabled
                category = blocker.fixedCategory
            }
    }
}

/// 根据是否启用，选择性地覆盖 `sizeCategory`。
@available(iOS 14.0, tvOS 14.0, *)
private struct ApplySizeCategory: ViewModifier {
    let isEnabled: Bool
    let category: UIContentSizeCategory

    func body(content: Content) -> some View {
        if isEnabled, let swiftUISize = ContentSizeCategory(uiContentSizeCategory: category) {
            content.environment(\.sizeCategory, swiftUISize)
        } else {
            content
        }
    }
}

@available(iOS 14.0, tvOS 14.0, *)
public extension View {
    /// 在纯 SwiftUI App 的根视图上调用一次，即可让整棵视图树屏蔽
    /// Dynamic Type，并跟随 `DynamicTypeBlocker` 的全局开关。
    ///
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .blockDynamicType()
    /// }
    /// ```
    func blockDynamicType() -> some View {
        modifier(BlockDynamicTypeModifier())
    }
}

// MARK: - UIContentSizeCategory -> SwiftUI ContentSizeCategory 映射

@available(iOS 14.0, tvOS 14.0, *)
private extension ContentSizeCategory {
    /// 把 UIKit 的档位映射为 SwiftUI 的档位。无法映射时返回 nil。
    init?(uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: return nil
        }
    }
}
#endif

//
//  DynamicTypeBlocker.swift
//  TrueType
//
//  屏蔽 iOS Dynamic Type（UIContentSizeCategory）的全局配置入口。
//
//  设计目标：
//  - 引入即生效：库在加载时自动完成 UIKit 的运行时挂钩（swizzle），
//    默认把界面的 contentSizeCategory 固定到系统默认档（.large）。
//  - 暴露开关：宿主 App 可在任意设置页读写 `DynamicTypeBlocker.shared`
//    的 `isEnabled` / `fixedCategory`，运行时切换会实时刷新界面。
//

#if canImport(UIKit)
import UIKit

/// 屏蔽 Dynamic Type 的全局配置对象。
///
/// 这是一个进程级单例，宿主 App 通过它来开关屏蔽行为、
/// 或调整被固定到的字号档位。所有属性都必须在主线程访问。
@MainActor
public final class DynamicTypeBlocker {

    /// 全局唯一实例。
    public static let shared = DynamicTypeBlocker()

    /// 当配置发生变化时发出的通知。SwiftUI / UIKit 侧监听它以触发刷新。
    public static let didChangeNotification = Notification.Name("TrueType.DynamicTypeBlocker.didChange")

    /// 是否启用屏蔽。默认为 `true`（引入即生效）。
    ///
    /// 设为 `false` 时，界面恢复跟随系统 Dynamic Type 设置。
    public var isEnabled: Bool = true {
        didSet {
            guard oldValue != isEnabled else { return }
            notifyChange()
        }
    }

    /// 屏蔽启用时，界面被固定到的字号档位。
    ///
    /// 默认 `.large`，即系统滑块处于中间默认位置时的档位，
    /// 也是 Apple 设计规范里绝大多数 UI 的基准尺寸。
    public var fixedCategory: UIContentSizeCategory = .large {
        didSet {
            guard oldValue != fixedCategory else { return }
            notifyChange()
        }
    }

    private init() {}

    /// 当前应当应用到界面上的字号档位。
    ///
    /// - 启用屏蔽时返回 `fixedCategory`；
    /// - 关闭屏蔽时返回 `nil`，表示不覆盖、跟随系统。
    var effectiveCategory: UIContentSizeCategory? {
        isEnabled ? fixedCategory : nil
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        refreshAllWindows()
    }

    /// 强制刷新所有已连接窗口，使配置变更立即可见。
    private func refreshAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                // 触发 traitCollection 重算与子树刷新。
                window.setNeedsLayout()
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
                window.subviews.forEach { $0.tt_refreshContentSizeCategory() }
                window.tt_refreshContentSizeCategory()
            }
        }
    }
}
#endif

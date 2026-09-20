//
//  DynamicTypeSwizzling.swift
//  TrueType
//
//  UIKit 侧的运行时挂钩：在库加载时自动交换 `traitCollection` 的实现，
//  使 `preferredContentSizeCategory` 被强制固定，从而屏蔽 Dynamic Type。
//
//  为什么 swizzle `traitCollection`：
//  UIKit 里所有字体缩放最终都取自当前 `UITraitCollection` 的
//  `preferredContentSizeCategory`。承载在 UIKit 里的 SwiftUI 也从宿主
//  的 trait 继承 `sizeCategory`。因此只要在 trait 源头覆盖这个值，
//  UIKit 与混合架构下的界面都会被固定。
//

#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime

/// 负责运行时挂钩的安装。`installIfNeeded()` 幂等，可重复调用。
///
/// 标注 `@MainActor`：swizzle 涉及 UIKit 类的方法表修改，必须在主线程执行，
/// 同时也让 `hasInstalled` 状态受主线程隔离保护。
@MainActor
enum DynamicTypeSwizzler {

    private static var hasInstalled = false

    /// 安装所有需要的 swizzle。只在首次调用时真正执行。
    static func installIfNeeded() {
        guard !hasInstalled else { return }
        hasInstalled = true

        swizzleTraitCollection(on: UIView.self)
        swizzleTraitCollection(on: UIViewController.self)
        swizzleTraitCollection(on: UIScreen.self)
    }

    /// 交换指定类的 `traitCollection` getter。
    ///
    /// 新实现会调用原实现拿到系统 trait，再用固定的
    /// `preferredContentSizeCategory` 覆盖后返回。
    private static func swizzleTraitCollection(on cls: AnyClass) {
        let selector = #selector(getter: UITraitEnvironment.traitCollection)
        guard let original = class_getInstanceMethod(cls, selector) else { return }

        let originalIMP = method_getImplementation(original)
        typealias OriginalFn = @convention(c) (AnyObject, Selector) -> UITraitCollection
        let originalFn = unsafeBitCast(originalIMP, to: OriginalFn.self)

        let block: @convention(block) (AnyObject) -> UITraitCollection = { obj in
            let base = originalFn(obj, selector)
            return TraitOverride.apply(to: base)
        }

        let newIMP = imp_implementationWithBlock(block)
        method_setImplementation(original, newIMP)
    }
}

/// 把固定档位合入一个已有的 trait collection。
enum TraitOverride {

    /// 若屏蔽启用，返回覆盖了 `preferredContentSizeCategory` 的 trait；
    /// 否则原样返回。该方法可能在非主线程被 UIKit 调用，因此对配置的读取
    /// 做了线程安全的快照处理。
    static func apply(to base: UITraitCollection) -> UITraitCollection {
        guard let category = ConfigSnapshot.effectiveCategory else { return base }
        // 已经是目标档位则无需再包一层，避免无谓分配。
        if base.preferredContentSizeCategory == category { return base }
        let override = UITraitCollection(preferredContentSizeCategory: category)
        return UITraitCollection(traitsFrom: [base, override])
    }
}

/// 配置的线程安全快照。
///
/// `traitCollection` getter 可能在任意线程被 UIKit 调用，而
/// `DynamicTypeBlocker` 标注了 `@MainActor`。这里用一个受锁保护的
/// 普通值缓存来供 swizzle 读取，主线程在配置变更时更新它。
enum ConfigSnapshot {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _isEnabled = true
    nonisolated(unsafe) private static var _category: UIContentSizeCategory = .large

    static var effectiveCategory: UIContentSizeCategory? {
        lock.lock(); defer { lock.unlock() }
        return _isEnabled ? _category : nil
    }

    static func update(isEnabled: Bool, category: UIContentSizeCategory) {
        lock.lock()
        _isEnabled = isEnabled
        _category = category
        lock.unlock()
    }
}

extension UIView {
    /// 强制该视图重新读取 trait 并刷新其子树。用于配置变更后的即时刷新。
    func tt_refreshContentSizeCategory() {
        setNeedsLayout()
        subviews.forEach { $0.tt_refreshContentSizeCategory() }
        // 触发依赖 traitCollection 的重绘（如 UILabel 的动态字体）。
        if let label = self as? UILabel { label.text = label.text }
        if let field = self as? UITextField { field.font = field.font }
        setNeedsDisplay()
    }
}
#endif

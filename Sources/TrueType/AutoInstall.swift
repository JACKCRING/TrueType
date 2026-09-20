//
//  AutoInstall.swift
//  TrueType
//
//  「引入即生效」的自动安装逻辑。
//
//  Swift 的 SPM 库没有 Info.plist 主类或 `+load` 可用作自动入口，
//  因此这里用 Objective-C runtime 的 `+load` 时机来触发安装：
//  定义一个继承自 NSObject 的类，其 `load` 会在其所在的镜像被加载进
//  进程时由 runtime 自动调用——无需宿主 App 写任何代码。
//
//  安装内容：
//  1. 完成 UIKit 的 traitCollection swizzle。
//  2. 监听 `DynamicTypeBlocker.didChangeNotification`，把配置同步到
//     供 swizzle 读取的线程安全快照。
//

#if canImport(UIKit)
import UIKit

final class TrueTypeAutoInstaller: NSObject {

    /// 由 Objective-C runtime 在镜像加载时自动调用。
    ///
    /// C 侧的 `+load` 已确保本方法通过 `dispatch_async(main)` 在主线程调用，
    /// 因此这里直接断言主线程隔离并执行安装。
    @objc static func trueTypeAutoLoad() {
        MainActor.assumeIsolated {
            performInstall()
        }
    }

    @MainActor
    private static func performInstall() {
        DynamicTypeSwizzler.installIfNeeded()
        syncSnapshot()

        NotificationCenter.default.addObserver(
            forName: DynamicTypeBlocker.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { syncSnapshot() }
        }
    }

    @MainActor
    private static func syncSnapshot() {
        let blocker = DynamicTypeBlocker.shared
        ConfigSnapshot.update(isEnabled: blocker.isEnabled, category: blocker.fixedCategory)
    }
}

// 触发 `trueTypeAutoLoad` 的加载时机。
// 通过 objc `+load` 语义：runtime 在加载镜像时调用所有类的 `load`。
// Swift 无法直接 override `load`，因此借助一个 category 风格的桥接：
// 使用 `__attribute__((constructor))` 由 C 侧调用（见 include 头文件）。
#endif

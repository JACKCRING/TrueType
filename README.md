# TrueType

屏蔽 iOS Dynamic Type（`UIContentSizeCategory`）的轻量级 SPM。无论用户在系统「设置 → 辅助功能 → 显示与文字大小」里把文字调到多大或多小，你的 App 字体与布局都保持固定尺寸。

- SwiftUI + UIKit 双兼容
- 引入即生效（UIKit / 混合架构），无需额外配置
- 暴露一个全局开关，可放进任意 App 的设置页，运行时实时切换

---

## 安装

Swift Package Manager：

```swift
.package(url: "https://github.com/<your>/TrueType.git", from: "1.0.0")
```

然后在 target 中依赖 `TrueType`。

---

## 快速上手

### UIKit / 混合架构（UIKit 承载 SwiftUI）

**什么都不用做。** 库在加载时会自动挂钩 UIKit 的 `traitCollection`，把
`preferredContentSizeCategory` 固定到默认档（`.large`）。承载在 UIKit 里的
SwiftUI 会自动继承这个固定档位。

### 纯 SwiftUI App（`@main App`）

SwiftUI 无法被全局运行时挂钩拦截，因此需要在根视图加一行：

```swift
import SwiftUI
import TrueType

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .blockDynamicType()   // 一行接入，随全局开关实时刷新
        }
    }
}
```

> 这是纯 SwiftUI 场景下唯一需要的代码。它会把固定的 `sizeCategory`
> 注入环境，并订阅全局开关变化自动刷新。

---

## 开关（放进你的设置页）

全局配置是一个进程级单例 `DynamicTypeBlocker.shared`，所有属性需在主线程访问。

```swift
import TrueType

// 打开 / 关闭屏蔽
DynamicTypeBlocker.shared.isEnabled = true   // true：固定字号；false：跟随系统

// 可选：调整被固定到的档位（默认 .large，即系统滑块中间位置）
DynamicTypeBlocker.shared.fixedCategory = .large
```

切换时会自动发出 `DynamicTypeBlocker.didChangeNotification` 并刷新已连接窗口，界面即时更新。

SwiftUI 设置页示例：

```swift
struct SettingsView: View {
    @State private var blockEnabled = DynamicTypeBlocker.shared.isEnabled

    var body: some View {
        Toggle("固定字体大小", isOn: $blockEnabled)
            .onChange(of: blockEnabled) { newValue in
                DynamicTypeBlocker.shared.isEnabled = newValue
            }
    }
}
```

UIKit 设置页示例：

```swift
@objc func toggleChanged(_ sender: UISwitch) {
    DynamicTypeBlocker.shared.isEnabled = sender.isOn
}
```

---

## 工作原理

| 层 | 机制 |
| --- | --- |
| 自动启动 | 独立的 Objective-C target `TrueTypeAutoStart` 通过 `+load` 在镜像加载时（早于 `main()`）反射调用 Swift 的安装逻辑 |
| UIKit | swizzle `UIView` / `UIViewController` / `UIScreen` 的 `traitCollection` getter，用固定的 `preferredContentSizeCategory` 覆盖返回值 |
| SwiftUI | `.blockDynamicType()` 把固定档位注入 `\.sizeCategory` 环境值 |
| 线程安全 | swizzle 可能在任意线程被 UIKit 调用，`ConfigSnapshot` 用锁保护一份配置快照供其读取；主线程在开关变化时更新快照 |

---

## 重要提示：静态链接下的 `+load`

「引入即生效」依赖 Objective-C 的 `+load`。当 TrueType 被**静态链接**进 App 时，
链接器可能因为没有直接引用而裁剪掉这个 `+load` 类，导致自动安装不触发。

如果发现屏蔽没有自动生效，任选一种方式解决：

1. **在链接标志里加 `-ObjC`**（推荐，最省事）
   Xcode → Target → Build Settings → Other Linker Flags 添加 `-ObjC`。

2. **在启动时主动触发一次**（显式、可靠）
   ```swift
   // AppDelegate.didFinishLaunching 或 App.init 里
   DynamicTypeBlocker.shared.isEnabled = true
   ```
   读写单例即可确保模块被引用、安装逻辑运行。

以动态 framework 方式集成时通常不受此影响。

---

## 能做到「零配置」吗？（诚实说明）

- **UIKit / 混合架构**：能，配合上面的静态链接提示即可完全零业务代码。
- **纯 SwiftUI App**：不能真正零代码，最少需要在根视图写一行 `.blockDynamicType()`。这是 SwiftUI 无法被全局挂钩的固有限制，不是本库的取舍。

---

## 兼容性

- iOS 14+ / tvOS 14+
- Swift 6（`swiftLanguageModes: [.v6]`）

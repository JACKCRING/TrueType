//
//  TrueTypeAutoStart.m
//  TrueTypeAutoStart
//
//  在镜像加载时自动触发 TrueType 的安装。
//
//  原理：
//  - Objective-C 的 `+load` 会在其所属镜像被加载进运行时的极早期被调用，
//    早于 main()，无需宿主 App 编写任何代码。
//  - 我们在这里通过 runtime 反射调用 Swift 侧
//    `TrueTypeAutoInstaller.trueTypeAutoLoad`，把控制权交回 Swift。
//  - 用反射（NSClassFromString + performSelector）而非直接链接，避免 C target
//    对 Swift target 产生编译期依赖，保持模块单向依赖关系。
//

#if __has_include(<UIKit/UIKit.h>)

#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface TrueTypeAutoStart : NSObject
@end

@implementation TrueTypeAutoStart

+ (void)load {
    // 在主线程尽早安排安装。此时 Swift 运行时已可用。
    dispatch_async(dispatch_get_main_queue(), ^{
        // Swift `@objc static func trueTypeAutoLoad()` 会被暴露为
        // 类方法 `trueTypeAutoLoad`，其 ObjC 类名带模块前缀。
        Class installer = NSClassFromString(@"TrueType.TrueTypeAutoInstaller");
        if (installer == Nil) {
            // 兼容未加模块前缀的情况。
            installer = NSClassFromString(@"TrueTypeAutoInstaller");
        }
        if (installer == Nil) { return; }

        SEL sel = NSSelectorFromString(@"trueTypeAutoLoad");
        if (![installer respondsToSelector:sel]) { return; }

        void (*fn)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
        fn(installer, sel);
    });
}

@end

#endif /* __has_include(<UIKit/UIKit.h>) */

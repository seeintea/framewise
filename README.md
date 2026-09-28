# Framewise

Framewise 是一款帮助用户完成照片构图的原生 iOS 相机应用。

用户可以选择预设的构图模板，并在实时相机画面上通过可视化引导线调整人物、主体和留白的位置。引导层只参与拍摄预览，不会出现在最终照片中。

项目正在从已经完成产品验证的 Expo / React Native 原型迁移到原生 iOS。当前仓库以 Xcode 新建的原生工程为起点；历史实现保留在 Git 历史中，需要参考时通过独立 worktree 查看，不复制回当前工作树。

## 开发环境

- Xcode 26
- iOS 26 或更高版本
- SwiftUI

用 Xcode 打开 `ios/Framewise.xcodeproj`，选择 `Framewise` scheme 和目标设备后运行。

命令行编译检查：

```bash
xcodebuild \
  -project ios/Framewise.xcodeproj \
  -scheme Framewise \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 仓库结构

```text
ios/            原生 iOS 应用代码、运行时资源和 Xcode 工程
android/        Android 工程与平台专属资源
apps/           独立应用，包括模板预览与后续编辑工具
composition/    平台无关的构图模板数据
design-system/  跨平台字体、图标和品牌源文件
plans/          产品、验证与架构讨论记录
```

`plans/` 只作为产品和迁移依据，不代表对应能力已经实现。历史实现通过 Git 追溯，
不是当前架构或能力的事实依据。

## 历史实现

旧原生 iOS 相机快照目录已于 2026-09-28 从当前工作树移除。完整快照仍保留在 Git 提交
`7810b0b` 的历史路径 `archive/ios-camera-legacy-2026-09-20/`，快照原始来源为 `e7b40b9`。
剩余提示类行为暂不迁移，具体取舍见 [新相机架构中的迁移收尾记录](./plans/ios-camera-architecture-v2.md)。
旧源码只用于追溯行为，不应从中复制架构或推断当前能力。

迁移前的 React Native 归档与早期 SwiftUI 翻译保留在提交 `5d1a630`。需要参考时使用独立 worktree：

```bash
git worktree add ../framewise-history 5d1a630
```

阅读完成后移除该 worktree，不要把整套历史代码恢复到当前工作树。

## License

Framewise 是闭源商业软件。源代码、素材和文档均保留所有权利，详见 [LICENSE](./LICENSE)。

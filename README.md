# Framewise

Framewise 是一款帮助用户完成照片构图的原生 iOS 相机应用。

用户可以选择预设的构图模板，并在实时相机画面上通过可视化引导线调整人物、主体和留白的位置。引导层只参与拍摄预览，不会出现在最终照片中。

项目正在从已经完成产品验证的 Expo / React Native 原型迁移到原生 iOS。当前原生工程已经包含首页、搜索、我的和悬浮 Tab 导航；相机、构图与本地 AI 等核心能力将在后续独立迁移。

## 开发环境

- Xcode 26
- iOS 18 或更高版本
- SwiftUI

用 Xcode 打开 `Framewise.xcodeproj`，选择 `Framewise` scheme 和目标设备后运行。

命令行编译检查：

```bash
xcodebuild \
  -project Framewise.xcodeproj \
  -scheme Framewise \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 仓库结构

```text
Framewise/            原生 iOS 应用代码与运行时资源
Framewise.xcodeproj/  Xcode 工程
archive/              原型阶段的历史实现与待迁移能力
design/               品牌和设计源素材，不加入应用 target
plans/                产品、验证与架构讨论记录
```

`archive/` 和 `plans/` 只作为迁移依据。当前原生应用不直接编译或依赖其中的代码。

## License

Framewise 使用 [MIT License](./LICENSE)。

# Framewise

> **已归档（Archived）**：项目已停止推进，2026-10-08 将归档状态写入仓库。仓库保留代码、设计与实验记录供回顾，原有计划和待办不再作为后续开发安排。

Framewise 是一款用构图模板辅助取景的原生 iOS 相机应用。用户选择模板，在实时预览上按引导线调整构图，再拍摄并保存到系统相册。构图引导不写入成片；当前照片与 Live Photo 视频会添加 Framewise 水印。

项目经历了 Expo / React Native 原型、早期 SwiftUI 迁移和原生相机重写。当前工作树使用 SwiftUI、AVFoundation、PhotoKit 与本地模板 JSON；历史实现和实验结果的适用范围见[迁移记录](plans/migration-history.md)。

## 为什么停止推进

在对比 Doka、Mola 和男友相机后，我们判断男友相机已能替代 Framewise 想提供的核心拍摄辅助体验，原有产品方向缺少值得继续投入的明确差异。因此决定归档，不再为延续项目而强行寻找差异点。相机能力调研、Swift / iOS 实践、构图模板原型和验证记录保留，作为这次探索的积累。

## 归档时的实现状态

已实现模板列表到相机的导航、SwiftUI 构图蒙版、普通照片和带声音 Live Photo 的捕获与相册保存，以及比例裁切、输出旋转、水印、缩放、对焦测光、曝光、闪光灯和前后摄切换。Live Photo 不可用时可降级为普通照片；相机会话具备中断和运行时错误恢复处理。

代码已实现不等于全部真机验收完成。首页分类与推荐仍是展示骨架，“全部模版”页已支持名称与简介搜索，尚无分类筛选，设置页主要提供 Debug 入口；当前没有 Android 应用工程或本地 AI 功能。

- [当前实现清单与验收边界](plans/current-status.md)
- [归档时的未完成事项](plans/next-steps.md)
- [文档索引及过时文档说明](plans/README.md)
- [工程协作规范](AGENTS.md)

## 开发环境

- Xcode 26 工程基线，使用支持当前源码的 Xcode 与 iOS SDK。
- `Framewise` target：iOS 18.0 起，iPhone；Swift language mode 5，默认 MainActor。
- SwiftUI UI；系统相机、图像处理和相册能力使用 Apple 框架。

用 Xcode 打开 `ios/Framewise.xcodeproj`，选择 `Framewise` scheme。开发者签名配置放在本地 `ios/Config/Signing.local.xcconfig`，不要提交。

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
ios/Framewise/       Swift 源码、Assets 与运行时资源
ios/Framewise.xcodeproj/  原生 iOS 工程
ios/Config/          签名配置入口
android/            Android 平台图标与启动素材，目前没有应用工程
apps/template-studio/  独立 Web 模板预览工具
composition/        平台无关的模板 JSON 与本地化文案
design-system/      字体、SVG 图标与品牌源文件
plans/              归档时的实现状态、未完成事项、设计与历史实验记录
```

[Template Studio](apps/template-studio/README.md) 已支持浏览模板、选择画幅和用本地图片预览，尚不支持编辑或写回模板。[模板数据](composition/README.md)与[设计资产](design-system/README.md)各自维护唯一来源。

## License

Framewise 是闭源商业软件。源代码、素材和文档均保留所有权利，详见 [LICENSE](./LICENSE)。

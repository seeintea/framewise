# Framewise 工程指南

Framewise 当前以 SwiftUI 原生 iOS 应用为主，已从 Expo / React Native 原型转向原生工程，并完成新相机的基础拍摄、处理与保存链路。产品体验和真机验收仍在推进。保持改动小而可逆，以当前 Swift 代码和 Xcode target 配置为准。

## 事实依据

- 做出假设前，先检查当前 Swift 代码、`ios/Framewise.xcodeproj` 和对应 target 的 build settings。
- 文档入口是 [plans/README.md](plans/README.md)。[当前实现清单](plans/current-status.md)记录代码已实现的能力与验收边界；[待实现与待优化](plans/next-steps.md)记录未完成事项。规划、实验结果和历史验收不能替代当前代码证据。
- 新相机的已确认设计见 [ios-camera-architecture-v2.md](plans/ios-camera-architecture-v2.md)。旧相机行为不自动成为重写要求；暂不迁移的行为与历史源码位置见 [迁移记录](plans/migration-history.md)。
- Expo / React Native、早期 SwiftUI 翻译及旧相机只用于追溯。阅读历史代码时使用独立 worktree，不恢复或复制到当前工作树，除非用户明确要求迁移具体能力。
- 过去实验的分支名称不是持久引用，不假定分支或实验提交会保留在 Git。实验按日期、方案、条件、数据和结论记录在 [camera-experiments.md](plans/camera-experiments.md)，代码是否采用以当前源码为准。
- 使用新的 Apple 平台 API 前，阅读对应系统版本的 Apple Developer Documentation，并确认 availability。

## 技术方案迭代

- 当首次实现效果不满意、进入技术方案细化讨论时，先调查官方推荐方式和成熟项目如何处理同类问题，再决定下一次改动；不要仅靠内部推测、反复调参或叠加补丁连续试错。
- 优先查阅 Apple 官方文档、示例及相关成熟开源项目的实际源码，确认其采用的 API、实现策略与适用条件。核对平台版本和当前工程的差异，不仅凭其他应用的表面效果推断内部实现。
- 讨论方案时简要给出参考来源、成熟方案的处理方式及其对当前问题的适用性，优先复用能满足需求的平台能力，并通过最小、可逆的实验验证用户关注的实际效果，再决定是否需要自定义实现。

## 运行环境与依赖

- 工程以 Xcode 26 建立；使用能编译当前源码的 Xcode 与 iOS SDK。当前 `Framewise` target 最低部署版本为 iOS 18.0，仅支持 iPhone，Swift language mode 为 5，默认 actor isolation 为 MainActor。不要把本机 SDK 版本当作最低部署版本。
- 应用 UI 使用 SwiftUI；只有 SwiftUI 无法合理满足相机预览、高频绘制或系统能力接入时才使用 UIKit、AVFoundation、Vision、Core ML 或 Metal。
- 优先使用 Apple 系统框架。只有平台能力无法合理提供所需功能时才新增第三方依赖。
- 如需第三方 Swift 依赖，优先使用 Swift Package Manager，并提交 `Package.resolved`；不要引入 CocoaPods、Carthage 或其他依赖管理器。
- 不要提交 `xcuserdata/`、Derived Data、签名证书、描述文件或其他开发者本地状态。

## Swift 与命名

- 保持 Xcode target 当前的 Swift language mode；除非用户明确要求，不要顺带升级语言模式或最低系统版本。
- 类型、协议和 SwiftUI View 使用 PascalCase；属性、函数和 enum case 使用 lowerCamelCase。
- 一个文件优先承载一个主要类型，文件名与主要类型一致。
- 保留模块边界上有意义的类型。避免 `Any`、强制解包、无依据的类型转换和重复领域类型。
- 优先使用值类型、明确的访问控制和现代 Swift 语法。
- 并发代码使用 Swift Concurrency。UI 状态与 UI 更新保持在 MainActor；不要用无结构并发隐藏生命周期问题。

## 项目边界

- `ios/Framewise/` 是 iOS 应用源码和运行时资源的根目录。
- `apps/template-studio/` 是模板预览与后续编辑工具，不属于任一移动平台。
- `composition/` 保存平台无关的构图模板数据，不依赖 SwiftUI、React 或平台 runtime 类型。
- `design-system/` 保存跨平台 UI 的字体、SVG 图标和品牌源文件，是这些视觉资产的唯一来源。
- 当前入口和根组合是 `ios/Framewise/FramewiseApp.swift`、`AppRootView.swift`；跨功能导航在 `Navigation/`；页面在 `Features/`，相机与引导页各有子目录。不为符合旧规划而移动现有文件或创建空的 `App/`。
- 相机会话、采集与保存流程在 `Core/Camera/`，采集后的图片 / Live Photo 成品加工在 `Core/Photo/`，权限在 `Core/Permissions/`，蒙版绘制在 `Core/Canvas/`；模板加载和解码在 `MaskDataSource.swift`、`Server/`。Camera 调用 Photo，Photo 不依赖 Camera 类型或共享状态。`MaskServer` 是本地数据入口，不是网络服务。
- Feature 和 Core 不依赖应用入口与根组合。保持现有职责边界，不新建笼统的 `Shared/`。
- 当前已有原生相机和 SwiftUI 蒙版绘制；Vision、Core ML、模板推荐和持久化扩展尚未实现，没有明确需求时不要根据历史方案提前建立模块。
- 保持可序列化的构图模板数据独立于 SwiftUI View、相机 runtime 对象和屏幕像素值。

## SwiftUI 实现风格

- 为当前需求实现最简单且正确的 View 与状态流，不为假设中的未来需求增加 coordinator、service、repository 或通用 wrapper。
- 优先使用 `@State`、`@Binding` 和 SwiftUI environment；出现真实的跨页面共享状态后再引入 Observation 模型。
- 使用 `NavigationStack` 表达层级导航，使用轻量且可哈希的路由值，不把完整业务模型塞入 navigation path。
- 遵循系统可访问性、Dynamic Type、Safe Area、深色模式和 Reduce Motion 行为。
- 新系统 API 必须通过 availability 检查提供合理的旧系统表现。回退只解决系统版本差异，不应吞掉编程错误。
- 仅在路由输入、持久化数据、设备 API 和网络响应等不可信边界校验数据；不要在可信内部状态中重复校验。

## 资源与本地化

- iOS 的资源包装放在 `ios/Framewise/Assets.xcassets/`；共享 UI 图标的 imageset 可以链接到 `design-system/icons/` 中的唯一 SVG 源文件。
- Android 专属的 adaptive icon、monochrome icon 和启动资源放在 `android/`，后续随 Android 工程迁入对应的 `res/` 目录。
- 字体、自定义 UI 图标和品牌源文件由 `design-system/` 统一管理；平台工程负责引用或转换，不各自维护独立设计源。
- 默认显示名称为 `Framewise`。新增本地化名称时使用 Xcode 支持的本地化资源，不在 build settings 中为不同语言复制 target。
- 新增面向用户的文本时使用可本地化的 SwiftUI 字符串，不在业务逻辑中拼接不可本地化文案。

## 代码质量与验证

- 不要关闭编译警告或用不安全写法绕过错误；如确有例外，在代码附近说明具体原因。
- 不要在一次聚焦改动中混入无关重构或 Xcode 自动升级设置；iOS 提交前的统一格式化按下方 Git 提交要求执行。
- 完成 Swift、资源或工程配置改动前，运行：

  ```bash
  xcodebuild \
    -project ios/Framewise.xcodeproj \
    -scheme Framewise \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
  ```

- 如果本机尚未安装匹配的 iOS Platform，明确报告环境限制；不要用降低部署版本或改工程配置来掩盖缺失组件。
- 除非用户明确要求，否则不要启动模拟器、安装应用、操作真机或执行签名归档。

## 文档维护

- 更新能力时同步 `plans/current-status.md` 与 `plans/next-steps.md`；区分“代码已实现”“真机已验证”和“待验证”，不要把编译通过写成产品验收完成。
- 当前设计文档只保留仍成立的职责、契约和取舍；实验数据、被撤回方案和调查过程单独记录。历史文档在开头注明过时范围与替代入口，正文中的“当前”“已完成”只描述其历史版本。
- `composition/README.md` 与实际 JSON / Swift 解码类型是模板数据现状的依据；旧 `CompositionPreset`、Skia 或 Expo 规范不得直接套用到当前 iOS。
- 不写实验分支切换、待合并或永久保留承诺；只有确认仍可追溯的历史提交才作为源码引用。本地附件或临时 trace 应注明非仓库材料，关键条件和结论写入文档。
- 纯 Markdown 改动检查链接、状态与源码的一致性和 `git diff --check`；上述构建要求适用于 Swift、资源或工程配置改动。

## Git 提交

- 只有用户明确要求时才创建 commit。
- 涉及 iOS 改动时，创建 commit 前必须在仓库根目录运行以下命令，使用根目录的 `.swift-format` 配置统一格式，并检查生成的 diff。格式化应在上述构建验证之前完成，将格式化结果一并提交。

  ```bash
  xcrun swift-format format --in-place --recursive ios/Framewise
  ```

- 一个 commit 可以包含多项共同完成的改动，不需要为了保持单一目的而强行拆分。
- commit 标题和 body 使用英文。
- 使用简洁的 Conventional Commit 标题，格式为 `<type>: <主要结果>`。
- 标题只描述 commit 的主要工作；body 使用少量 bullet 补充实际完成的次要内容和必要的验证信息。

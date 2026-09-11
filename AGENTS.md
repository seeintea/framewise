# Framewise 工程指南

Framewise 正在从 Expo / React Native 迁移到原生 iOS。保持改动小而可逆，并以当前实际存在的 Swift 代码和 Xcode 工程配置为准。不要把 `plans/` 中规划的模块或 `archive/` 中的历史实现视为已经迁移完成。

## 事实依据

- 做出假设前，先检查当前 Swift 代码、`Framewise.xcodeproj` 和对应 target 的 build settings。
- `plans/` 记录产品与架构方向，只作为上下文，不代表相关功能已经实现。
- `archive/` 保存旧版验证代码与构图数据。在对应能力完成原生迁移前，不要删除、直接引用或把它加入原生 target。
- 使用新的 Apple 平台 API 前，阅读对应系统版本的 Apple Developer Documentation，并确认 availability。

## 运行环境与依赖

- 项目使用 Xcode 26，当前最低部署版本为 iOS 18。
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

- `Framewise/App/` 负责应用入口、根导航和全局组合。
- 产品功能放在 `Framewise/Features/<Feature>/`，功能之间不要直接共享彼此的内部实现。
- 跨功能导航放在 `Framewise/Navigation/`。
- 后续真正跨 feature 的领域能力直接放在 `Framewise/` 下职责明确的目录，例如 `CameraEngine/`、`VisionEngine/`、`CompositionEngine/` 和 `Persistence/`；不要创建笼统的 `Shared/`。
- Feature 和领域模块不得依赖 App 层。
- 相机、视觉和构图属于后续独立迁移范围。没有明确需求时，不要根据 `archive/` 提前建立空模块或抽象层。
- 保持可序列化的构图模板数据独立于 SwiftUI View、相机 runtime 对象和屏幕像素值。

## SwiftUI 实现风格

- 为当前需求实现最简单且正确的 View 与状态流，不为假设中的未来需求增加 coordinator、service、repository 或通用 wrapper。
- 优先使用 `@State`、`@Binding` 和 SwiftUI environment；出现真实的跨页面共享状态后再引入 Observation 模型。
- 使用 `NavigationStack` 表达层级导航，使用轻量且可哈希的路由值，不把完整业务模型塞入 navigation path。
- 遵循系统可访问性、Dynamic Type、Safe Area、深色模式和 Reduce Motion 行为。
- 新系统 API 必须通过 availability 检查提供合理的旧系统表现。回退只解决系统版本差异，不应吞掉编程错误。
- 仅在路由输入、持久化数据、设备 API 和网络响应等不可信边界校验数据；不要在可信内部状态中重复校验。

## 资源与本地化

- App 运行时资源放在 `Framewise/Resources/`，图片优先使用 Asset Catalog。
- `design/` 保存设计源文件和历史导出物，不加入应用 target，也不从运行时代码直接读取。
- 默认显示名称为 `Framewise`，简体中文显示名称通过 `zh-Hans.lproj/InfoPlist.strings` 配置为“蒙版相机”。
- 新增面向用户的文本时使用可本地化的 SwiftUI 字符串，不在业务逻辑中拼接不可本地化文案。

## 代码质量与验证

- 不要关闭编译警告或用不安全写法绕过错误；如确有例外，在代码附近说明具体原因。
- 不要在一次聚焦改动中混入无关重构、全工程格式化或 Xcode 自动升级设置。
- 完成 Swift、资源或工程配置改动前，运行：

  ```bash
  xcodebuild \
    -project Framewise.xcodeproj \
    -scheme Framewise \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
  ```

- 如果本机尚未安装匹配的 iOS Platform，明确报告环境限制；不要用降低部署版本或改工程配置来掩盖缺失组件。
- 除非用户明确要求，否则不要启动模拟器、安装应用、操作真机或执行签名归档。

## Git 提交

- 只有用户明确要求时才创建 commit。
- 一个 commit 可以包含多项共同完成的改动，不需要为了保持单一目的而强行拆分。
- commit 标题和 body 使用英文。
- 使用简洁的 Conventional Commit 标题，格式为 `<type>: <主要结果>`。
- 标题只描述 commit 的主要工作；body 使用少量 bullet 补充实际完成的次要内容和必要的验证信息。

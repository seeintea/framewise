# 当前实现清单

> 状态：当前代码事实。核对日期：2026-09-29。依据为当前工作树的 Swift、模板 JSON、Web 工具源码和 `Framewise` target build settings。
>
> “已实现”表示代码链路存在，不等于所有设备与场景已通过真机验收。未完成和待验证事项统一放在[待实现与待优化](next-steps.md)，实验结果见[相机实验记录](camera-experiments.md)。

## 工程与平台

- 当前移动端为 SwiftUI 原生 iOS，只有 `Framewise` app target / scheme，支持 iPhone 与 iOS Simulator，不支持 Mac Catalyst。
- Debug / Release 最低 iOS 18.0，Swift language mode 5，默认 MainActor，启用 Approachable Concurrency。工程以 Xcode 26.0.1 建立；本轮读取 build settings 使用本机 Xcode 27 / iOS Simulator 27 SDK，最低系统版本仍是 18.0。
- iOS target 当前没有第三方 Swift Package product dependency，也没有测试 target。
- `android/` 只有平台素材，没有可运行的 Android 工程。Template Studio 是独立 Web 工具，不能算作移动端实现。

配置证据：[project.pbxproj](../ios/Framewise.xcodeproj/project.pbxproj)、[Info.plist](../ios/Framewise/Resources/Info.plist)。

## 已实现：页面、模板与导航

| 能力 | 当前范围 | 主要代码 / 数据 |
| --- | --- | --- |
| 应用与根导航 | `NavigationStack`、模板首页 / 设置两页、浮动栏进入“全部模版”列表 | [AppRootView](../ios/Framewise/AppRootView.swift)、[MainTabView](../ios/Framewise/Navigation/MainTabView.swift) |
| 本地模板加载与解码 | 14 个模板；独立 `template.v1.json` 与 `zh-Hans.v1.json`，UUID 引用，校验 schema、默认变体与本地化 | [模板数据说明](../composition/README.md)、[MaskDataSource](../ios/Framewise/MaskDataSource.swift)、[MaskContent 解码](../ios/Framewise/Server/Models/MaskContent+Decoding.swift) |
| 本地查询入口 | `MaskServer` 列表与按 ID 查询；没有网络服务 | [ListMasks](../ios/Framewise/Server/ListMasks.swift)、[GetMask](../ios/Framewise/Server/GetMask.swift) |
| 模板搜索与选择 | 顶部搜索框按名称与简介实时筛选，支持清空与无结果状态；双列瀑布流以默认变体的真实画幅显示色块卡片，仅叠加标题与推荐比例，文字使用浅色半透明底，较矮卡片使用紧凑排版，点击打开该模板；辅助功能大字号使用单列 | [SearchView](../ios/Framewise/Features/SearchView.swift)、[CameraMaskRequest](../ios/Framewise/Navigation/CameraMaskRequest.swift) |
| 首页快捷拍摄 | “拍一张”固定打开“前景纵深”模板 `foreground-depth`，不是旧文档中的九宫格 | [GuideView](../ios/Framewise/Features/Guide/GuideView.swift)、[模板 JSON](../composition/templates/foreground-depth/template.v1.json) |
| 蒙版与注释 | SwiftUI Canvas 绘制实线 / 虚线、圆、圆角矩形及本地化注释；归一化坐标，注释可隐藏 | [MaskCanvas](../ios/Framewise/Core/Canvas/MaskCanvas.swift)、[CameraMaskOverlay](../ios/Framewise/Features/Camera/CameraMaskOverlay.swift) |
| 关联模板切换组件 | 相机可接收有序关联模板并切换；正式入口目前只传单模板 | [AppRootView](../ios/Framewise/AppRootView.swift)、[CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift) |
| Debug 工具 | 权限检查与申请、单 / 多模板相机 UI mock 预览；mock 不执行真实采集 | [PermissionDebugView](../ios/Framewise/Features/Debug/PermissionDebugView.swift)、[CameraDebugView](../ios/Framewise/Features/Debug/CameraDebugView.swift) |

模板按当前 `defaultVariant` 使用；存在多种画幅的数据结构和输出支持，不表示已有面向用户的变体选择器。当前渲染器是 SwiftUI Canvas，旧 Skia 指南仅供历史参考。

## 已实现：原生相机

| 能力 | 当前范围 | 主要代码 |
| --- | --- | --- |
| 权限入口 | 进入相机要求相机与相册 add-only 权限；麦克风仅在启用 Live Photo 时按需申请，提供拒绝 / 受限状态与设置入口 | [CameraAccess](../ios/Framewise/Features/Camera/CameraAccess.swift)、[Permissions](../ios/Framewise/Core/Permissions/Permissions.swift) |
| 预览与生命周期 | AVFoundation 会话在专用队列运行；UIKit preview layer 接入 SwiftUI；离页 / 后台停止，回到前台恢复 | [CameraPreview](../ios/Framewise/Features/Camera/CameraPreview.swift)、[CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift) |
| 中断与运行时错误 | 中断提示与重试、恢复后重新读取设备能力，处理 `mediaServicesWereReset` | [CameraController](../ios/Framewise/Core/Camera/CameraController.swift)、[CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift) |
| 普通照片 | 设备支持时优先 HEIF / HEVC，否则 JPEG；使用 `.balanced`；拍摄时冻结比例、闪光与 Live 状态 | [CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift)、[CameraController](../ios/Framewise/Core/Camera/CameraController.swift) |
| 比例与输出方向 | 支持 1:1、3:4、4:3、9:16、16:9，中心裁切；竖屏 UI 下处理横向模板和握持方向旋转 | [PhotoAspectRatio](../ios/Framewise/Core/Photo/PhotoAspectRatio.swift)、[CameraViewportLayout](../ios/Framewise/Features/Camera/CameraViewportLayout.swift)、[CameraOrientationMonitor](../ios/Framewise/Core/Camera/CameraOrientationMonitor.swift) |
| 前后摄与镜像 | 设备能力决定切换入口；前置预览和照片连接镜像；切换失败恢复原输入 | [CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift) |
| 缩放 | 后置设备倍率档位、连续捏合和系统 zoom ramp；捏合结束 / 取消及采集接管时清理基准；前置宽 / 窄两档，窄档约为宽档的 1.3 倍中心裁切 | [CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift)、[CameraZoomControls](../ios/Framewise/Features/Camera/CameraZoomControls.swift) |
| 对焦、测光与曝光 | 点击位置转设备坐标、连续自动对焦 / 曝光、曝光补偿；点按重置补偿，主体或视向变化后回到中心自动状态 | [CameraFocusExposureControl](../ios/Framewise/Features/Camera/CameraFocusExposureControl.swift)、[CameraFocusInteraction](../ios/Framewise/Features/Camera/CameraFocusInteraction.swift)、[CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift)、[CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift) |
| 闪光与偏好 | 根据设备能力提供 off / auto / on；闪光、Live 偏好和注释显示使用 `AppStorage` | [CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift)、[CameraAccess](../ios/Framewise/Features/Camera/CameraAccess.swift) |
| Live Photo 与降级 | 静态图 + 带声音 MOV；不支持或麦克风拒绝 / 受限 / 不可用时保留普通照片并提示原因 | [CameraEngine](../ios/Framewise/Core/Camera/CameraEngine.swift)、[LivePhotoProcessor](../ios/Framewise/Core/Photo/LivePhotoProcessor.swift) |
| 统一处理与固定水印 | 静态图融合裁切、旋转和绘制；Live 视频用 Core Image 合成；成品固定添加右下 logo + 中文“蒙版相机”，没有用户开关 | [PhotoProcessor](../ios/Framewise/Core/Photo/PhotoProcessor.swift)、[PhotoWatermark](../ios/Framewise/Core/Photo/PhotoWatermark.swift)、[LivePhotoWatermarkCompositor](../ios/Framewise/Core/Photo/LivePhotoWatermarkCompositor.swift) |
| 相册保存 | PhotoKit add-only 写入普通照片或 `.photo` + `.pairedVideo`；继承配对元数据、清理临时文件；离开相机后继续保存，失败由根页面提示 | [CameraPhotoSaver](../ios/Framewise/Core/Camera/CameraPhotoSaver.swift)、[LivePhotoProcessor](../ios/Framewise/Core/Photo/LivePhotoProcessor.swift)、[AppRootView](../ios/Framewise/AppRootView.swift) |
| 相册入口与缩略图 | 点击尝试跳转系统「照片」App，失败提示；不申请读取权限。已有完整 / 有限读取授权时按拍摄时间显示可访问的最新图片，监听相册变化并在前台刷新；静态成品处理后、写库前生成小尺寸内存预览，Live 不等待视频处理；保存失败撤回对应预览，跨相机页面保留，重启不持久化 | [CameraBottomControls](../ios/Framewise/Features/Camera/CameraBottomControls.swift)、[CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift)、[CameraAlbumThumbnail](../ios/Framewise/Core/Camera/CameraAlbumThumbnail.swift)、[PhotoProcessor](../ios/Framewise/Core/Photo/PhotoProcessor.swift) |
| 快门响应与背压 | 设备支持时启用 zero shutter lag / responsive capture；readiness coordinator 与全应用最多 3 张 pending 请求共同控制快门；额度覆盖采集 / 处理 / 写库，离页重入共用且释放后更新当前页面；静态加工 actor 串行，单张 Live 内静态 / 视频并行 | [CameraController](../ios/Framewise/Core/Camera/CameraController.swift)、[CameraPhotoSaver](../ios/Framewise/Core/Camera/CameraPhotoSaver.swift)、[PhotoProcessor](../ios/Framewise/Core/Photo/PhotoProcessor.swift)、[LivePhotoProcessor](../ios/Framewise/Core/Photo/LivePhotoProcessor.swift) |
| 反馈与观测 | 快门遮罩、轻触感；拍摄阶段 Debug 日志，会话 / 权限阶段 Debug 和 Release 日志 | [CameraScreen](../ios/Framewise/Features/Camera/CameraScreen.swift)、[CameraCapturePerformance](../ios/Framewise/Core/Camera/CameraCapturePerformance.swift)、[CameraSessionPerformance](../ios/Framewise/Core/Camera/CameraSessionPerformance.swift) |

构图引导只参与预览；水印属于最终资源处理。前摄宽窄档是当前自定义实现，不宣称与 Apple Camera 完全一致。

相册跳转使用 `photos-redirect://`，Apple 未提供公开稳定契约；只能尝试打开「照片」App，不能保证定位到最新图片。按钮预览不代表保存成功；未写入相册的图片还不能在「照片」App 中看到。有限读取授权下，“最新”仅限允许访问的图片；只有 add-only 权限时使用本次应用运行中拍摄的内存预览，否则显示占位图标。

相机职责已拆分：`Core/Photo` 接收静态图片 / 配对视频、画幅与最终旋转，负责成品加工及缩略图生成，
通过阶段回调交给 Camera 记录耗时；不依赖 Camera 类型或共享状态。Camera 保留会话、握持方向、
每拍 delegate 保活、跨页面保存、采集额度和相册缩略图结算。Feature 对焦曝光行为使用页面局部
`@State` 值与 `Binding`；快门遮罩、Live 降级及中断 / 恢复提示分别由独立 View 呈现。

## 已实现：工具与资产

- [Template Studio](../apps/template-studio/README.md)读取共享模板与中文本地化，支持模板列表、画幅选择、几何 / 注释预览和本地图片背景。图片留在浏览器；尚无编辑、写回、模板封面或变体示例图接入。
- [design-system](../design-system/README.md)统一管理字体、SVG 图标和品牌源文件；iOS 用资源目录与 imageset 引用，模板目录作为只读资源打包。

## 验收边界

当前新相机已有局部真机反馈和性能样本，但它们只覆盖记录中的构建、素材和场景；旧相机 M0～M6 的验收不能转用。HEIF 的图像 / Live 配对、前置镜像与补光、各比例方向、多设备能力、中断恢复和连续保存的完整矩阵仍需验证。

2026-09-29 Camera / Photo 职责拆分已通过 Xcode 27 的无签名 generic iOS Simulator 构建，部署版本仍为 iOS 18。
使用临时 macOS SwiftUI `Binding` 与相机命令替身运行实际 `CameraFocusInteraction`，验证配置 ID 在命令提交时冻结、
旧选择 / 旧配置 / 旧曝光回调失效、拖曝光或拍摄期间延后复位、隐藏反馈保留设备选择、零 EV 隐藏 / 非零 EV 淡化、
拖动恢复显示以及清理后的任务取消。替身为非仓库材料，不调用真实相机或相册；本轮未启动模拟器或操作真机，
成品处理、Live 配对与实际交互仍按待办验收。

2026-09-29 相册入口与缩略图已通过 iOS Simulator 目标编译；用户反馈测试通过。未记录机型、系统与具体覆盖场景，不将该反馈视为完整验收矩阵通过；授权组合、iCloud 下载、删除 / 编辑同步和连续拍摄等边界仍待补充验证。代理未启动模拟器或操作真机。

2026-09-28 首拍性能调查已结束，未产出经验证值得采用的进一步优化。Release trace 缺少拍摄标记和等待线程数据，不能解释此前 Debug 等待或证明问题消失。相关数据和限制保留在[实验记录](camera-experiments.md)。本轮文档整理没有运行应用或追加真机验收。

2026-09-29 跨页面采集额度与取消捏合清理已实现，无签名 generic iOS Simulator 构建通过；使用临时 PhotoKit 替身验证了共享额度、当前页面通知、保存成功与失败后的释放及 Live 临时资源清理。替身为非仓库材料，不调用真实相册；退出重入快门及被打断捏合的真机体验仍待验证，本轮未运行应用或追加真机验收。

2026-09-29 模板搜索与双列瀑布流已通过无签名 generic iOS Simulator 构建。卡片以封面内叠加标题与推荐比例的方式保持原画幅，简介不再显示，文字不增加卡片高度。使用临时 macOS SwiftUI 离屏渲染核对了五种画幅、浅 / 深色与显式放大字体时的紧凑排版；这些样例为非仓库材料，不能替代 iOS Dynamic Type 与真机验收。搜索交互与可访问性的实际体验仍待验证，本轮未启动模拟器或操作真机。

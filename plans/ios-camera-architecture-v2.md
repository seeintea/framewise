# iOS 相机重写架构

> 状态：Core 权限模块、相机核心拆分与基础拍摄能力已实现；正式相机页已接入蒙版预览、新 UI 与前后切换，前置取景、镜像和屏幕补光仍待真机验证。
>
> 创建日期：2026-09-20。
>
> 最近更新：2026-09-28。
>
> 本文描述 2026-09-20 开始的新相机实现。旧相机快照目录已从当前工作树移除；旧源码保留在
> Git 提交 `7810b0b` 的历史路径 `archive/ios-camera-legacy-2026-09-20/`，不作为本文的默认设计依据。

## 2026-09-28 旧相机迁移收尾

本轮以旧相机为参照的迁移收尾。基础预览、普通/Live 拍摄与处理保存、镜头与拍摄控件、
会话中断/运行时错误恢复、HEIF 优先编码、Live 不可用自动降级与启动性能日志，以当前
Swift 代码和对应章节的验证记录为准；旧相机的验收结果不自动适用于新实现。

`CameraStatusBadge` 已复制保留为 `Features/Camera` 下的 SwiftUI 提示组件，目前只有组件
预览，尚未接入正式相机页面。这不代表旧提示行为已迁移；用户确认其余提示类改动暂不迁移：

| 旧行为 | 当前处理决定 |
| --- | --- |
| Live 开启/关闭后的短暂状态徽标 | 暂不迁移；正式页面以 Live 图标的实际状态表达模式 |
| 模板方向与握持方向不一致时的“请旋转手机”提示 | 暂不迁移；保留当前方向与成片规则 |
| 请求相机/麦克风权限、启动配置时的分阶段说明面板 | 暂不迁移；保留当前权限入口、加载表现与分段性能日志 |
| 设备、输入、拍摄、处理和相册保存失败的细分文案及按原因设置/重试入口 | 暂不迁移；保留现有权限引导、相机错误提示和全局保存失败提示 |

Live 降级原因提示与会话中断/恢复反馈已实现，不属于上述暂缓项目。旧的预览可见区域到照片
显式映射用于解决旧横竖屏成像不一致，本轮确认不迁移；成片正确性继续按当前管线验收。
相册入口在旧实现与当前实现都属于占位，不作为旧能力迁移遗漏。后续提示需求单独讨论，
不根据旧代码自动补齐。

检查确认 `archive/` 仅含 23 个已跟踪、未修改的旧相机文件，当前 iOS target 和运行代码均
不依赖它们，因此移除整个目录。删除前完整快照可从 Git 提交 `7810b0b` 的历史路径
`archive/ios-camera-legacy-2026-09-20/` 追溯，快照原始来源为 `e7b40b9`。标题带“归档”的
设计、性能与验收文档继续保留作为历史记录，其源码引用改为 Git 版本，不代表当前能力。
删除后已通过无签名 generic iOS Simulator 构建，并检查更新文档的链接均不再指向已删除目录。

## 2026-09-28 Live Photo 自动降级与启动性能日志

普通照片只要求相机与相册 add-only 权限。Live 偏好开启且麦克风权限尚未决定时，
`CameraAccess` 仍申请麦克风权限；拒绝或受限后继续进入普通拍照，不再要求用户先关闭 Live。
启动、主动开关、镜头切换和会话恢复都以当前支持能力与权限为准，发布实际 Live 状态：

- 当前镜头不支持 Live、麦克风拒绝/受限、麦克风设备缺失、设备输入创建或接入不可用时，
  自动暂停 Live 并移除音频输入，保持普通照片可用。页面 Live 图标和每次拍摄采用实际模式，
  显示可关闭的降级原因提示；权限拒绝或受限时可进入系统设置。
- 用户的持久化 Live 偏好保留。重新进入、恢复会话或切回支持的镜头时重新尝试该偏好，
  成功后恢复实际 Live 模式。用户在已经启用 Live 时主动关闭，清除偏好与降级提示。
- 无法替换视频输入、设备配置失败或会话无法运行仍按配置错误处理，不伪装成普通照片成功。
  切换失败时恢复原视频输入、音频输入、Live enabled/suspended 与镜像状态。
- 已在目标模式时允许恢复流程幂等重用；需要改变模式时仍不能与未完成的采集重叠。
  权限请求任务离开页面后失效，旧 Live 配置回调不能覆盖新启动周期的实际状态。

按 [Apple 的 Live 支持说明](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesupported)，
支持能力会随会话预设和设备格式变化；镜头切换后重新查询并配置。
继续在会话停止时预先启用支持 Live 的输出管线，运行中通过
[isLivePhotoCaptureSuspended](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesuspended)
切换模式，避免反复修改 enabled 所触发的管线重建。保持现有启动顺序和拍摄质量设置。

新增 `CameraSessionPerformance`，通过 `Logger.info` 在 Debug 和 Release 记录
`[CameraSession]`。每次权限操作、启动、恢复、切换镜头、Live 配置或停止具有独立 UUID；
同一次启动的串行队列、会话配置和 Live 配置沿用一个 UUID。每行包含 `build`、`operation`、
`phase`、`duration`（本阶段毫秒）、`elapsed`（操作开始后的累计毫秒）、`outcome` 与 `detail`。
结果区分 `success`、`fallback`、`failure`、`interrupted`、`cancelled` 和 `skipped`。
`Logger` 在 iOS 14 起可用，`ContinuousClock` 在 iOS 16 起可用，覆盖工程最低 iOS 18。
使用 Xcode 或 Console 采集时启用 Info 级别并筛选 `CameraSession`；这些日志默认写入系统内存
日志存储，不增加应用自己的日志文件。

| 阶段 | 时间边界与说明 |
| --- | --- |
| `begin` | 操作计时起点，便于定位未完成的操作 |
| `permission_check` / `permission_request` | 权限检查或请求；请求耗时包含系统授权弹窗等待，也可能直接返回已决定的权限 |
| `permissions_total` | 一次权限操作总耗时，麦克风不可用标为 fallback；与会话启动分开计时 |
| `session_queue_wait` | 会话命令提交至串行队列开始执行 |
| `camera_permission_check` | 会话队列上的相机授权校验 |
| `session_configuration` | 创建输入、接入输出、预置 Live/响应式采集与设备初始配置；已配置的会话标为 skipped |
| `session_start` / `session_stop` | 同步 `startRunning` / `stopRunning` 调用 |
| `live_photo_queue_wait` / `live_photo_configuration` | Live 命令排队及实际配置/降级耗时，detail 记录原因 |
| `live_photo_result` | Live 配置返回 MainActor 的结果，累计时间包括返回队列等待 |
| `startup_total` / `recovery_total` | Controller 命令开始至会话运行且实际 Live 模式发布；记录当前镜头与请求/实际 Live 状态 |
| `capture_ready` | 启动或恢复后首次满足系统 readiness 与保存任务数量上限的累计耗时；停止/中断前未就绪则记录相应结果 |
| `switch_total` / `stop_total` | 切换镜头或停止操作累计耗时 |

`startup_total` 不包含进入页面前的导航、权限弹窗或 SwiftUI 布局；`capture_ready` 也不表示首帧
预览已显示。它们不与不同 UUID 的权限耗时直接相加。现有 `[CameraCapture]` 拍摄到保存日志
保持原范围，本次不新增 JPEG 对照采集或预热优化。

已通过无签名 generic iOS Simulator 的 Debug 与 Release 构建，确认 Release 产物保留日志。
临时 macOS 替身检查运行真实 Controller，以及从当前 Access/Engine 提取的权限流程、启停、
切换、Live 配置与能力发布方法，覆盖权限拒绝/受限、麦克风缺失/创建失败/接入失败、不支持
Live 的前置降级、切回后置恢复、采集中幂等配置、权限请求取消、旧回调失效和输入/设备锁/
启动失败回滚。该检查不会启动相机，
不能替代实际 AVFoundation 输入协商、预览和成片验收。仍需真机验证拒绝麦克风后普通拍照、
支持能力变化后的镜头切换、系统设置授权后重入，以及采集一份 Debug/Release 启动日志。

## 2026-09-28 优先使用 HEIF

`CameraEngine` 在会话启动、切换镜头和恢复后，从已接入视频输入的照片输出查询
`availablePhotoCodecTypes`。当前输出支持 `.hevc` 时，每次拍摄创建 HEIF 设置；否则使用默认
JPEG 设置。普通照片与 Live Photo 的静态照片采用同一选择。照片处理继续按实际源文件类型
编码裁切、旋转和水印后的像素，保留源照片元数据，包括 Live Photo 配对标识。

选择方式遵循 [Apple 的照片采集示例](https://developer.apple.com/documentation/avfoundation/capturing-still-and-live-photos)
与 [availablePhotoCodecTypes](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/availablephotocodectypes)。
HEVC 照片编码在 iOS 11 起可用，覆盖工程最低 iOS 18。继续使用 `.balanced` 拍摄质量和
Image I/O 默认编码质量；本次没有调整视频处理或增加预热。

Debug 日志保留每张照片从快门到相册写入完成的同一 UUID 和时间轴，并增加当前镜头、请求
编码、实际输入与输出类型、文件字节数、最终像素尺寸，以及 `photoEncodeStarted` 编码起点。
Live Photo 额外记录原视频时长和关键照片在视频中的时间，以便辨别视频工作量差异。

耗时直接与已有采集数据比较，不新增 JPEG 对照开关或对照采集流程。相同设备、镜头、比例、
闪光灯与 Live 模式分别统计首拍和后续拍摄，关注以下边界：

| 指标 | 时间边界 |
| --- | --- |
| 采集完成 | `shutter` → `captureDelivered` |
| 静态照片解码、裁切与水印 | `photoProcessingStarted` → `photoRendered` |
| 静态照片编码 | `photoEncodeStarted` → `photoProcessingFinished` |
| 与旧日志比较编码阶段 | `photoRendered` → `photoProcessingFinished`，包含元数据准备 |
| 相册写入 | `libraryWriteStarted` → `saved` |
| 总等待 | `shutter` → `saved` |

Live Photo 的静态照片和视频处理可以并行，不能把两段耗时相加当作总等待；同条件视频转码
耗时也应单独核对。`saved` 表示 PhotoKit 写入成功，不包含相册界面的缩略图刷新。

已通过无签名 generic iOS Simulator 构建。临时替身依赖检查真实 `CameraController` 的普通/
Live 编码选择、不支持 HEIF 时回退、切换与恢复后能力更新、旧回调失效和每拍独立设置。
另在 macOS 执行真实 `CameraPhotoProcessor` 的 Image I/O 编码路径，验证 HEIF 输入与输出
类型一致、像素可解码、尺寸与方向标签、Live Photo 配对标识、EXIF/GPS 保留及无效输入失败。
该检查替换了 UIKit 绘制，不验证 iOS 水印、镜像或实际相册 Live Photo 播放，也不用于测量
iPhone 编码速度。

2026-09-28 真机日志包含六张 Live 与随后三张普通照片，均成功保存为 HEIC。与最近同尺寸、
带水印且并行处理的 JPEG 记录比较，后续拍摄总保存中位数：普通约 729 → 888 ms，Live
约 3004 → 3247 ms；照片编码分别增加约 29 / 49 ms。采集、视频处理与相册写入也有变化，
不能把全部总时间差归因于 HEIF。首张 Live 为 4099 ms，仍在历史首次拍摄波动范围内。
逐张数据、旧日志来源与比较边界见 [HEIF 真机比较](ios-camera-heif-validation-2026-09-28.md)。
各比例与横竖方向、水印、前置镜像，以及 Live Photo 的动态播放和声音仍需成片验收。

## 2026-09-28 会话中断与运行时错误恢复

`CameraController` 在当前页面启动周期内监听相机会话的中断、中断结束与运行时错误通知。
通知只匹配自己的 session，UI 状态在 MainActor 上更新；停止或离开页面时取消观察并使旧启动、
切换和恢复回调失效，旧通知不能在后台或离开页面后重新启动相机。

- 中断时暂停快门与设备控制，显示相机暂时不可用。中断结束后自动尝试恢复；音频或视频设备
  被其他客户端占用时额外提供重试按钮，用户可以主动请求恢复。
- 媒体服务重置（`mediaServicesWereReset`）发生前相机已成功启动时，自动尝试恢复当前会话。
  恢复过程中再次发生运行时错误、初次启动失败或其他运行时错误，停止会话并提示用户重试，
  不循环重启。
- 恢复继续使用当前视频输入与照片输出，重新校验相机权限、读取真实镜头能力，并同步最后
  请求的 Live Photo 偏好，并按当前能力发布实际模式（见自动降级章节）。已经处于目标模式时
  不重配正在完成的拍摄；需要实际切换模式时仍禁止与采集重叠。权限请求继续由
  `CameraAccess` 管理。
- 清除旧点按反馈与手势状态；成功恢复时回到中心连续自动对焦、自动测光和 `0 EV`。倍率按
  当前设备实际值重新发布，前置尚未完成的倍率动画落到已选取景档位。
- 中断前已经发起的拍摄继续接收系统成功或失败回调；这些旧回调不能把暂停或恢复中的页面
  改回就绪。已经交给 `CameraPhotoSaver` 的资源继续处理和写入相册。

参考 [Apple 的会话状态通知](https://developer.apple.com/documentation/avfoundation/avcapturesession)、
[startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning())
与 [AVCam 示例](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)。
同时核对 AVCam 的运行时错误、设备占用中断与主动恢复源码：媒体服务重置后重启已有会话，
恢复失败时交给用户重试。会话启停和设备配置继续在已有串行会话队列执行。当前 SDK 中三项
通知在 iOS 4 起可用，中断原因在 iOS 9 起可用，覆盖工程最低 iOS 18。

已通过无签名 generic iOS Simulator 构建；另以临时替身依赖执行真实 `CameraController` 的
通知与生命周期检查，覆盖中断结束、媒体服务重置、旧恢复与切换回调失效、保存继续执行、
一般运行时错误和重复恢复错误不会循环重启。该检查不启动摄像头，也不代替 AVFoundation
真机行为验收。用户已完成简单真机试用，反馈未发现问题；电话或设备占用、Live Photo
拍摄中断、媒体服务重置以及暂停后离开页面的实际恢复效果尚未逐项验收。

## 2026-09-23 优先级调整

第一阶段的产品核心改为先完成接近 iPhone 系统相机的基础拍照能力：后置相机实时预览、
连续捏合缩放、按当前设备支持的倍率快速切换，以及选择 `1:1`、`3:4`、`9:16` 并保存相应
比例的竖屏照片。下文第 9 节和第 11 节中“先固定 zoom、后实现缩放”的实施顺序已被此决定取代。

横排保存复用同一套竖屏预览与裁切：先得到完整的竖屏成片，再将整张像素矩阵旋转
90 度。真机验证中，两种横握姿态下 `UIDevice.orientation` 都报告 `portrait`，无法用于区分
左右；Core Motion 的重力向量可以区分：以屏幕正对用户为准，手机向左转时 `gravity.x` 为负，
向右转时为正。自动模式在按快门时读取重力；仅当 `|x| ≥ 0.5` 且 `|x| > |y|` 时按其符号选择
旋转方向。方向不够明确时依次采用设备报告的横握方向、本次相机页面最后一次明确的横握方向，
最终默认向左旋转。保存方向菜单已在 2026-09-24 的核心拆分中移除，由比例选择直接决定输出：
`3:4`、`9:16` 固定竖版，`4:3`、`16:9` 使用横版自动旋转，`1:1` 自动确定画面内容方向。
该选择不修改预览、缩放或裁切矩形。
竖屏、左右横握及三种尺寸的保存结果已通过真机手动验证。

倍率按钮对应设备实际可用的虚拟摄像头切换点和常用数字倍率；物理镜头是否切换由
AVFoundation 根据设备与场景决定。三种尺寸表示输出宽高比，不预设固定像素尺寸。模板引导、
Live Photo、前后切换与曝光控制在此基础拍照链路稳定后继续推进。预览与照片四边内容的精确
对应仍需真机验证，不能仅以比例正确代替取景一致性的验收。

## 2026-09-26 前置相机接入

状态：已按下列确认行为接入正式相机页，并通过无签名的模拟器目标构建；实际取景、镜像与
屏幕补光效果仍需真机验收。本机当前安装的是 Xcode 27，沿用工程 Swift 5 和 iOS 18 设置构建，
未修改语言模式或部署版本。

- 前置只提供宽、窄两档自拍取景，不提供中间快捷选项。“宽、窄”表示自拍取景范围，
  不直接采用设备允许的最小、最大缩放倍率；具体倍率仍需按设备能力与真机取景效果确认。
- 前置捏合用于切换宽、窄档位，不能通过手势停留在两档之间或扩大到两档之外。按用户确认
  的方向，双指收拢切到窄档，张开切到宽档。两档切换动画可以经过中间倍率，最终落在所选
  档位。后置保留现有快捷倍率与连续捏合缩放。
- 每次前后切换都重置倍率，不记住或恢复此前的取景。切到前置时默认使用宽档，
  切回后置时回到既有的 `1×` 初始倍率。
- 前置闪光灯沿用当前的关闭、自动、开启三种模式及切换顺序；关闭时不补光，自动模式由系统
  判断是否补光，开启时按下快门进行短暂的全屏屏幕补光，拍摄后恢复正常取景。模式可用性
  仍按当前设备能力查询。
- 前置预览与保存照片都采用镜像，使蒙版构图时的左右位置与成片一致；用户接受成片中的
  文字也会左右反转。蒙版本身不因前置镜像而翻转。

补光已沿用系统闪光灯拍摄设置，前置使用设备支持的 Retina Flash。Apple 的
[Retina Flash 说明](https://developer.apple.com/library/archive/documentation/DeviceInformation/Reference/iOSDeviceCompatibility/Cameras/Cameras.html)
指出，支持的前置设备通过既有闪光灯能力提供屏幕补光，并会调整屏幕亮度与色温。
拍摄设置使用当前的
[AVCapturePhotoSettings.flashMode](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/flashmode)，
切换设备后重新查询 `supportedFlashModes`。系统补光的颜色与实际效果需真机验证，当前未添加
自定义白色覆盖层。

实现细节：

- 宽档使用当前前置设备的最小可用倍率，窄档采用宽档的 `1.3` 倍中心裁切，并限制在设备可用
  范围内。这是本次可逆的取景基线，不表示 Apple 提供了固定的窄档倍率或已与系统相机完全
  对齐。若设备无法提供不同的窄档，只显示可用的宽档，避免两个按钮对应同一取景。
- 前置快捷切换沿用系统 ramp 与 Reduce Motion 行为。拍照或停止会话时，尚未结束的前置
  动画直接落到已选档位，避免成片或恢复后的预览停留在中间倍率。
- 前置捏合相对起始距离收拢至 `0.9` 或张开至 `1.1` 时选择对应档位，轻微移动不触发；同一次
  手势只选择一个档位，继续同向捏合不重复发出命令，反向切换可松手后再次捏合。
  `GestureState` 保存本次目标，正常结束或取消时自动清除，复用现有快捷倍率命令。
- `CameraEngine` 在串行会话队列中替换视频输入，保留同一会话、照片输出与已有音频输入。
  切换期间禁止拍照和设备控制；新设备无法接入或设备配置失败时恢复原输入与音频状态。
  Live Photo 不支持时成功切换并降级为普通照片（2026-09-28 更新）。真正失败时 UI 重新读取
  原设备能力，并提示切换失败。
- 切换成功后重新发布倍率、曝光和闪光灯能力，清除旧对焦反馈，曝光补偿回到 `0 EV`。
  旧设备的异步缩放、对焦与曝光回调不会覆盖新设备状态。
- 预览连接与照片输出连接都显式关闭自动镜像调整，前置开启镜像，后置关闭镜像。现有照片
  处理通过 `UIImage` 解读方向标签，Live Photo 视频处理继续解读 track 的 `preferredTransform`；
  蒙版不参与镜像变换。普通照片与 Live Photo 的左右位置及最终旋转仍待真机验证。

会话替换参考
[Apple AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)，
镜像设置参考
[isVideoMirrored](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored)
与 [automaticallyAdjustsVideoMirroring](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/automaticallyadjustsvideomirroring)。
本次使用的前置设备发现、连接镜像及照片闪光灯 API 均可用于工程最低版本 iOS 18。

捏合状态处理参考 [Apple 的手势说明](https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures)
与 [updating(_:body:)](https://developer.apple.com/documentation/swiftui/gesture/updating(_:body:))，
已核对其在 iOS 13 起可用。另核对
[Zoomable 的实际源码](https://github.com/ryohey/Zoomable/blob/main/Sources/Zoomable/Zoomable.swift)：
其在手势变化时处理缩放，结束时限制结果；本项目保留实时手势响应，前置仅选择预设档位，
没有采用它对图片的自由缩放与平移。

真机验收：宽、窄档取景与捏合切档、轻微移动不误触、手势取消后可再次切档；每次切换的倍率
重置；点击测光与曝光控制；关闭、自动、
开启三种闪光模式；所有已支持输出比例下普通照片与 Live Photo 静态图、配对视频的镜像、裁切
和方向一致性；连续拍摄、快速切换与离开后恢复的状态。

## 2026-09-26 连续缩放范围对齐

连续捏合与快捷倍率的有效范围统一使用设备当前的最小可用倍率，以及
`min(maxAvailableVideoZoomFactor, oneXFactor * 25)` 的上限。
`oneXFactor` 与快捷按钮的显示基准共用同一计算方式，使显示倍率最高为 `25×`；设备支持范围
更小时使用设备上限。移除内部倍率 `10` 的固定上限。
在 `1×` 对应内部倍率 `2` 的虚拟相机上，原限制会将显示倍率截断在 `5×`。
用户真机反馈仅按设备最大可用倍率限制会超过 `25×`，因此确认本次拍照显示上限为 `25×`。
快捷按钮仍表示现有常用倍率与虚拟摄像头切换点，更高倍率通过捏合达到，按当前 `1×` 基准显示。
需在此前支持 `25×` 的真机上验收上限，确认继续捏合也不会超过该值。

依据：[Apple 的 maxAvailableVideoZoomFactor 文档](https://developer.apple.com/documentation/avfoundation/avcapturedevice/maxavailablevideozoomfactor)
将此属性定义为当前采集配置允许的最大倍率。此改动沿用已有 API，不改变设备选择或缩放动画。
同时核对 [NextLevel 的缩放源码](https://github.com/NextLevel/NextLevel/blob/2fa42500caf7edd7136d23b64d9ecb5684d93d07/Sources/NextLevel.swift)：
其在设备赋值前限制最小倍率与 format 最大倍率。本项目沿用限制后赋值的方式，使用当前配置的
最大可用倍率与已确认的显示上限共同决定边界。

## 2026-09-26 初始显示倍率为 1×

相机首次配置时，在设置 `.photo`、接入输入与照片输出并提交会话配置后，设置初始倍率。
默认值复用快捷按钮的 `oneXFactor`，并限制在当前设备的可用范围内；启动后将设备实际倍率
返回页面，让画面与选中的 `1×` 按钮一致。已配置会话的暂停与恢复继续沿用当前倍率。
此调整修正原实现先设置倍率、后接入会话的顺序。需真机验证全新打开相机时直接显示 `1×`。

## 2026-09-26 快捷缩放动画

用户真机对比后接受系统缩放动画，正式快捷倍率切换统一使用
`AVCaptureDevice.ramp(toVideoZoomFactor:withRate:)`。移除按时间逐帧赋值的自定义动画、
临时对比开关、报告观察器和验证入口。物理镜头选择仍由 AVFoundation 决定。

速率沿用本次验证时的参数：按倍率比值的 `abs(log2(target / current))` 计算跨度，
名义时长为 `min(0.15 + max(distance - 1, 0) * 0.04, 0.20)` 秒，速率为跨度除以名义时长。
系统会平滑加速度，因此这两个时间参数不保证实际完成时长。

连续点击先停止当前动画，再从设备当前倍率转向新目标，不排队累积动画。
捏合以设备当前倍率为起点立即接管，停止会话时也停止缩放；开启“减弱动态效果”时
快捷倍率直接赋值。按钮立即选中目标倍率，重新进入相机时读取设备实际倍率。

### 本次参考来源

记录日期：2026-09-26。以下源码链接固定为记录时重新核对的提交，方便追溯；这些库仅作
实现参考，未作为依赖引入 Framewise。

| 项目 | 核对位置 | 与本次改动相关的处理方式 |
| --- | --- | --- |
| VisionCamera V5 | [HybridCameraController.swift，提交 `91bae1f`](https://github.com/margelo/react-native-vision-camera/blob/91bae1f08d549b50444ee16661dc4f4375cba0b6/packages/react-native-vision-camera/ios/Hybrid%20Objects/HybridCameraController.swift#L319) | `startZoomAnimation(zoom:rate:)` 直接调用系统 `ramp`，按速率驱动；通过 `isRampingVideoZoom` 观察完成，另有 `cancelZoomAnimation()`。这是本次改用系统动画的直接参考。 |
| NextLevel | [NextLevel.swift，提交 `2fa4250`](https://github.com/NextLevel/NextLevel/blob/2fa42500caf7edd7136d23b64d9ecb5684d93d07/Sources/NextLevel.swift#L2446) | `videoZoomFactor` setter 在会话队列中锁定设备，限制倍率范围后直接赋值。用于对照设备控制方式，该路径没有提供快捷倍率动画。 |
| Mijick/Camera | [CameraManager.swift，提交 `0f02348`](https://github.com/Mijick/Camera/blob/0f02348fcc8fbbc9224c7fbf444f182dc25d0b40/Sources/Internal/Manager/CameraManager.swift#L191)；[CaptureDevice.swift](https://github.com/Mijick/Camera/blob/0f02348fcc8fbbc9224c7fbf444f182dc25d0b40/Sources/Internal/Manager/Helpers/Capture%20Device/CaptureDevice.swift#L59) | `setCameraZoomFactor` 锁定设备后调用 `setZoomFactor`，最终限制范围并直接写入 `videoZoomFactor`。用于对照缩放入口与设备赋值方式。 |

官方依据：[Apple 的 ramp 文档](https://developer.apple.com/documentation/avfoundation/avcapturedevice/ramp(tovideozoomfactor:withrate:))
说明速率以倍率的倍频变化计算，内部会平滑加速度；[videoZoomFactor 文档](https://developer.apple.com/documentation/avfoundation/avcapturedevice/videozoomfactor)
说明直接赋值会取消正在进行的 ramp。本项目据此用当前倍率赋值实现立即接管，未照搬
VisionCamera 使用 `cancelVideoZoomRamp()` 的平滑停止方式。

在上述查阅的缩放路径中，未发现按 iPhone 型号应用固定画面偏移补偿的实现；这不代表这些
项目的所有功能都不存在相关处理。本次最终选择依据是用户对当前真机系统动画效果的认可，
没有继续引入双摄预采集或几何补偿。

## 2026-09-23 Live Photo 接入

首次开启 Live Photo 时由用户在相机页主动操作；`CameraAccess` 通过权限模块请求麦克风权限。
原首版 `CameraEngine` 在会话停止期间接入音频输入并启用 Live Photo 能力；2026-09-27
已调整为下节的提前准备与暂停方式。普通照片仍可使用同一个输出。按快门时分别取得静态照片
数据和配对短视频文件；取得完整资源前
保持拍摄状态，避免覆盖尚未完成的请求。后续处理与相册写入按 2026-09-24 的异步保存规则执行。

静态照片沿用当前竖屏居中裁切及最终旋转，并在重新编码时保留原始元数据中的 Live Photo
配对标识。短视频按自身的方向元数据归一化到竖屏，进行相同比例的居中裁切与同方向旋转，
保留影片元数据，再与静态照片作为同一相册资源保存。临时视频文件在保存或失败后清理。
如果原始短视频的正立尺寸已经等于目标比例且不需旋转，则直接使用原文件，避免重新编码；
其余情况仍需导出变换后的短视频。保存成功不再显示提示。
Live Photo 的拍摄、相册播放与相关输出组合已由用户在真机验收。

## 2026-09-27 Live Photo 开关减少预览中断

用户反馈 Live Photo 开关时预览闪动。代码审查确认原开关都会停止、重启会话，并改变
`isLivePhotoCaptureEnabled`；Apple 明确说明运行中改变该属性需要较长的管线重配置，
会暂时冻结预览。这是本轮处理的明确中断来源，尚无真机阶段日志证明它覆盖所有闪动原因。

改为在首次启动前及前后镜头替换的停止阶段，为支持的设备准备 Live Photo 管线。
用户关闭 Live 时设置 `isLivePhotoCaptureSuspended = true`；开启时接入麦克风后恢复。
开关本身不再调用 `stopRunning()` / `startRunning()`，也不再改管线 enabled 属性。
音频输入通过运行会话的 `beginConfiguration()` / `commitConfiguration()` 增删：首次开启
仍须请求麦克风权限，关闭后移除音频输入；仅准备 Live 能力不主动接入麦克风。

普通照片仍不给 `livePhotoMovieFileURL`，只有本次明确选择 Live 才生成配对视频。
Live 请求同时检查已准备、未暂停和音频输入存在；采集期间不能改 Live 配置。
添加音频后配置不可用或会话意外停止时，移除新输入并报告失败，不留下已开启音频的半成状态。

保留暂停状态跨会话停止与恢复；前后镜头切换重新查询支持能力并设置当前模式，失败回滚
同时恢复原 enabled 和 suspended 状态。页面启动无论 Live 偏好开关都同步一次音频和暂停
状态，避免失败重试后留下旧麦克风输入。刚开启后的 Live 片段不会包含恢复前的缓存。

参考 [Apple Live 管线属性](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocaptureenabled)、
[暂停属性](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesuspended)
与 [运行会话的原子配置](https://developer.apple.com/documentation/avfoundation/avcapturesession/beginconfiguration())；
同时核对 [AVCam 源码](https://github.com/AppTyrant/AVCamBuildingACameraApp/blob/master/Swift/AVCam/CameraViewController.swift)：
它提前准备 Live 管线，开关修改本次拍摄模式，逐次请求用视频 URL 决定是否生成 Live。
本项目额外在关闭时暂停并移除麦克风，不照搬示例持续保留音频输入的配置。
`preservesLivePhotoCaptureSuspendedOnSessionStop` 在 iOS 16 起可用，覆盖最低 iOS 18，
已核对当前 SDK；工程 Swift 模式和部署版本保持不变。

已通过规定的无签名 generic iOS Simulator 构建及独立代码审查，实际无闪动效果仍需真机
确认。运行中增删音频输入并不保证所有设备完全不中断预览，首次
系统权限弹窗也可能触发页面暂停；本轮未加入冻结帧覆盖或额外的视频帧采集。

## 2026-09-24 对焦、曝光与闪光灯控制

相机页点击预览时，由 `AVCaptureVideoPreviewLayer` 将点击位置换算到设备坐标，再对支持的设备
设置连续自动对焦与连续自动测光的兴趣点。曝光滑杆按设备支持的 EV 范围调整曝光补偿，重置为
`0 EV`。闪光灯提供设备当前支持的关闭、自动和开启模式，并在每次拍摄的照片设置中指定；
普通照片与 Live Photo 走同一个拍摄入口。这些控制已通过模拟器目标编译，并由用户在真机验收。

## 2026-09-26 点击对焦时重置曝光补偿

每次点击预览进行对焦与测光时，在同一次设备配置中将曝光补偿恢复为 `0 EV`。
配置成功后同步重置页面曝光状态，使新位置的曝光滑杆显示默认值；失败时保留已有曝光值，
沿用现有对焦失败提示。用户随后仍可针对新位置调整曝光补偿。
已通过模拟器目标编译，需真机验证调亮、调暗后点击新位置的画面与滑杆均恢复自动曝光基准。

## 2026-09-26 非零曝光的控件保留与淡化

点击对焦或结束曝光调整后，闲置计时为 `3.5` 秒。曝光为 `0 EV` 时仍移除对焦框与曝光条；
曝光不为零时保留两者，将整体不透明度在 `0.25` 秒内降至 `50%`，曝光补偿保持原值。
淡化仅影响显示，保留黄色、触摸区域与拖动手势。
真机反馈首版对整个交互容器降低不透明度后，曝光条无法继续拖动。后续改为只淡化绘制内容，
曝光条使用独立的透明矩形与明确的 `contentShape`、`allowsHitTesting` 接收原有拖动手势，
绘制内容不参与触摸检测。用户已在真机确认此修复有效；未据此断言系统在特定不透明度下的内部行为。
再次触碰曝光条时立即恢复正常显示、取消闲置计时，同一次拖动直接调整曝光，无需额外点击唤醒。
松手后重新计时；将曝光调回 `0 EV` 后也等待 `3.5` 秒再消失，拖动过程中保持正常显示。
点击新对焦位置恢复正常显示，并沿用曝光归零规则。拍照不主动清除非零曝光的控件。
开启“减弱动态效果”时直接切换不透明度，不播放淡化动画。
淡化后的直接拖动与恢复显示已由用户在真机确认；零曝光自动消失和连续拍摄时的控件保留仍待验收。

## 2026-09-27 场景变化时退出点按对焦

点按预览后，开启当前设备的 `isSubjectAreaChangeMonitoringEnabled`，使用
`AVCaptureDevice.subjectAreaDidChangeNotification` 判断主体区域明显变化。该系统通知也可能由
光照变化触发，不等同于仅检测手机移动。首版仅使用系统主体变化通知。

收到通知后，将对焦、测光兴趣点恢复为设备中心，保持连续自动对焦与连续自动曝光，将曝光补偿
恢复为 `0 EV`；设备配置成功后同步清除页面的对焦框、曝光条和闲置计时。配置失败时保留原有
页面状态并沿用对焦失败提示。`EV` 归零是本次确认的产品规则，不是系统通知自带的行为。

正在拖动曝光条或采集照片时，记录这次选择的待退出状态，待拖动结束、拍摄完成且页面重新可操作
后处理。新一次点按取代旧选择和待退出状态，旧通知、对焦及曝光回调不能覆盖新的选择。
`3.5` 秒闲置隐藏对焦框只影响反馈显示，场景变化监测继续有效。未发生场景变化时，沿用非零
曝光保留与淡化规则，拍照本身不清除选择。

离开相机、暂停会话或切换设备时结束旧点按选择并移除旧设备观察；下一次点按重新开启监测。
实现参考 [Apple 的主体区域变化文档](https://developer.apple.com/documentation/avfoundation/avcapturedevice/subjectareadidchangenotification)
与 [AVCam 源码](https://github.com/AppTyrant/AVCamBuildingACameraApp/blob/master/Swift/AVCam/CameraViewController.swift)
中恢复中心连续对焦、测光的处理方式。
移动触发灵敏度、非零曝光恢复和拖动期间延后退出的实际效果待真机验收。

首次真机反馈：调整非零曝光后，多次上下、左右改变取景内容仍未退出选择，灵敏度不符合预期。
排查时曾在 Debug 构建记录监测启用、原始通知来源、事件转发和页面重置阶段；日志统一以 `[CameraFocus]`
开头。用户提供的后置 `1×` 日志确认：三摄虚拟设备在 `EV=-2.4` 后收到主体变化通知，设备与
页面选择判断通过，并完成中心对焦与曝光归零。该日志证明一次完整链路有效；没有时间戳，不能
据此判断通知延迟，也不能将系统主体变化通知等同于可靠的手机移动检测。

用户确认增加最小移动检测实验：复用现有 `10 Hz` Core Motion device-motion 采样，记录点按
时的姿态，镜头朝向相对该姿态变化约 `30°` 时请求同一个退出流程。首版使用 `15°`，用户真机
确认接受移动检测方案后要求调整为 `30°`，并移除本次聚焦调试日志。该角度是产品阈值，不是
Apple 推荐值。比较旋转矩阵中设备 Z 轴在参考空间的方向，忽略绕镜头轴旋转，因此
单纯竖横屏切换不退出；小幅手抖不退出，累计转向从点按时计算，调整曝光不重新建立参考。
正在拖动或拍摄时仍记录待退出状态，结束后处理；新点按重建参考，退出选择或停止会话时移除
移动监测。超阈值只报告一次，早于新点按参考的排队采样不能触发退出。

系统主体变化通知与 `30°` 朝向变化并行，任意一路触发即请求退出，不要求两者同时满足；系统
通知可能在转动不足 `30°` 时先触发。Core Motion 不可用时沿用系统通知。仅平移手机而朝向不变无法靠
姿态可靠判断，仍依赖系统通知。方向计算与编译已通过本机验证，移动检测方案已由用户真机
确认接受；调整为 `30°` 后的灵敏度及拖动期间延后的实际体验待真机验收。实现依据 [Apple 的设备运动数据文档](https://developer.apple.com/documentation/coremotion/getting-processed-device-motion-data)
与 [姿态旋转矩阵 API](https://developer.apple.com/documentation/coremotion/cmattitude/rotationmatrix)。

## 2026-09-24 蒙版输出方向决策

本节记录现有的照片输出比例与方向规则，不表示蒙版数据直接控制拍摄或保存。照片处理先在竖版
坐标中裁切；蒙版的摆放旋转不改变相机设备、缩放或照片裁切。相机核心不读取 `MaskVariant`；
调用方独立传入照片裁切比例与目标输出方向。
最终旋转只作用于完整的竖版裁切结果，普通照片与 Live Photo 的静态图、配对视频使用同一方向。

- `3:4` 输出选项：保存固定的 `3:4` 竖版照片，不读取握持方向。用户横握拍摄也不改变结果。
- `4:3` 输出选项：先得到相同规则的 `3:4` 竖版裁切结果，再整体旋转 90 度保存为 `4:3`。
  左右旋转沿用已验证的按快门方向策略：先看 Core Motion 重力横向分量；方向不明确时依次看
  系统报告的横握方向、本次相机页面最近一次明确的横握方向，最终默认向左旋转。蒙版摆放时的
  旋转方向不决定照片旋转方向。
- `1:1` 输出选项：始终裁出正方形，以画面内容方向作自动判断。明确竖握时不旋转；明确左、右横握时
  分别旋转 −90、+90 度。按快门时优先依据重力向量中占优的横向或竖向分量；姿态不明确时沿用
  最近一次可靠的握持方向，仍无记录则不旋转。手机接近平放时，重力无法可靠区分其绕屏幕法线
  的转动，因此自动结果有这一边界。输出宽高始终为 `1:1`。

测试阶段的相机页比例菜单提供 `1:1`、`3:4`、`4:3`、`9:16`、`16:9`，不显示独立的
保存方向菜单。正式相机页的比例状态改由当前蒙版更新，见下文“正式相机 UI 接入决策”。
`Core/Camera` 仍不读取 `MaskVariant`。

## 2026-09-24 异步保存与反馈决策

拍摄状态只覆盖相机采集，以及取得后续处理所需的完整资源。普通照片需取得静态照片数据；
Live Photo 还需取得配对视频。资源交付后，相机即可接受下一次拍摄；照片裁切、视频处理和
写入相册作为独立任务继续执行，不占用拍摄状态。每个任务负责保留并清理自己的临时资源。

保存成功时不显示“已保存”提示；只有处理或写入失败时才向用户反馈。失败结果不能因用户离开
相机页面而静默丢失。这里的异步保存指应用进程内不阻塞相机；应用退到系统后台后仍保证完成
属于另一个待讨论的生命周期需求。

`Core/Camera/CameraController` 在采集资源交付后把照片交给 `CameraPhotoSaver` 并释放快门。
保存成功不显示提示；保存失败通过应用根层的通知处理，在离开相机页后仍能反馈。

## 2026-09-27 快门到相册耗时优化

本轮实现集中在资源交付之后的处理和写入阶段，保留 `.balanced` 拍摄质量、现有输出像素尺寸、
竖版中心裁切、静态照片最终像素方向与前置镜像规则。下文记录分阶段实现及真机验证范围。

- 普通照片与 Live Photo 共用 `CameraPhotoProcessor`，将处理后的编码资源交给 PhotoKit。
  原始资源在方向已经为 `up`、无需最终旋转、像素尺寸精确匹配现有裁切结果时直接写入。
  若源方向校正与最终旋转恰好抵消，且无需裁切，则无损复制编码数据并将方向归一为 `up`；
  此时源像素矩阵已经等于目标像素矩阵。其他情况继续渲染像素并编码，不能仅改变 EXIF 方向
  来掩盖与目标比例不符的像素矩阵。
- 图片处理由独立 actor 串行执行，避免连续拍摄时同时展开多张全尺寸位图；Live Photo 使用
  `async let` 让静态图处理与配对视频导出重叠。视频导出成功但静态图失败时也清理导出文件。
- 图像 renderer 使用不透明画布；保存任务使用 `.userInitiated` 优先级。
- 完成处理的临时视频通过 `shouldMoveFile` 交给 PhotoKit，省去中间复制。相册写入完成前
  保留资源，成功或失败后执行原有清理，失败仍通过根层通知反馈。

实现依据是 Apple 的[照片资源保存示例](https://developer.apple.com/documentation/avfoundation/saving-captured-photos)、
[临时文件移交说明](https://developer.apple.com/documentation/photos/phassetresourcecreationoptions/shouldmovefile)
与[不透明渲染画布说明](https://developer.apple.com/documentation/uikit/uigraphicsimagerendererformat/opaque)。
使用的 PhotoKit 文件移交 API 自 iOS 9 可用，renderer 的 `opaque` 自 iOS 10 可用，均覆盖 iOS 18。

Debug 构建中，在 Xcode 控制台筛选 `[CameraCapture]`。同一次快门以 UUID 关联，所有时间使用
单调时钟，单位为从快门命令开始累计的毫秒。`captureSubmitted` 到 `captureDelivered` 覆盖
采集和资源交付；`photoProcessingStarted`、`photoRendered`、`photoProcessingFinished`
区分静态图渲染与编码；视频有独立的开始、结束或直通记录；`libraryWriteStarted` 到 `saved`
是 PhotoKit 写入耗时。`saved` 仅在 PhotoKit 成功回调后记录，不代表相册 UI 或 iCloud 已刷新。

真机对比应固定设备、镜头、场景、光线、比例、闪光灯和 Live Photo 设置，分别记录首次拍摄
与后续至少 10 次拍摄的总耗时，比较中位数和最慢值。还需检查五种比例、前后镜像、左右横握、
Live Photo 播放和声音，以及连续拍摄与离开页面后的保存。首轮代码完成时仅通过无签名
Simulator 目标构建；后续真机结果见下文，未覆盖的组合和内存表现仍待验收。

后续用户提供同一轮连续三张 `4:3` 实测：普通照片从快门到 PhotoKit 成功分别为
`803 / 686 / 673 ms`；Live Photo 为 `4429 / 3168 / 3010 ms`。普通照片渲染及编码为
`275 / 234 / 221 ms`，写入相册为 `59 / 71 / 57 ms`。Live Photo 后两张在约
`2.22–2.35 s` 才取得完整资源，随后视频处理约 `0.67 s`，相册写入约 `0.12–0.15 s`。
Live Photo 第一张的图片、视频处理都更慢，但样本不足以断言是首次初始化开销。

据此追加两个窄路径实验：

- 静态照片仅在 EXIF `right` 加最终 `−90°`，或 EXIF `left` 加最终 `+90°`，且完整像素
  尺寸精确匹配目标时，使用 `CGImageDestinationCopyImageSource` 无损保留编码像素并清除已抵消
  的方向标记。镜像、实际裁切或旋转不能抵消的情况仍走原 renderer。该 API 自 iOS 7 可用。
- 配对视频不需要裁切、只需整体旋转时，使用 `AVMutableMovie` 修改视频轨道的
  `preferredTransform` 并原地写回 movie header，保留原压缩样本、音频及时间元数据。
  视频显示内容、尺寸和镜像映射与原变换一致，编码像素不再为整体旋转重新编码；静态照片
  仍要求规范化像素矩阵。实际需要裁切的视频继续使用原视频合成与导出路径。相关 API 自 iOS 13 可用。

依据 Apple 的[视频方向处理建议](https://developer.apple.com/library/archive/qa/qa1744/_index.html)、
[仅替换 movie header 的说明](https://developer.apple.com/documentation/avfoundation/avmoviewritingoptions/addmovieheadertodestination)
与 [ImageIO 无损复制 API](https://developer.apple.com/documentation/imageio/cgimagedestinationcopyimagesource(_:_:_:_:))。
也核对了 [SDWebImage 的 ImageIO 编解码实现](https://github.com/SDWebImage/SDWebImage/blob/master/SDWebImage/Core/SDImageIOCoder.m)：
其处理 `CGImage` 像素与 EXIF 方向的职责区分适用，但没有把它的通用编码逻辑或依赖引入相机。

新增 `movieRecordingFinished` 区分录制结束与完整文件交付；`photoPixelsReused` 表示静态图
命中旋转抵消路径，`movieTransformUpdated` 表示仅修改视频轨道变换，`movieTranscodeStarted`
表示仍需重新编码。不能仅凭原来 `movieReceived` 的约 `2.2 s` 推断全部时间都在录像。

追加验证：macOS 合成素材覆盖 720 组源方向、比例、尺寸与最终旋转组合，检查无损路径的
像素不变、EXIF 保留和方向归一；非无损分支使用占位 renderer 拒绝，不代替 UIKit 渲染验收。
四组左右旋转与镜像视频验证了显示四角映射、视频/音频/时间元数据的压缩样本及时间戳不变、
配对标识保留，以及移动文件后仍可读取。此验证不代替真机 PhotoKit 配对播放与提速验收。

第二轮真机反馈：用户按竖拍、横拍、竖拍、横拍顺序拍摄四张 `4:3` Live Photo，确认图片无误、
Live Photo 正常播放。四次快门方向快照均为 `turns=-1`，全部命中 `photoPixelsReused` 与
`movieTransformUpdated`。以下单位均为毫秒；图片与视频并行，应用处理列不可再与图片耗时相加。

| 拍摄顺序 | 快门至录制结束 | 录制结束至完整视频 | 资源交付后应用处理 | 相册写入 | 快门至保存 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 竖拍 1 | 1485.7 | 772.6 | 61.4 | 250.4 | 2570.9 |
| 横拍 2 | 1498.3 | 792.7 | 42.6 | 143.0 | 2476.9 |
| 竖拍 3 | 1530.3 | 375.4 | 39.0 | 151.1 | 2096.1 |
| 横拍 4 | 1495.2 | 788.1 | 34.3 | 142.2 | 2460.2 |

应用处理按 `saveStarted` 到 `libraryWriteStarted` 计算，静态图片处理分别为
`34.2 / 16.5 / 13.0 / 12.2 ms`。与上一轮后两张约 `0.67 s` 的视频处理相比，后处理阶段已
明显缩短；总耗时中位数约 `2.47 s`。第三张更快主要来自系统视频收尾缩短约 `0.4 s`，不能
将全部波动算作应用优化收益。这是小样本实测，不能推断跨设备或所有场景的稳定百分比。

同轮用户补充四张 `4:3 / turns=-1` 普通照片，确认结果正常，均命中 `photoPixelsReused`：

| 拍摄顺序 | 快门至资源交付 | 图片处理 | 相册写入 | 快门至保存 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 419.0 | 10.4 | 144.2 | 574.2 |
| 2 | 438.8 | 12.2 | 125.7 | 577.5 |
| 3 | 433.2 | 10.4 | 125.9 | 570.1 |
| 4 | 411.6 | 10.1 | 119.4 | 541.7 |

图片处理按 `photoProcessingStarted` 到 `photoPixelsReused` 计算。总耗时中位数约
`572 ms`，上一轮三张为约 `686 ms`；图片处理从约 `221–275 ms` 降到约 `10–12 ms`。
本轮采集与相册写入时间也有变化，不能将后处理节省量直接当作端到端节省量。

本轮确认范围为该设备的 `4:3 / turns=-1` 普通照片及 Live Photo 竖横拍、正常播放；不据此声明
`turns=+1`、其他比例、前置镜像或后台保存已通过真机验收。当前剩余耗时
主要在完整 Live Photo 资源交付之前，后续若继续优化应单独调查采集和系统文件收尾，避免继续
围绕已降至几十毫秒的应用后处理反复调参。

## 2026-09-28 水印正式逻辑迁入主分支

主分支迁入普通照片、Live Photo 封面和视频的「logo + 蒙版相机」水印。五种比例统一
使用已验证的输出几何：静态图在现有最终绘制中加水印并只编码一次；视频使用复用的
CIContext 和 LivePhotoWatermarkCompositor，按有效区域归一化、模板裁切及最终旋转
合成水印。继续保留相机元数据、Live 配对标识、音轨与时间元数据的导出链路，照片与
视频并行处理，沿用相册写入和临时文件清理逻辑。

正式版本固定开启水印，不提供本轮实验的无水印、C/D 选择或 benchmark 启动参数。
未迁入 B/C/D 串行对照、几何/轨道信息扫描、轮换与重叠检测、Core Animation 图层
对照实现、实验 Scheme 参数，以及新增的细分计时和采集诊断回调。主分支原有的
拍摄/保存生命周期日志保持原样。由于成片始终需要写入水印像素，不保留只在关闭水印
时使用的照片像素复用、视频直通和仅修改 movie header 分支。

实验代码与完整对照能力保留在 `codex/live-photo-watermark-performance` 的提交
`6cf24f2`。下方 2026-09-27 各节是实验演进与验收记录，其中的开关、B/C/D 路径和
计时字段描述该实验提交，不代表主分支仍提供这些接口。

保留的验收结论：全比例 D 真机拍摄后续耗时基本约 3000 ms；此前 4:3 逐张日志的
快门至保存中位数由 C 的 3544.6 ms 降至 D 的 3026.1 ms。首次拍摄偏慢仍是后续
独立优化项，现象数据和定位要求见下方“全比例 D 真机反馈与首次拍摄优化待办”。

迁移验证：规定的无签名 generic iOS Simulator 构建通过；与实验提交逐项核对，
裁切/旋转变换、水印位图生成、Core Image composition 和 compositor 实现一致。
本次不重新宣称做过 42 次导出或真机测量，那些结果属于下方记录的实验阶段。

## 2026-09-27 保存前水印与耗时对照

用户确认普通照片、Live Photo 静态封面及配对视频都加水印。第一版在最终成片右下角显示
`design-system/brand/logo-lens-golden-v4.png` 与固定品牌文字「蒙版相机」，使用白字和半透明
黑底，边距、图标和字号按成片短边缩放。资源由 imageset 符号链接引用品牌源文件。

- 静态图在现有方向归一、居中裁切和最终旋转的同一次 renderer 中叠加，恢复坐标变换后
  绘制水印，保证文字不跟随前置镜像或源 EXIF 旋转。继续只编码一次并传递原相机元数据和
  Live Photo 配对标识。
- 视频共用同一水印位图生成方式，使用独立 CALayer 树和
  `AVVideoCompositionCoreAnimationTool`，在现有视频变换之后合成。水印位图每个视频只生成
  一次，不逐帧绘制文字；逐帧合成的开销包含在视频导出时间内。
- 开启水印时必须修改像素，因而跳过照片直通/无损复用、视频直通/仅修改 movie header
  的快速路径。照片和视频仍并行处理，原有保存与临时文件清理职责不变。

参考 Apple 的 [UIGraphicsImageRenderer](https://developer.apple.com/documentation/uikit/uigraphicsimagerenderer)
及 [Core Animation 视频合成说明](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool)。
renderer 自 iOS 10、Core Animation 视频合成自 iOS 4 可用，覆盖最低 iOS 18。
本机实际安装 Xcode 27；新增的 iOS 27 合成工具 Configuration 初始化使用编译器及运行系统
双重检查，Xcode 26 / iOS 18–26 继续使用原有初始化接口，不修改工程语言模式或最低版本。

Debug 默认开启水印；在 Xcode Scheme → Run → Arguments Passed On Launch 添加
`-CameraDisableWatermark` 后重新启动，可同时关闭照片与视频水印并恢复原快速路径。
Release 始终开启。此参数只用于本轮性能对照，不增加产品设置入口。

控制台筛选 `[CameraCapture]`，按同一 UUID 关联。原 `+…ms` 仍为快门起算累计时间；
新增 `duration=…ms` 是该阶段自身时间：

| 日志 | 含义 |
| --- | --- |
| `watermark enabled=true/false` | 本次照片是否开启水印 |
| `photoWatermarkPrepared duration` | 载入 logo 对象 |
| `photoWatermarkDrawn duration` | 生成水印小位图并叠加到照片，不含整张照片解码和最终编码 |
| `photoEncoded duration` | ImageIO 元数据准备及最终编码 |
| `photoProcessingFinished duration` | 整张照片处理，开启/关闭水印都有此指标 |
| `movieWatermarkPrepared duration` | 水印位图与合成图层准备 |
| `movieExportFinished duration` | 视频导出，包含逐帧水印合成及重编码 |

比较同设备、同镜头、同场景、同比例与方向下的开启/关闭两组，各自分开记录首张和至少
10 张后续拍摄。普通照片与 Live Photo 分组，先用上轮的 `4:3 / turns=-1` 复测，再覆盖
其他比例与镜像。分别比较中位数和最慢值：

1. `photoProcessingFinished duration`：照片处理增量。
2. `movieProcessingFinished - movieProcessingStarted`：视频处理增量。
3. `libraryWriteStarted - saveStarted`：资源交付后的应用处理增量；照片、视频并行，不能相加。
4. `saved - libraryWriteStarted`：相册写入变化；`saved` 的累计时间比较端到端增量。

水印的总损耗包含失去快速路径后新增的解码、整图渲染和重新编码，不能只报告文字绘制时间。
先前实测普通照片总耗时中位数约 572 ms、Live Photo 约 2.47 s 仅作历史参考，本轮需同条件
关闭水印重测基线。当前仅完成无签名 Simulator 目标构建，未启动模拟器或操作真机；具体
毫秒增量、五种比例与前后摄/左右旋转的水印位置、Live Photo 配对播放和声音仍待真机验收。

### 水印首轮真机对照结果

用户提供开启/关闭各 10 张样本，每组前 5 张 Live Photo、后 5 张普通照片，均为
`4:3 / turns=-1`，全部成功保存。以下为各组 5 张中位数，单位 ms：

| 类型 | 阶段 | 关闭 | 开启 | 中位数差 |
| --- | --- | ---: | ---: | ---: |
| 普通照片 | 交付后处理 | 13.1 | 235.2 | +222.1 |
| 普通照片 | 相册写入 | 128.9 | 54.9 | −74.0 |
| 普通照片 | 快门至保存 | 539.5 | 692.2 | +152.7 |
| Live Photo | 交付后处理 | 38.2 | 1370.6 | +1332.4 |
| Live Photo | 相册写入 | 151.6 | 131.8 | −19.8 |
| Live Photo | 快门至保存 | 2535.3 | 3752.0 | +1216.7 |

静态图水印绘制中位数 16.6 ms，视频水印准备 17.4 ms，视频导出 1332.8 ms。
Live Photo 第一张封面处理 930 ms，后四张 225–288 ms；视频导出第一张 1822 ms，
后四张 1125–1383 ms。各阶段中位数不可相加；采集、写入波动不能归为水印收益或损耗。
这些日志确认了时间基线，不代表新增水印的画面、颜色或所有方向已获用户验收。

### 首轮实验记录：同一 MOV 的 B/C/D 导出对照

Debug 启动参数 `-CameraWatermarkBenchmark` 启用对照。保持水印开启，移除
`-CameraDisableWatermark`；该轮实验时默认由 Core Animation 生成并保存正式 Live Photo。
当前默认策略见下方“全部比例统一使用 Core Image”。
在 `saved` 之后、删除原始 MOV 之前，串行对该原始资源运行：

- B：保持相同裁切旋转、最高质量 preset，强制导出但不加水印，不能命中直通/header 路径。
- C：当前 Core Animation 水印。
- D：Core Image 水印，复用 `CIContext`、关闭视频中间结果缓存，每个视频只生成一次水印图。

执行顺序按拍摄轮换 `B,C,D` → `C,D,B` → `D,B,C`。同一时刻只允许一组对照；
测试导出不写入相册，成功或失败均清理临时输出。正常 `saved` 不包含后续对照时间。
正式保存会提前运行一次 C，因此这组对照是已有拍摄流程下的测量，不是三条路径的冷启动比较。

D 首轮只覆盖无需裁切的完整画面，针对当前实测的 `4:3`（也支持无裁切的 `3:4`）。
使用 `LivePhotoWatermarkCompositor` 显式设置输出尺寸；先按每帧 clean aperture 提取
有效画面，再应用与 B/C 相同的方向变换，最后叠加水印。不修改原始文件或创建另一份 MOV。
检测到模板裁切时 D 仍明确失败，不能把失败算成更快的导出；这是当前实验覆盖范围的限制。
正常产品的其他比例仍走原 Core Animation 路径。iOS 26 使用 composition configuration
与类型化 pixel buffer API，iOS 18–25 使用对应 mutable composition 与 CVPixelBuffer API。

操作步骤：

1. 开启 `-CameraWatermarkBenchmark`，选择 `4:3` 和 Live Photo。
2. 拍摄后等待 `benchmarkFinished failures=0 overlap=false`，再拍下一张；建议拍 6 张，
   覆盖两轮执行顺序。在对照期间不要开始下一次拍摄、切换镜头或退出应用。
3. 发送全部 `[CameraCapture]` 日志。`benchmark.B/C/D.movieCompositionPrepared duration`
   是合成准备；`movieExportFinished duration` 是导出；`total duration` 是完整处理。
   输出摘要记录尺寸、显示尺寸、帧率、时长、codec FourCC 数值、文件大小、音频/元数据轨数及
   配对标识是否存在。三组参数不一致时先查原因，不直接比较速度。
4. 完成性能对照后移除 benchmark 参数，单独添加 `-CameraUseCoreImageWatermark`，
   用整幅 `4:3` 验证 D 的实际 Live Photo 保存、封面切换、左右方向、前置镜像和声音。
   该参数只用于 Debug 候选路径验收，需要裁切时保存会明确失败；不要在其他比例下使用。

若另一张照片的后处理进入正在运行的对照，结束日志会标记 `overlap=true`，这组数据不用于
性能结论。这个检测不覆盖尚未交付的相机采集负载，因此仍需要等到对照结束才按下一次快门。
失败只记录在 benchmark 日志，已经成功保存的正式照片不因此报告保存失败。

先比较 C 与 B 估计图层合成的额外代价，再比较 D 与 C 判断替换是否有效。
这不是逐阶段 CPU/GPU 耗时之和；管线可能重叠执行。不降低分辨率、帧率或主动调整编码质量。

依据 Apple 的 [Core Image 视频接口](https://developer.apple.com/documentation/avfoundation/avvideocomposition/init(applyingfiltersto:applier:))
和 [CIContext 视频性能建议](https://developer.apple.com/videos/play/wwdc2020/10008/)。
该轮实验尚未改变默认合成方案；后续真机结果与默认路径变更见下文。

本轮验证：无签名 iOS Simulator 目标构建通过，未启动模拟器或操作真机。
另在 macOS 临时验证程序中复用当前视频处理源码，替换 UIKit 水印为非对称彩色测试图，
覆盖镜像开/关与 `−1/0/+1` 旋转共 6 组、每组 B/C/D 三种导出。全部确认原 MOV 哈希
不变、配对标识保留、时间元数据样本及其时间戳不变、存在音频样本、C/D 输出尺寸一致。
严格在 0.5 秒抽帧后，C/D 的 8-bit RGBA 平均绝对差为 0.82–1.30，方向和测试水印匹配；
默认抽帧容差会选取不同帧，不能用于这种逐像素比较。这项合成测试不代替真实 logo/文字、
真机 PhotoKit 配对播放、实际音质、色彩/HDR 与性能验收。

### 同素材对照的真机失败与事务修正

用户随后提供 5 张完整对照和第 6 次卡住的日志：前 5 张正式照片均已 `saved`，
B/C 均成功，D 均在合成准备阶段抛出当时的 `ProcessingError code=3`
（`unexpectedRenderSize`），结束为 `failures=1 overlap=false`。D 没有导出成功样本，
不能得出 Core Image 性能结论。B 导出中位数 563.0 ms，C 932.9 ms；逐张 C−B 差值
中位数 383.2 ms。源视频为 HEVC，B/C 均输出 H.264，尺寸均为 1744×1308，音轨、
3 条元数据轨与配对标识存在；首条源片较短，不能把不同片长的耗时直接解释成预热收益。

第 6 次仅记录到 `captureSubmitted`，没有照片或视频交付，用户确认界面无法操作。
日志尾部为 `deleted thread with uncommitted CATransaction`，不是完整崩溃或线程堆栈；
现有日志不足以确认卡死根因，但后台 actor 创建 CALayer 且依赖隐式事务是已发现的问题。
依据 [Apple CATransaction 文档](https://developer.apple.com/documentation/quartzcore/catransaction)，
隐式事务依赖线程 run loop 提交。现在只把图层树创建移至 MainActor，并用显式 begin/commit
及 disableActions 包住图层与合成工具创建；水印位图生成和视频导出继续在后台。

D 保持尺寸校验，不强行缩放或吞掉异常。错误现在记录 expected/actual 尺寸；源/输出摘要
补充编码尺寸、clean aperture、presentation dimensions 和 preferredTransform，区分实际
显示区域与编码尺寸。相机补充 `captureCallReturned`、`captureWillBegin`、`willCapturePhoto`
用于定位再次卡住时是否返回采集调用及进入系统回调，不增加超时重试或修改采集状态。

事务修正后，本机使用 1744×1308 HEVC 合成素材复测 6 组旋转/镜像，18 次 B/C/D 导出
全部通过原文件哈希、配对标识、时间元数据与音频存在性检查，同时间抽帧 C/D 平均绝对差
1.02–1.72。未复现真机 D 尺寸不匹配，也未复现第 6 次采集卡住，不能据此声称已修复真机
卡死。下一步先重启应用拍 1 张，获取具体尺寸错误；确认后再恢复多张对照。

### 4:3 单张定位 clean aperture 与 D 合成器修正

后续单张 UUID `57693E6D` 的采集调用返回、采集回调与保存均完整，`saved=4448.6 ms`，
提供的日志没有事务警告；单张通过不能证明连续拍摄卡住的问题已解决。
同素材 B 导出 631.4 ms、C 1167.8 ms，差 536.4 ms；D 仍未导出成功。
新增 geometry 日志确认源编码为 1920×1440，clean aperture 为 (88,66,1744,1308)，
而旧系统 CI 滤镜 composition 自动生成了 1920×1440 画布，和 B/C 的 1744×1308 不符。

本机补建包含上述有效区域的 HEVC 素材，先复现相同尺寸错误，再替换 D 的接入方式。
Apple 的系统 CI 回调 composition 不支持修改其属性和私有 instructions，因此不复制
或修改这些指令。参考 [AVVideoCompositing](https://developer.apple.com/documentation/avfoundation/avvideocompositing)
及 [MetalPetal 实际实现](https://github.com/MetalPetal/MetalPetal/blob/master/Frameworks/MetalPetal/MTIVideoComposition.swift)，
用小型自定义合成器从源 pixel buffer 读取有效区域，由复用的 CIContext 合成到系统提供的
输出 buffer；保留原 AVURLAsset、导出 preset 与源轨时间节奏。渲染在 AVFoundation 工作线程
同步完成，取消等待当前帧完成，不产生额外 Task 或主线程图层操作。D 仍是实验候选，正式保存仍用 C。

修正后的 macOS 合成验证覆盖镜像开/关 × −1/0/+1 旋转，共 18 次 B/C/D 导出。
源 MOV 哈希、配对标识、带时间戳的元数据样本保留，音频样本存在，C/D 尺寸相同；
同时间抽帧的 C/D 平均绝对像素差为 0.77–1.12（8-bit RGBA）。无签名 iOS Simulator
构建通过。以上不代替真机性能、PhotoKit 配对播放和连续拍摄稳定性验收。
下一步仍先拍一张 4:3 Live Photo，确认 D 完整导出、输出几何一致且
`benchmarkFinished failures=0 overlap=false`，再恢复两轮顺序的 6 张对照。

### Core Image 真机验收与默认路径

随后 6 张同素材 B/C/D 对照全部 `failures=0 overlap=false`，三种执行顺序各覆盖两次。
B/C/D 视频导出中位数分别为 651.6/1114.8/661.8 ms；逐张 C−D 导出差中位数
459.7 ms，D−B 完整视频处理差中位数 17.3 ms。每张三条路径的输出几何、帧率、时长、
编码格式、音轨/元数据轨数一致，配对标识存在。这是强制转码对照，不能与无水印 header
快路径的十几毫秒处理时间混为一谈。

关闭 benchmark、开启 D 实际保存后的 6 张均保存成功。快门到 saved 中位数 3026.1 ms，
上轮 C 为 3544.6 ms；视频导出中位数由 1080.6 降至 594.7 ms，采集交付中位数基本一致。
两轮并非同一份素材，整体差值不能全部归于算法。D 首张总计 3972.9 ms，封面处理
968.5 ms、视频导出 1309.5 ms；后五张保存总计 2884.5–3076.7 ms。首次使用开销
尚未定位，不据此宣称已完成首张性能优化。用户随后确认播放、水印位置、封面切换、
画面方向和声音正常；验收针对这轮 4:3 样本，不外推到所有镜头、系统和比例。

首次切换默认方案时按实际视频几何选路径：无需额外模板裁切时使用 D（Core Image），需要裁切时
使用 C（Core Animation）。关闭水印仍保留原直通/header 快路径。这个选择同时应用于
Debug 和 Release；不在导出失败时静默换路径。日志新增 `movieRenderMode=D/C/B needsCrop=...`。
共享 Scheme 已停用强制 D 参数，正常使用无需任何水印实验启动参数。

该阶段 Debug 的 `-CameraUseCoreImageWatermark` 保留为强制 D 验证开关，需要模板裁切时明确失败；
新增 `-CameraUseCoreAnimationWatermark` 可强制 C 做回归对照（不要同时开启两者）。
`-CameraWatermarkBenchmark` 仍显式测试 B/C/D，不会把 C 的结果记作 D；但现在正常保存
会预先运行默认路径，比较历史日志时需考虑预热对象已改变。需要重现旧实验条件时强制 C。
其他裁切比例与首次使用开销留待独立验证，不扩大本次替换范围。

默认路径回归使用同样带 clean aperture 的 HEVC 合成素材：5 种比例分别调用正常处理
入口和对应的显式 D/C 路径，共 10 次导出。同时间抽帧像素一致，源文件哈希、配对标识、
时间元数据样本和音频存在性检查通过；强制 D 处理 1:1 仍按预期失败。该验证只确认路径
选择和既有输出未改变，不代表裁切比例已经过本轮真机视觉验收。规定的无签名构建通过。

### 全部比例统一使用 Core Image

用户确认此前各比例成片正常，并要求全部扩展到 D。默认视频水印现在统一使用 Core Image，
覆盖 `1:1`、`3:4`、`4:3`、`9:16`、`16:9`，同时用于 Debug 和 Release。
移除按 `needsCrop` 改走 C 的分流，以及 D 对模板裁切的拒绝。复用现有的有效区域归一化、
居中裁切位移和最终旋转变换，水印仍按最终输出尺寸绘制；不更改分辨率、帧率或编码 preset。
普通静态照片仍使用既有单次绘制/编码路径，关闭水印仍保留直通/header 优化。

C 继续作为 `-CameraUseCoreAnimationWatermark` 的显式调试对照；强制 D 参数无需开启，
开启时也支持全部比例。B/C/D benchmark 同样可以处理裁切比例，不再有
`coreImageRequiresWholeFrame` 错误。实际路径仍通过 `movieRenderMode=D needsCrop=...` 记录。

本机使用带 (88,66,1744,1308) clean aperture 的 1920×1440 HEVC 合成素材，覆盖全部
5 种比例、镜像开/关及两种横向旋转，共 14 组、42 次 B/C/D 导出；其中 D 通过正常
`process` 入口验证默认选择。所有组的源文件哈希、配对标识、带时间戳的元数据样本、
音频存在性、视频样本数、时长与 C/D 输出尺寸检查通过。同时间抽帧 C/D 的 8-bit RGBA
平均绝对差为 0.71–1.12，水印区域 RGB 平均绝对差为 0.85–1.11。规定的无签名
Simulator 构建通过。此次本地检查验证 D 的裁切/方向/水印输出；各比例的真机反馈见下文。

### 全比例 D 真机反馈与首次拍摄优化待办

2026-09-27，用户在全部比例默认切换到 D 后再次真机测试，反馈除首次拍摄较慢外，
各比例 Live Photo 的快门到保存完成耗时基本在 **3000 ms 左右**，与此前 4:3 的测试
结果接近。当前保留全部比例使用 D 的默认方案。本次为用户实测概述，没有新增逐张日志、
各比例样本数或统计分布，因此不将约 3000 ms 写成精确中位数，也不推算各比例提速百分比。

**后续优化项：首次拍摄偏慢。** 本轮先完成全比例水印路径统一，首次拍摄开销尚未优化，
单独纳入后续工作，不在这次验收中视为已解决。此前 D 的 4:3 日志可作为现象参考：
首张总耗时 3972.9 ms，后五张为 2884.5–3076.7 ms；首张封面处理 968.5 ms、
视频导出 1309.5 ms，两者并行，不能相加。该组数字不代表这次所有比例的首次耗时。

后续定位与验证要求：

- 分开记录应用重新启动后的首张与后续拍摄，固定设备、镜头、场景、比例及水印设置。
- 分别检查采集交付、封面绘制/编码、视频合成准备/导出和相册写入，定位首次额外等待；
  初始化、缓存建立或资源竞争仅作为待验证方向，不预先认定为根因。
- 优化后同时对比首张和后续拍摄的耗时与成片效果；若尝试预热，还需检查启动耗时及资源
  占用，避免把首次拍照的等待简单搬到应用启动阶段。

## 2026-09-27 拍摄期间保持控件外观

拍摄期间继续锁定下一次拍摄、前后切换、倍率、对焦、曝光、闪光灯和 Live Photo 设置，
但不再因这次临时锁定让快门、切换按钮、顶部按钮或曝光条变灰。拍摄阶段的控件沿用就绪
时的颜色、透明度与选中状态，受锁定的按钮和倍率选项暂不接受触摸；实际命令入口仍检查
`phase == .ready`，其他输入途径也不能在采集期间更改拍摄设置。

启动、停止、切换设备及 Live 配置过程中的不可用表现，以及设备不支持某项能力时的禁用
状态保持原样。曝光条继续使用真实可操作状态限制拖动，保留原有闲置淡化规则；模板选择、
注释显隐和现有快门黑色闪屏反馈沿用既有行为。此改动只调整拍摄锁定的视觉反馈，不改变
采集生命周期或快门恢复时机。

已通过规定的无签名 generic iOS Simulator 构建及代码审查；拍摄时外观稳定、连续点按
快门与其他受锁控件的实际体验仍待真机验收。

## 2026-09-27 快门轻微触感

页面处于可拍状态且已取得倍率能力时，接受快门操作后提供一次轻微触感，普通照片与
Live Photo 相同。使用 SwiftUI `sensoryFeedback` 的 `.impact(weight: .light, intensity: 0.5)`，
复用仅在接受快门操作后变化的 `shutterFeedbackID`；启动、切换或采集锁定期间的点击不触发。
触感表示已接受快门操作，不等待拍摄结束或相册保存，也不作为保存成功提示。

触感独立于黑色闪屏动画，“减弱动态效果”仍沿用已有视觉行为。Live 接入麦克风后设置
`AVAudioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)`，避免音频输入默认
抑制触感；保留 AVFoundation 的自动音频会话配置，不添加新的音效。该设置失败时记录原因，
不让触感可用性阻断正常拍照。

已查阅 [Apple SwiftUI 触感文档](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
与 [录音期间触感设置](https://developer.apple.com/documentation/avfaudio/avaudiosession/setallowhapticsandsystemsoundsduringrecording(_:))，
并核对当前 SDK：前者从 iOS 17、后者从 iOS 13 可用，覆盖最低 iOS 18。
已通过规定的无签名 generic iOS Simulator 构建。实际轻重与 Live 录音效果仍待真机验收。

## 2026-09-27 拍摄与保存延迟讨论

后续图片加工优化已从实验中提取为独立文档
[iOS 图片加工优化：实验结论与实施起点](ios-photo-processing-optimization.md)，
在 `codex/photo-processing-optimization` 从实验前 `main`（`d6f6c1b`）重新推进。
完整测试复盘保留在 `codex/camera-latency-validation` 的 `2d5894c`，没有整体移植实验代码。
新分支首轮已将静态照片的方向归一化、居中裁切与最终旋转融合为一次绘制，普通照片与
Live 静态照片共用 `PhotoAspectRatio.renderedImage(from:quarterTurns:)`，移除独立的
`PhotoOutputRotation`。仍使用原尺寸计算、裁切坐标和 `UIImage` 方向及镜像处理方式。
该次改动保持模板输出规则、编码路径、相机采集与视频流程不变；当时水印尚未实现。
后续已在同一次最终输出画布中接入水印，见本页「保存前水印与耗时对照」。
图片加工优化的验证状态记录在对应文档第 7 节。

下文保留优化前 `d6f6c1b` 的代码审查与参考方案讨论，尚未建立新实现的真机阶段计时基线。
它不改变上文已实现的异步保存规则或成片契约。
`plans/ios-camera-performance.md` 对应归档旧相机，其历史耗时不能作为当前实现的基线。

### 用户反馈与原因边界

用户反馈：已有闪屏反馈后，从拍照到处理、最终进入系统相册仍感觉慢；快门恢复与相册出现
两个环节都明显，普通照片也存在，不限于 Live Photo。后续第一轮验证优先覆盖普通照片。

此前实现优先保证单次拍摄资源完整交付，以及裁切、镜像和输出方向正确，带来两项性能代价：

- 单个拍摄请求占用全局拍摄状态，完整请求结束前不能开始下一张，没有利用采集与处理重叠的能力。
- 保存前进行全尺寸像素重绘；需要最终旋转时再绘制一次，增加自定义处理工作。

这些实现选择确实增加等待或处理工作，但系统采集、计算摄影、编码和 PhotoKit 写入也需要时间。
尚无阶段计时，不能将全部延迟归因于此前决策，或断言某个阶段占据最多耗时。
成片要求本身继续保留，优化重点是状态划分与实现方式。

### 优化前实际链路（`d6f6c1b`）

依据该提交的 `CameraScreen`、`CameraEngine`、`CameraController`、`CameraPhotoSaver`、
`PhotoAspectRatio`、`PhotoOutputRotation` 与 `LivePhotoProcessor` 的实际代码：

```text
按下快门 → 页面进入 capturing → AVFoundation 采集、处理和编码
  → didFinishCaptureFor 返回完整结果 → 后续保存任务入队 → 页面恢复 ready

保存任务：照片解码、方向归一化与比例裁切 → 按需最终旋转 → PhotoKit 写入系统相册
Live Photo 另需处理配对视频，照片和视频资源准备完毕后一起写入相册
```

- `CameraEngine` 仅持有一个 `photoDelegate`，其非空时拒绝下一次拍摄；直到
  `didFinishCaptureFor` 才清空并交付结果。Live Photo 还需取得配对视频的处理结果。
- `CameraController` 调用 `saver.enqueue` 后立即完成拍摄回调，不等待自定义处理或相册写入。
  因此保存已经与快门锁定解耦，不能描述为“必须落库后才能拍下一张”。
- 普通照片始终经过 `UIGraphicsImageRenderer`，即使目标比例与原图一致也会重绘，
  同时归一化方向；最终横版旋转使用第二次 renderer。随后从 `UIImage` 创建 Photos asset。
- Live Photo 静态图也经过裁切、旋转与重新编码；需要变换的视频使用最高质量 preset
  配合 `videoComposition` 导出。已有视频直接复用分支，不代表所有拍摄都需要视频重新编码。
- 当前黑色闪屏在按下快门时触发，普通照片动画为 `0.04 + 0.18` 秒，Live Photo 为
  `0.04 + 0.36` 秒。它只提供视觉反馈，不缩短系统处理、快门锁定或保存耗时。
- 当前拍摄使用 `.balanced`，尚未接入 Responsive Capture、Readiness Coordinator、
  Fast Capture Prioritization、Deferred Photo Delivery 或阶段计时。

### 本轮参考方案

记录日期：2026-09-27。以下开源库只用于阅读实际实现，不作为新增依赖。

| 来源 | 已核对的处理方式 | 适用范围与限制 |
| --- | --- | --- |
| [VisionCamera v4.7.3 拍摄入口](https://github.com/mrousavy/react-native-vision-camera/blob/v4.7.3/package/ios/Core/CameraSession%2BPhoto.swift)与 [PhotoCaptureDelegate](https://github.com/mrousavy/react-native-vision-camera/blob/v4.7.3/package/ios/Core/PhotoCaptureDelegate.swift) | 每次拍摄创建独立 delegate；捕获事件与图片文件结果分开，写文件后返回路径、方向和镜像信息，Photos 保存不纳入这条结果流程。 | 可参考每张照片独立生命周期与保存职责分离，不能据此判断上层快门 UI 恢复时间或性能。[该版本配置](https://github.com/mrousavy/react-native-vision-camera/blob/v4.7.3/package/ios/Core/CameraSession%2BConfiguration.swift)仍将 Responsive/Fast Capture 列为 TODO，不能声称已采用。 |
| [NextLevel 拍摄回调源码](https://github.com/NextLevel/NextLevel/blob/main/Sources/NextLevel.swift) | 分别通知采集、图片处理和完整捕获结束；普通照片通过 `fileDataRepresentation()` 将编码 Data 交给调用方。 | 这条普通照片路径不在库内执行裁切、像素旋转或 Photos 保存。它不承担 Framewise 的成片变换要求，不能直接据此比较速度。 |
| [Apple：Create a more responsive camera experience](https://developer.apple.com/videos/play/wwdc2023/10105/)与 [Readiness Coordinator 文档](https://developer.apple.com/documentation/avfoundation/avcapturephotooutputreadinesscoordinator) | Responsive Capture 允许下一张采集与上一张处理重叠；readiness 用于决定是否及时接受新请求，协调后台相机队列与主线程 UI。 | API 从 iOS 17 可用，覆盖当前 iOS 18 最低版本；仍需检查当前设备与配置支持，并处理交错的多次拍摄回调。 |
| [Apple：Saving captured photos](https://developer.apple.com/documentation/avfoundation/saving-captured-photos) | 将 `fileDataRepresentation()` 得到的编码 Data 作为 `.photo` 资源交给 PhotoKit。 | 可作为不含自定义变换的性能对照。当前比例裁切、镜像和最终物理像素方向要求不能通过直接保存原始 Data 自动满足。 |

另已核对当前安装 SDK 的 `AVCapturePhotoOutput.h`：上述响应式拍摄及 readiness API 的
iOS availability 为 17.0。Zero Shutter Lag 在现代 SDK 链接的应用中会于支持的配置下默认开启；
实际启用状态仍需检查。它改善捕获时刻与按下快门时刻的对应，不等于减少编码或落库耗时。

### 候选实施顺序，尚未实施

1. 建立真机分段计时：按下快门、系统图片交付、完整 capture 结束、快门恢复、
   自定义处理开始与结束、Photos 写入完成。另观察相册实际出现时间，不将它与写入回调
   自动视为同一时刻。对比普通照片不同输出比例和方向，再覆盖 Live Photo。
2. 改善下一拍等待：在支持的配置下验证 Responsive Capture 与 Readiness Coordinator，
   为每张照片保留独立 delegate 和资源，依据就绪状态恢复快门。仍在处理的请求不能被新请求
   覆盖；相机切换等会话变更需继续考虑进行中的请求。仅提前解禁按钮可能造成排队，
   不足以证明实际拍摄更及时。
3. 缩短自定义处理与保存：先以原始编码 Data 直存作为性能对照，测量当前额外处理的占比；
   正式输出尝试将方向归一化、裁切与最终旋转合并为一次像素处理，只在满足现有契约时
   复用原资源。不能以方向标签替代已确认的物理像素旋转要求。

第一轮建议保留当前 `.balanced` 画质与成片规则；响应式采集增加内存需求，需结合保存任务
积压情况验证，避免无界增加进行中的请求或处理任务。优化幅度以真机测量为准，暂无耗时承诺。

Deferred Photo Processing 暂不列为第一轮：它先将代理照片作为 `.photoProxy` 写入相册，
最终高质量处理稍后完成，改善连续拍摄与照片先出现的体验，不保证最终成片更早就绪。
Apple 说明对代理照片像素或元数据的修改不会自动反映到最终照片，需后续通过 PhotoKit 调整；
因此不能直接套用当前保存前裁切、旋转流程。Fast Capture Prioritization 会按需降低拍摄质量，
也先不作为本轮默认方案。

### 同日补充：Live Photo 的采样时间与额外等待

用户进一步反馈 Live Photo 约有两秒等待，系统相机的体感没有这么长，要求核对采样时序与
成熟实现。以下仍是讨论与代码审查，未改动拍摄或保存实现，也没有测得各阶段耗时。

**采样时长不等于快门必须禁用的时长。**
[Apple 的 Live Photo 说明](https://support.apple.com/en-us/104966)描述快门前后各约 `1.5` 秒。
前半段来自快门之前的采集，不需要在按下之后重新等满整段；若要保留后半段，仍需等待未来
画面产生。因此“按下之后固定两秒”不是 API 的硬性规则，也不能承诺把完整后续画面立即交付。

[Apple WWDC16 的采集时序说明](https://developer.apple.com/videos/play/wwdc2016/501/)及当前
SDK 将几个完成时刻区分开：

| 时刻 | 含义 | 当前 Framewise 的使用情况 |
| --- | --- | --- |
| `didFinishRecordingLivePhotoMovie…` | 动态部分所需样本已收集，文件尚不一定写完；可以结束采样中的 LIVE 指示。 | 未实现此回调，未单独表达采样结束。 |
| `didFinishProcessingLivePhotoToMovieFile…` | 系统 MOV 文件已写完，可以消费。 | 保留视频 URL，等待完整请求结束。 |
| `didFinishCaptureFor` | 本次请求的回调全部结束，可清理请求状态。 | 交付图片与视频，释放全局拍摄状态。 |
| 自定义处理和 Photos 写入完成 | 得到符合当前成片契约的最终相册资源。 | 已在后台执行，但须等加工结束才能创建完整 Live Photo asset。 |

我们的 `AVCapturePhotoOutput` 同样提供快门之前的 Live Photo 内容；当前代码在开启功能时
配置输出，按每次快门时没有重新开启 Live Photo 或停止、重启会话。
系统 [自动裁掉过度移动画面的能力](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotoautotrimmingenabled)
在支持时默认开启，当前代码未关闭。因此没有证据将每拍等待归因于缺少预采集或自动修剪。
预采集、按运动自动缩短片段和允许请求重叠是不同机制，不能互相替代。

本轮另核对了 Apple 旧版 AVCam 示例的
[CameraViewController.swift 镜像](https://github.com/Lax/Learn-iOS-Swift-by-Examples/blob/master/AVCam/Swift/AVCam/CameraViewController.swift)
与 [PhotoCaptureDelegate.swift 镜像](https://github.com/Lax/Learn-iOS-Swift-by-Examples/blob/master/AVCam/Swift/AVCam/PhotoCaptureDelegate.swift)：
每张创建独立 delegate 并按 `uniqueID` 保留；源码明确处理 Live Photo 请求重叠，用进行中的
采样数量控制 LIVE 指示，不等上一张保存完才接受下一张。采样结束只移除相应指示，完整图片
Data 与系统 MOV 随后直接作为 `.photo`、`.pairedVideo` 写入同一 asset，未额外裁切或转码。
这证明公开 API 可拆开请求生命周期，不能据此声称已查明系统 Camera app 的内部调度；
旧示例的 UIKit、队列和按钮策略也不能完整照搬到当前工程，需结合系统 readiness 与负荷限制。

另外核对 [LimitPoint/LivePhoto 的实际源码](https://github.com/LimitPoint/LivePhoto/blob/master/LivePhoto.swift)：
`saveToLibrary` 直接将已有配对文件提交 PhotoKit，不重新编码。它是 Live Photo 资源工具，
不是相机采集库；其 `generate` 将任意照片、视频重新配对时的转码不属于原生拍摄的必要步骤。
NextLevel 未实现完整的 Live Photo 视频处理回调，上一轮普通照片参考不能据此延伸为
完整 Live Photo 方案。上述镜像与资源库链接核对日期为 2026-09-27，链接使用其当前分支。

当前额外处理发生在 `LivePhotoProcessor.process`：先完成静态图裁切、按需旋转和编码，
再开始视频处理。视频若已满足比例且 `quarterTurns == 0` 则复用原文件，否则通过
`videoComposition` 与 `AVAssetExportPresetHighestQuality` 重新导出整段视频，最后才写入 Photos。
视频变换处理的是整段画面，不只是静态照片；但不能在未测量时判断导出增加了几秒。
不能假定每次 `3:4` 都会复用视频，需记录真实尺寸、变换与所走分支。

因此需分别验证两类优化：快门就绪时允许独立请求重叠，以减少用户等待；保存端减少成对资源
的重复加工，以缩短最终成片落库。第一轮计时应补充采样结束、系统 MOV 交付、静态图处理、
视频导出与 Photos 写入的时间，以及片段 duration、photoDisplayTime、输入/输出尺寸和
是否直接复用视频。原始配对资源直存仅作性能对照；正式优化继续满足静态图、配对视频相同
裁切、镜像和最终方向的要求，不为缩短等待强行截掉后续画面。

## 2026-09-24 相机核心拆分

`Core/Camera` 包含无 SwiftUI 依赖的会话与设备控制、握持方向判断、照片与 Live Photo 处理、
以及相册写入。`CameraController` 对页面提供相机会话和拍摄命令，采集结束即将后续保存任务交给
`CameraPhotoSaver`。`CameraPreview`、`CameraAccess` 和 `CameraScreen` 保留在 Feature 中。

Live Photo 是持久化的用户偏好，首次默认为关闭；用户开启后，后续进入相机仍尝试开启。
`CameraAccess` 在偏好开启时校验并按需申请麦克风权限；不可用时继续普通照片。进入相机后的
Live Photo 会话配置属于启动阶段，实际模式与偏好分开（2026-09-28 更新）。
只有用户在相机页面内主动切换时，才进入 `changingLivePhoto` 阶段。页面用单一操作阶段控制
启动、切换和拍摄的互斥；异步保存不占用该阶段。

## 2026-09-24 蒙版预览与相机边界

以下是正式相机 UI 的已确认方向，先在 `CameraDebugView` 中用灰色画布和一套真实蒙版数据
局部试验，后已接入 `CameraScreen`。本节取代第 9、10、12 节中关于固定 `CameraViewport`、
模板切换不改变可见预览框、以及由 `TemplateFrame` 单独在固定预览上做 aspect fit 的早期布局假设。
这些章节保留为实施过程记录，不代表当前完成状态。

- 蒙版是叠在相机预览上的视觉引导。`CameraMaskOverlay` 只绘制线条和提示，不请求权限、不操作
  `AVCaptureSession`、设备、zoom、曝光、拍摄或保存。`Core/Camera` 不读取 `MaskVariant`。
- 页面从当前模板声明的宽高得到**竖屏显示比例**：短边除以长边。`4:3 → 3:4`、
  `16:9 → 9:16`、`3:4 → 3:4`、`1:1 → 1:1`。这是界面取景框的比例，不直接表示最终
  文件的像素尺寸、宽高方向或保存旋转；正式页面另外将模板原始宽高比写入拍摄比例状态。
- 在屏幕顶部到下方安全区域上边缘之间，按该竖屏比例取得尽可能大的预览矩形并居中。
  `CameraPreview` 与蒙版覆盖层使用同一个最终矩形。切换到另一比例时，可见预览框随之变化；
  相机会话、设备与 zoom 不因蒙版切换而重配。同一显示比例下更换蒙版，只改变覆盖层。
- 模板比例与可用显示区域进入**一次** UI 布局计算，产出预览框尺寸、蒙版旋转前的绘制尺寸与
  当前角度。这些界面点数交给预览组件和蒙版组件；两者不再各自计算宽高。调试页已通过
  `CameraViewportLayout` 完成这一步；真实握持方向留到接入相机时再加入。SwiftUI 可用容器和
  `@ViewBuilder` 组合预览与蒙版，`CameraPreview` 本身不持有蒙版数据。
- 横版模板放进竖屏预览框时需要旋转蒙版坐标。左右横握分别使用相反的 90 度方向；从一侧切到
  另一侧，蒙版相对翻转 180 度。当前调试实现固定 `+90°`，另一侧与角度符号的真机对应仍待
  验证。方向依据可与现有 Core Motion 握持判断共享，但蒙版旋转不能决定照片输出旋转。
- 模板读取失败时，显示布局回退到 `3:4`，不绘制蒙版，并给出约 3.5 秒的失败提示。
  调试页已有此回退；正式相机入口仍需在接入时调整。目前加载失败会停在错误页。

这里的预览尺寸只描述可见 UI。预览层的 `resizeAspectFill` 与最终照片四边内容是否一致，
仍需在真机上按不同比例分别验证；蒙版的布局计算不代替照片裁切计算。

## 2026-09-25 相机底部操作区布局

照片预览、拍照键和前后摄像头切换组成底部操作区；快捷缩放与这组控件分离，叠放在
预览区域内部下沿，随预览矩形变化而移动。调试页的快捷缩放距预览框底边 12 点；
底部操作区以覆盖层定位，不占用或改变预览区域的布局空间。
如果快捷缩放的默认底边距拍照键外圈顶边不足 24 点，只将缩放控件上移到两者相距 24 点。
两者使用同一屏幕坐标系中的实际布局位置判断；预览框和拍照键不因避让而移动。
`CameraMaskRequest.relatedMaskIds` 包含当前 `maskId`，因此只有数组至少包含两个 ID 时才有
模版切换选项。底部操作区按此条件呈现两种布局：

- `relatedMaskIds.count >= 2`：拍照键居中位于上方；下方一行依次放照片预览、模版切换器、
  前后摄像头切换。切换器初始选中 `maskId`，选项顺序与 `relatedMaskIds` 一致。
- `relatedMaskIds.count < 2`：沿用照片预览、拍照键、前后摄像头切换同一行的布局，不显示
  模版切换器。

模版切换器采用原生相机模式栏的视觉方向：整条栏在黑色相机底部使用可辨认的深灰底色和细描边，
当前项始终居中，选中态在 iOS 26 使用系统透明玻璃按钮样式，较早系统使用材质回退；相邻项在
两侧露出。选项宽度随文字变化，保留最小
点击区域并收紧选项间距；点击相邻项或横向滑动可改变 mock 选择。模式栏与两侧圆按钮之间留出
24 点间距，整组控件距离屏幕左右边缘各 36 点；切换栏与照片预览、镜头翻转按钮同高，
当前 UI mock 均为 44 点。拍照键整体直径为 72 点，外圈为约 3 点宽的半透明白色描边，
中间约 3 点宽的空隙完全透明，中心为直径 60 点的白色实心圆。
多模版布局中，拍照键与下方工具栏之间留 24 点垂直间距。
只裁切两侧溢出的选项文字，选中玻璃按钮的按压效果不受模式栏外框裁切。
多模版布局的底部工具栏贴合底部安全区域上边缘；无模版切换栏的单行布局在安全区域上方
额外留 16 点底部间距。

照片预览对应现有 `onOpenAlbum` 按钮。未来取得相册访问权限并读取最新照片后，以照片缩略图
显示在该按钮上；没有缩略图时保留占位外观。点击打开相册、权限申请和照片读取属于后续业务实现，
不属于本轮 UI 调整。

模版切换以模版 ID 作为选中与切换依据，标题只负责显示。后续可将关联项从纯 ID 扩展为包含
`id` 与自定义 `title` 的数据；本轮 UI mock 可使用 `3:4`、`9:16`、`1:1`、`4:3`、
`16:9` 等比例标题。切换 mock 选项时应能看到预览区域随所选比例更新：`3:4` 与 `4:3`
使用相同的竖屏预览尺寸，`9:16` 与 `16:9` 也使用相同尺寸；横版模版的蒙版坐标旋转规则
仍按上一节执行。切换至其他显示比例时重新计算预览矩形。真实模版读取、拍摄输出与相机设备
控制的接入另行实现。

调试页现有两种布局预览：多模版 mock 可点击切换项并更新灰色预览框比例，单模版预览沿用
原有一行布局与真实蒙版示例。多模版 mock 不绘制真实蒙版，因为其他比例还没有对应的模版数据。
两种预览均从 Debug 构建的设置页“开发调试”分区进入，供真机检查界面；不启动相机会话。
导航请求的 `relatedMaskIds` 已传入 `CameraAccess` 和 `CameraScreen`；现有入口仍都传空数组，
因此正常入口暂时只显示单蒙版布局。调试页的多蒙版 mock 仍用于布局检查。

## 2026-09-25 正式相机 UI 接入决策

正式 `CameraScreen` 使用已经验证布局的相机 UI，移除测试阶段的独立照片比例菜单与旧控件布局。
当前相机页面只维护一份拍摄比例状态，以当前选中的蒙版原始宽高比更新；同时按上文规则计算
竖屏可见预览框。`3:4` 与 `4:3` 可以使用同一形状的预览框，但拍摄比例状态仍保留方向区别。
新 UI 不提供另一处可与蒙版比例冲突的比例选择。

闪光灯模式与 Live Photo 开关属于本地相机偏好，由正式 UI 展示并修改；拍摄时使用按快门当刻的
设置。闪光灯仍须按当前设备实际支持的模式启用，Live Photo 开启时仍须经过麦克风权限与会话配置。
正式顶部闪光灯控件每次点击按关闭、自动、开启的顺序切换，跳过当前设备不支持的模式，
并保存用户选择；不弹出菜单。快捷缩放显示相机核心提供的用户倍率标签，点击时使用对应的
设备 zoom factor。快捷缩放栏占据的实际区域不触发预览聚焦，栏位因避让快门上移时排除区域
随之移动。

进入相机时由初始蒙版设置拍摄比例；切换蒙版时更新选中蒙版、预览框和拍摄比例，不重启
相机会话。按快门时复制当时的拍摄比例并传给 `CameraController`；后续切换蒙版不改变已经发起的
拍摄或异步保存任务。`Core/Camera` 只接收拍摄比例值，不读取蒙版数据。

照片预览入口尚未实现；前后摄像头切换已按上方“2026-09-26 前置相机接入”完成代码接入。
正式页面已接入上述 UI 与拍摄比例状态；多蒙版切换尚无携带真实关联 ID 的产品入口，
具体成片边界仍需真机验证。

## 1. 当前已确认原则

### 1.1 权限获取与相机运行拆分

权限获取是进入相机能力之前的独立流程，不属于相机会话、预览或拍摄状态的一部分。
新实现不得在 `CameraScreen`、相机会话对象或拍摄方法中混合系统授权申请、授权说明 UI 与
相机设备配置。

目标链路：

```text
模板导航
  → CameraAccess
      → 查询相机权限
      → 在需要时由用户操作触发系统授权请求
      → 被拒绝或受限时显示说明与设置入口
  → CameraScreen
      → 创建并运行相机会话
```

这一拆分带来以下约束：

- 只有权限入口负责调用相机权限申请 API。
- `CameraScreen` 只在相机权限可用时创建和启动相机运行对象。
- 相机运行层不能通过主动弹出权限请求来修复状态错误。
- 如果权限在应用外被撤销，相机运行层返回明确的权限不可用结果，由上层退出或切回权限入口。
- 应用从系统设置返回前台时，权限入口重新读取真实授权状态，不缓存旧结论。
- 模板 ID 和模板 variant 穿过权限入口传递；权限层不解析或修改模板数据。

### 1.2 权限获取与校验属于独立 Core 模块

系统权限的状态查询、授权请求和系统状态到领域状态的映射统一放在新的
`ios/Framewise/Core/Permissions/` 中。该模块是系统能力边界，不属于 Camera feature，也不
依赖相机页面是否存在。

职责分为两层：

- `Core/Permissions` 负责与 AVFoundation、PhotoKit 等系统框架交互，返回明确、可测试的权限
  状态和请求结果。
- `CameraAccess` 等 feature 层负责决定何时查询或申请、显示什么说明、是否打开系统设置，以及
  授权成功后进入哪个页面。

`Core/Permissions` 不提供授权说明 UI，不执行导航，不创建相机会话，也不保存页面状态。权限
状态每次从系统读取，不在 Core 模块内维护一份可能过期的长期缓存。

## 2. 职责边界

| 边界 | 负责 | 不负责 |
| --- | --- | --- |
| `Core/Permissions` | 调用系统权限 API；查询和申请权限；把平台状态映射为应用可消费的结果 | 授权说明 UI、导航、相机会话和业务页面状态 |
| `CameraAccess` | 调用 Core 权限能力；表达检查中、请求中、拒绝与受限等页面状态；提供系统设置入口 | 直接调用系统权限 API、创建 capture session、拍摄照片 |
| `CameraScreen` | 组合相机 UI、模板覆盖层和页面生命周期 | 请求任何系统权限 |
| `CameraSession` | 配置相机设备与 capture session、启动和停止预览、执行拍摄命令 | 权限说明 UI、系统设置导航、相册授权 |
| 照片保存流程 | 在需要保存时调用 Core 的 add-only 相册权限能力 | 相机预览与拍摄设备控制 |
| 相册缩略图流程 | 在用户需要相册缩略图时调用 Core 的 read-write 相册权限能力 | 阻塞拍摄、预览或照片保存 |
| Live Photo 配置流程 | 在用户启用声音能力时调用 Core 的麦克风权限能力 | 普通照片流程与相机基础启动 |

这些名称先用于表达职责，不代表必须立即建立同名协议、service 或通用权限框架。实现时以满足
当前真实流程所需的最少类型为准。

## 3. Core 权限模块规划

初始目录规划：

```text
ios/Framewise/Core/Permissions/
├── Permissions.swift
├── CameraPermission.swift
├── PhotoLibraryPermission.swift
└── MicrophonePermission.swift
```

Core 权限边界已经实现相机、相册和麦克风三个独立权限类型。每个类型都可以单独查询当前状态、
判断是否已授权，以及显式发起异步授权请求；没有提供批量请求全部权限的入口。
`PhotoLibraryPermission` 进一步区分 `.addOnly` 与 `.readWrite`，两者可以分别查询和申请。PhotoKit
不提供 read-only 访问级别，因此缩略图流程使用系统的 read-write 权限，但应用只把它用于读取
用户可访问照片的缩略图。

使用侧统一通过无状态的 `Permissions` facade 传入所需权限数组：

```swift
let result = Permissions.check([.camera, .photoLibraryAdd])
result.isAuthorized
result[.camera]

let requested = await Permissions.request([.camera, .microphone])
requested[.microphone]

await Permissions.openSettings()
```

使用侧只暴露 `check`、`request` 和 `openSettings` 三个动作。`check` 与 `request` 的结果既能判断
传入权限是否全部可用，也能通过权限下标读取每一项的具体状态。数组中的权限按传入顺序逐项
申请，重复项会被忽略。这个接口只减少调用侧分支，不改变按实际使用时机分别申请权限的规则；
调用方不得因为支持数组参数就在进入相机时请求全部权限。

权限类型遵守以下边界：

- 对外提供当前权限状态查询。
- 对外提供显式的异步授权请求；查询操作本身不得弹出系统授权框。
- 不把 `AVAuthorizationStatus`、`PHAuthorizationStatus` 等系统 enum 扩散到 feature 层。
- `Permissions` facade 不缓存状态、不持有 UI，也不决定一次应申请哪些权限。
- 不为了统一形式提前引入协议；出现真实替换或测试需求后再抽象。
- 不持有 SwiftUI 状态，不要求在 MainActor 上执行无关的系统查询。
- 不记录授权文案；用户可见文案属于具体 feature。

## 4. 权限申请时机

`CameraAccess` 在进入拍摄页面前静默检查当前拍摄模式需要的权限。发现未决定的权限后，先通过
应用弹窗解释用途；用户确认继续后，再按顺序调用对应的系统授权请求：

1. **普通照片模式**：进入拍摄流程时检查相机与相册 add-only 权限，保证能够打开相机并保存结果。
2. **Live Photo 模式**：Live Photo 用户偏好持久化，首次默认关闭。偏好开启时在上述权限之外增加
   麦克风权限。`CameraAccess` 读取并传递该偏好，用户可在权限受阻时从入口关闭它；相机页的切换
   成功后也会更新该偏好。
3. **相册 read-write 权限（可选）**：用户主动使用相册缩略图能力时才申请；拒绝或受限不能阻塞
   相机预览、拍摄和 add-only 保存。

普通照片模式不检查或申请麦克风与相册 read-write 权限。Live Photo 偏好开启时，
`CameraAccess` 在进入相机页之前完成麦克风权限检查。

## 5. 相机权限状态

权限入口至少需要表达以下状态：

| 状态 | 页面行为 |
| --- | --- |
| `checking` | 等待读取系统真实状态，不创建相机会话 |
| `notDetermined` | 弹窗说明当前模式所需权限，由用户确认后触发系统请求 |
| `requesting` | 等待系统授权结果，避免重复请求 |
| `authorized` | 进入 `CameraScreen` |
| `denied` | 说明权限用途，并提供打开系统设置的入口 |
| `restricted` | 说明设备限制，不把它表现为可重复申请的状态 |

状态名称是当前讨论中的领域表达，不要求直接复用系统 enum，也不应把 AVFoundation 类型扩散到
导航和模板模块。

## 6. 运行时防线

权限流程与相机运行拆分后，相机运行层仍需要在配置设备前验证前置条件。这是针对系统状态可能
变化的边界检查，不是第二套授权流程。

当权限不可用时，相机运行层应：

- 不创建或继续运行 capture session；
- 返回可识别的权限不可用结果；
- 不调用权限申请 API；
- 不决定展示文案或跳转系统设置；
- 由页面上层将用户带回 `CameraAccess`。

## 7. 权限侧实施范围

Core 权限边界已完成：

1. 在 `Core/Permissions` 中定义统一的应用权限状态，不向 feature 暴露系统 enum。
2. 相机、相册 add-only、相册 read-write 和麦克风权限分别提供独立的状态查询、授权判断和异步
   申请能力。
3. 使用侧可以通过 `Permissions` 传入数组统一查询、判断或依次申请所需权限。
4. 已经决定的权限不会重复发起系统申请；状态始终以对应系统 API 的结果为准。

相机权限 UI 与流程接入已完成：

1. `CameraAccess` 静默检查当前模式需要的权限，并表达检查中、未决定、请求中、已授权、拒绝、
   受限与未知状态。
2. 普通照片模式要求相机与相册 add-only 权限；全局 Live Photo 开关开启时再要求麦克风权限。
3. 缺少未决定的权限时先弹窗说明，用户确认后逐项请求；拒绝后可以打开系统设置。
4. 授权成功后进入当前占位的 `CameraScreen`，模板 variant 与 annotation 不经过权限层修改。
5. 应用从系统设置回到前台时重新检查真实权限状态。

权限侧第一阶段不实现 `AVCaptureSession`、实时预览、拍照、相册保存或 Live Photo。后续章节在对应
设计讨论确认后再加入本文。

## 8. 实施安排

Core 权限模块与 `CameraAccess` 已完成首轮实现，`CameraScreen` 仍保持占位页面行为。下一步按照
第 9 节建立单一后置相机的最小实时预览链路。

## 9. 相机侧实施顺序

权限流程与相机运行分别推进。相机侧不直接从旧实现恢复完整能力，而是从可验证的最小预览
链路逐步增加功能。

当前基线阶段明确暂不实现：

- Live Photo；
- 曝光补偿与曝光交互；
- 前后摄像头切换；
- 摄像头缩放，包括倍率按钮、捏合缩放和模板驱动的隐式缩放。

这些能力不进入第一步的类型设计、页面状态或验收范围。第一步默认只需要支持一个后置相机的
实时预览，并在页面存续期间保持同一个 capture device 和固定 zoom。以后加入其他能力时再扩展
真实接口，不提前保留空开关或假状态。

### 9.1 第一步：建立统一预览界面

第一步建立一个统一且稳定的相机内容平面，并从这一阶段开始接入真实模板。预览优先遵守两个
不变量：

1. **最大化屏幕利用**：相机预览尽可能占用页面可用显示区域；每个模板同时尝试原始方向和
   旋转 90 度后的方向，并选择能够在预览区域内取得最大面积的矩形。
2. **模板切换不改变相机内容**：相机位置不变时，打开或切换任何模板都不能改变底层预览的
   取景范围、缩放、方向或画面变换。

第二个不变量比较的是相机内容的几何映射，而不是连续视频帧的逐像素数据。实时画面会随时间、
自动对焦和系统自动曝光自然变化，但同一个场景点在模板切换前后必须保持在同一个屏幕位置。

建议把预览界面拆成三个明确职责：

```text
CameraScreen
  └── CameraViewport
      ├── CameraPreview
      └── TemplateOverlay
          └── TemplateFrame
              └── CompositionCanvas
```

- `CameraViewport` 占用页面允许的最大连续显示区域，是稳定的相机内容平面。它的 frame 和预览
  变换不依赖当前模板。
- `CameraPreview` 在 `CameraViewport` 中显示底层相机画面，不读取模板比例，也不因模板变化
  重新配置设备、session、connection 或 zoom。
- `TemplateOverlay` 与 `CameraViewport` 共用坐标空间，但不改变底层预览。
- `TemplateFrame` 分别使用模板的 `width:height` 与 `height:width`，在 `CameraViewport` bounds
  内执行 aspect fit，并选择面积更大的有效矩形。
- `TemplateFrame` 在 `CameraViewport` 中水平、垂直居中。最大矩形计算必须是只依赖可用矩形与
  模板比例的确定性结果，同时返回 frame 和模板旋转角度。
- 当旋转方向胜出时，只旋转模板坐标系与引导内容，不旋转、缩放或重新裁切 `CameraPreview`。
- `CompositionCanvas` 只在 `TemplateFrame` 内把模板归一化坐标映射到屏幕坐标。
- `CameraScreen` 组合页面，但不直接操作 AVFoundation 连接、设备或 preview layer。

不同宽高比的模板不可能同时拥有相同边界并保持不变形，因此“内容绝对一致”不要求不同模板
拥有相同的 `TemplateFrame`。它要求所有模板都覆盖在同一张不移动、不缩放的相机内容平面上；
切换模板时只允许模板框、引导形状和框外视觉处理发生变化。

模板允许旋转 90 度以取得更大的屏幕利用面积。`3:4` 与 `4:3` 拥有完全相同的两个候选比例，
因此在同一屏幕和可用区域中必须得到同一个物理 `TemplateFrame`；两者只在模板坐标系的旋转
方向上不同。两个候选面积相同时保留模板声明的原始方向，避免无依据的旋转。

### 9.2 统一预览界面的边界

统一预览界面负责：

- 承载实时相机画面；
- 最大化利用页面可用显示区域；
- 提供不随模板变化的相机内容坐标空间；
- 在该坐标空间中计算当前模板能够占用的最大 `TemplateFrame`；
- 裁切超出 `CameraViewport` 的预览与 overlay 内容；
- 为后续点击映射和照片裁切提供稳定的预览几何基础。

统一预览界面不负责：

- 查询或申请系统权限；
- 创建授权说明和系统设置入口；
- 拍摄照片或保存到相册；
- Live Photo、曝光、镜头切换或其他相机控制；
- 任何形式的摄像头缩放；
- 决定导航和模板选择流程。

`CameraPreview` 不负责启动和停止相机会话。相机会话的生命周期由后续独立的运行对象管理，
预览组件只显示传入的预览源。这样替换或重建运行逻辑时，不需要同时改动页面布局和模板画布。

### 9.3 竖屏预览与输出契约

新相机第一阶段只建立竖屏拍摄链路。模板声明的宽高比先归一化为竖屏输出比例：短边作为输出
宽度，长边作为输出高度。

```text
3:4  → 3:4
4:3  → 3:4（模板坐标系旋转 90 度）
9:16 → 9:16
16:9 → 9:16（模板坐标系旋转 90 度）
1:1  → 1:1
```

因此，`3:4` 和 `4:3` 不只是共享同一个屏幕 `TemplateFrame`，也共享同一个照片裁切基线。
第一阶段选择 `4:3` 模板仍保存竖向 `3:4`；后续横版输出按上方 2026-09-24 决策执行。

普通照片处理必须使用预览阶段已经确定的相机内容映射和 `TemplateFrame`。拍摄时不能根据模板
原始方向重新选择 crop、旋转相机内容或改变 zoom。保存后的像素矩阵使用归一化后的竖屏比例，
方向元数据不得让同一张照片在不同读取方中再次旋转成横向输出。

### 9.4 第一步验收范围

第一步完成时应满足：

1. 相机权限已授权后，可以显示单一后置相机的实时画面。
2. `CameraViewport` 使用页面允许的最大显示区域，不为尚未实现的相机控件预留空间。
3. 任意模板的 `TemplateFrame` 都在原始方向和旋转 90 度方向中选择面积更大的结果。
4. 在同一相机会话中切换模板时，capture device、zoom、preview layer frame、视频方向、镜像和
   内容变换均保持不变。
5. 同一个场景特征点在模板切换前后保持同一屏幕坐标；模板只能改变覆盖层，不能造成预览跳动、
   放大、缩小或重新裁切。
6. `CameraPreview` 不查询权限，不包含拍摄、保存、缩放或其他相机控制状态；普通照片拍摄与保存
   由预览之外的独立运行对象和保存流程完成。
7. 进入和离开页面时，预览能按独立运行对象的生命周期启动与停止。
8. `3:4` 与 `4:3` 模板在同一可用区域内产生相同尺寸、中心点和位置的 `TemplateFrame`，只改变模板
   坐标系的旋转。
9. 使用 `3:4` 和 `4:3` 模板分别拍摄普通照片时，保存结果都必须是竖向 `3:4`，并使用相同的
   crop rect、输出像素尺寸和内容映射。
10. 当前阶段不因为尚未实现 Live Photo、曝光、镜头切换或缩放而增加占位逻辑。

第一轮真机测试使用固定机位和静态场景，依次选择 `3:4` 与 `4:3` 模板拍摄。验收时将两张输出
图像对齐比较：相同场景特征应位于相同归一化坐标，四边可见内容和输出尺寸应一致。由于两次
拍摄的时间、传感器噪声、自动对焦和系统自动曝光可能不同，“照片一样”指几何内容与裁切契约
一致，不要求编码数据或每个像素字节完全相同。

这项测试需要普通照片捕获、最小裁切处理、`PhotoLibraryPermission` 的 add-only 权限和相册写入
能力，但仍不引入相册读取、Live Photo、曝光控制、镜头切换或缩放。

预览使用的内容模式、设备旋转策略，以及预览到最终照片的映射仍需分别确认；在这些决策完成
前，不把旧实现的 `resizeAspectFill` 和裁切算法自动带入新方案。

## 10. 后续阶段：竖版裁切后的横版输出

第一阶段先证明 `3:4` 与 `4:3` 模板可以共享完全相同的竖屏预览、裁切和 `3:4` 保存结果。
这条基线完成后，再为原始横版模板恢复横版文件输出。

以 `4:3` 模板为例，后续处理顺序固定为：

```text
原始照片
  → 归一化到固定的竖屏预览坐标
  → 按已经验证的 TemplateFrame 映射完成 3:4 裁切
  → 将裁剪后的完整 3:4 像素矩阵整体旋转 90 度
  → 得到并保存 4:3 文件
```

这里的 90 度旋转是最终输出变换，不是采集方向变换，也不是镜像。向左或向右旋转由按快门时
已验证的物理握持方向策略决定，不由模板进入竖屏 `TemplateFrame` 时的旋转方向决定。

实现必须区分：

1. **采集归一化**：处理传感器方向和照片方向元数据，使原始照片与固定预览内容坐标一致。
2. **横版输出旋转**：在裁切完成后，按握持方向对整个裁剪结果应用 90 度旋转，得到横版文件。

### 10.1 传感器坐标与预览坐标

相机传感器拥有固定的原始像素坐标方向，用户看到的预览则可能已经由系统应用了 90、180 或
270 度的方向变换。因此，传感器原始坐标与用户实际预览坐标不能默认相同。

```text
传感器原始坐标
  → 采集方向与照片方向元数据
  → 用户实际看到的预览坐标
```

模板裁切矩形定义在用户预览坐标中，不能未经转换直接应用到传感器原始图片。普通照片处理必须
选择一种明确方式：

- 先把拍摄结果逻辑归一化到正立的竖屏预览坐标，再应用模板裁切；或
- 保留原始像素方向，但使用一份明确且可测试的坐标变换，把预览裁切矩形转换到照片坐标。

无论选择哪种实现，结果都必须等价：裁剪发生在用户实际看到的内容位置。采集归一化只解决
“传感器内容如何对应预览”的问题，不决定模板最终输出为竖向还是横向。

横版输出旋转不得：

- 在原始采集图片上先旋转再重新计算裁切；
- 以 AVFoundation capture connection 的旋转代替已验证的物理握持方向判断；
- 在旋转后再次裁切或改变 zoom；
- 只修改方向元数据而保留与声明比例不一致的像素矩阵。

保存后的 `4:3` 图像应拥有横向像素矩阵和规范化方向。验收时，把该 `4:3` 输出应用相反的
90 度旋转还原为 `3:4`，其四边内容和场景特征坐标必须与第一阶段直接保存的 `3:4` 基线一致。

这一阶段只增加最终输出方向变换，不改变预览、`TemplateFrame`、相机设备、zoom 或既有裁切
映射。其他横版比例，例如 `16:9`，后续遵守相同规则。

## 11. 基线完成后的能力优先级

只有权限、统一预览、模板布局、普通照片裁切保存和模板输出旋转全部通过验收后，才开始增加
相机控制能力。后续优先级为：

```text
当前竖屏拍摄与输出基线
  → 镜头缩放
  → Live Photo
  → 前后摄像头切换
  → 曝光等其他相机控制
```

### 11.1 镜头缩放

缩放是基线完成后的第一优先能力。加入缩放后仍必须保持模板与相机内容映射一致；模板切换不能
修改 zoom，zoom 变化也不能创建另一套模板布局或裁切规则。具体支持倍率按钮、连续缩放还是物理
镜头切换，在进入该阶段前单独设计。

### 11.2 Live Photo

Live Photo 在缩放之后实现。静态照片与配对视频必须复用届时已经验证的预览、裁切与模板输出
变换，不能各自建立方向或裁切逻辑。麦克风权限在该阶段通过 `Core/Permissions` 独立接入。

### 11.3 前后摄像头切换及其他控制

前后摄像头切换已接入；前置两档取景、屏幕补光与镜像行为见上方“2026-09-26 前置相机接入”。
设备能力差异和切换期间的预览稳定性仍需在实现时验证。曝光补偿等其他相机控制已按上方
2026-09-24 及后续决策接入，实际完成状态以当前代码为准。

## 12. 实施前仍需确认

以下问题尚未形成决定，开始对应代码前必须继续讨论或通过最小实验确认：

1. `CameraPreview` 如何把相机原始宽高比映射到固定 `CameraViewport`，包括 aspect fit、
   aspect fill 或显式固定裁切策略。
2. 第一阶段如何锁定竖屏坐标，包括应用方向限制、设备旋转事件和 AVFoundation connection
   方向之间的职责。
3. 如何把 `TemplateFrame` 从屏幕预览坐标精确映射到全分辨率照片坐标，并验证四边可见内容。
4. 第一阶段保存照片的具体编码格式、输出像素尺寸、色彩空间与元数据保留范围。
5. `CameraViewport` 对 Safe Area 的使用规则，以及后续控制 UI 是覆盖在预览上还是占用预览外
   空间。无论最终选择什么，模板切换都不能改变 viewport。

这些未决项不能从旧相机实现直接继承。解决顺序优先保证固定预览内容与 `3:4` / `4:3` 基线
测试，再讨论性能和扩展能力。

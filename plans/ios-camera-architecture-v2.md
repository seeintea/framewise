# iOS 相机当前架构与确认决策

> 状态：新相机已接入正式 SwiftUI 页面；实现状态与真机验收范围分开记录。
> 创建日期：2026-09-20。整理日期：2026-09-29。
> 本文以 `ios/Framewise/` 当前 Swift 代码和 `ios/Framewise.xcodeproj` 为依据，保留仍有效的设计。
> 已完成能力见 [功能状态](current-status.md)，待实现/待优化见 [后续工作](next-steps.md)，
> 测量、失败和撤回方案见 [相机实验记录](camera-experiments.md)，完整迁移节点见
> [迁移记录](migration-history.md)。早期实施顺序和已被替代的布局假设不再作为当前要求。

## 当前代码边界

当前源码仍使用 `Core/Camera` 和 `Core/Permissions`；文档整理不搬动代码、不提前建立新模块。
工程保持最低 iOS 18、Swift 5 language mode、MainActor 默认隔离。Xcode 26 是工程工具链基线；
部分历史检查使用本机 Xcode 27，不表示提高了最低工具链要求。

| 位置 / 类型 | 当前职责 |
| --- | --- |
| `Core/Permissions` | 从系统读取权限状态、显式请求授权、打开系统设置；无 UI、导航或长期状态缓存 |
| `CameraAccess` | 决定相机、相册 add-only、麦克风权限时机，承载说明与设置入口 |
| `CameraScreen` | 页面 UI、蒙版选择、预览布局、页面生命周期、设备状态与反馈 |
| `CameraPreview` | 用 `AVCaptureVideoPreviewLayer` 显示传入 session，把点击位置换算到设备坐标 |
| `CameraController` | MainActor 上的命令入口、readiness、会话事件、每拍资源到保存任务的交接 |
| `CameraEngine` | 串行会话队列上的 AVFoundation 配置、启停、镜头与设备控制、每拍独立 delegate |
| `CameraOrientationMonitor` | Core Motion 握持方向与点按后的朝向变化监测 |
| `CameraPhotoProcessor` / `PhotoAspectRatio` | 静态图方向归一化、整数比例中心裁切、最终旋转、水印与一次编码 |
| `LivePhotoProcessor` / `LivePhotoWatermarkCompositor` | 配对视频几何变换、水印合成、导出与配对资源保留 |
| `CameraPhotoSaver` | 接管采集后的处理、PhotoKit 写入、临时资源清理和失败通知 |
| `CameraAlbumThumbnail` | MainActor 共享小尺寸拍摄预览与最新可读相册缩略图；按快门时间排序，处理保存结果、相册变化和页面观察生命周期 |

相机核心不读取 `MaskVariant`、模板 ID 或 SwiftUI View。模板模块只声明可序列化数据；
蒙版覆盖层不请求权限、不操作相机会话，也不把构图线或注释写入成片。

## 权限与实际 Live 模式

```text
模板导航 → CameraAccess → 权限检查 / 用户确认后的请求 → CameraScreen
                                      ↓
                      普通：相机 + 相册 add-only
                      Live 偏好开启：另检查 / 按需请求麦克风
```

`Permissions.check`、`request` 接受所需权限数组，按传入顺序处理并去重；查询本身不弹授权框。
Core 对外返回 `PermissionStatus`，不把平台授权 enum 扩散到导航与模板层。相册 `.addOnly`
与 `.readWrite` 分开；缩略图只使用已经授予的读取权限，不因显示按钮主动申请整个相册的访问权。

相册按钮使用 SwiftUI `openURL` 尝试打开 `photos-redirect://`，无需 PhotoKit 读取授权。
该 scheme 没有 Apple 公开的稳定契约，失败时提示手动打开「照片」App，不承诺定位到具体资产。
读取缩略图前检查 `.readWrite`；完整 / 有限授权时按 `creationDate` 降序查询最新图片，有限授权
只覆盖用户允许的资产。使用 PhotoKit 小图请求（允许 iCloud 下载），保留查询结果以监听变化，
离页 / 后台取消请求和观察，重新进入 / 前台恢复查询；旧请求回调不能覆盖新查询。

普通照片和 Live 静态成品编码后生成最长边 256 像素的内存预览，保留裁切、方向和水印，不另存
临时图片。Live 静态预览不等待视频导出。预览按快门时间选择，保存结果按每拍 ID 结算；失败
撤回该拍预览并沿用全局失败提示。保存时明确设置快门时间，避免并行处理导致相册拍摄时间顺序
倒置。状态仅保留未完成拍摄、最近一次成功保存和一张相册小图，不持久化；共享状态用于覆盖
离页继续保存与重入相机。相册查询成功后接管已保存预览，允许删除 / 编辑反映到按钮。按钮显示
临时预览不代表写入成功，系统「照片」App 只能看到完成保存的资产。

参考：[Apple 照片权限与有限相册](https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app)、[PhotoKit 缩略图请求](https://developer.apple.com/documentation/photos/phimagemanager/requestimage(for:targetsize:contentmode:options:resulthandler:))。所用 PhotoKit / ImageIO / SwiftUI 能力均覆盖最低 iOS 18。

相机与 add-only 权限不可用时由 `CameraAccess` 阻止进入；未决定的权限先说明用途，用户继续后
逐项请求。回到前台重新读取系统真实状态。运行层仍检查相机授权，但不主动弹授权请求来修复错误。

Live 是持久化用户偏好，首次默认关闭；偏好与实际模式分开。偏好开启、麦克风未决定时仍申请
麦克风权限；拒绝/受限不阻止普通拍照。启动、主动切换、镜头切换、恢复按真实支持能力发布模式：

- 不支持 Live，麦克风拒绝/受限、设备缺失、创建或接入不可用时暂停 Live、移除音频输入，
  继续普通照片。图标与每拍设置使用实际模式；页面显示可关闭的降级原因，权限问题提供设置入口。
- 保留用户 Live 偏好；重入、恢复或切回支持镜头时重新尝试，成功后恢复 Live。用户主动关闭已
  启用的 Live 时清除偏好及提示。
- 视频输入替换、设备配置或会话运行失败仍是配置错误；不能把它们当作成功的普通照片降级。
- 权限任务离开页面后失效；旧配置结果不能覆盖新的页面启动周期。

Live 支持随 preset 和格式改变，镜头切换后重新查询。会话停止阶段提前准备支持设备的 Live
管线；运行时开关用 `isLivePhotoCaptureSuspended`，不反复启停 session 或改 enabled 属性。
关闭时移除麦克风输入，开启时原子配置音频并恢复；保留暂停状态跨停止与恢复。
刚开启的 Live 片段不会含恢复前的缓存。采集中只允许已在目标模式的幂等重用，实际模式变更
仍不能与未完成采集重叠。运行中增删音频输入不能保证所有设备完全无预览中断。

依据：[Live 支持能力](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesupported)、
[Live enabled](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocaptureenabled)、
[Live suspended](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/islivephotocapturesuspended)、
[原子会话配置](https://developer.apple.com/documentation/avfoundation/avcapturesession/beginconfiguration())。
已实现的暂停状态保留 API 自 iOS 16 可用，覆盖最低 iOS 18。

## 预览、蒙版与输出契约

`CameraViewportLayout` 一次计算预览和覆盖层的 UI 点数。模板原始比例决定拍摄比例，短边/长边
决定竖屏预览比例：`4:3 → 3:4`、`16:9 → 9:16`；正方形保持 `1:1`。在可用空间取最大
居中矩形，预览与蒙版共用它。不同显示比例会改变可见框；同显示比例换蒙版只改变覆盖层。
切换蒙版不重配 session、设备或 zoom。早期“固定 viewport、模板变化不改变可见框”假设已撤销。

`CameraPreview` 使用 `resizeAspectFill`。横版蒙版旋转到竖屏框内；左右横握使用相反 90°，
从一侧换到另一侧相对翻转 180°。蒙版旋转不决定照片输出旋转，蒙版不因前置镜像而翻转。
加载失败时以 `3:4` 布局且不绘制蒙版，正式页显示约 3.5 秒提示。

正式页无独立比例菜单；选中蒙版的原始宽高比更新唯一拍摄比例状态。当前支持下表五种比例，
宽高比不是固定输出像素尺寸：像素大小取决于源图与整数比例裁切。按快门冻结比例、模式与
握持方向，后续蒙版切换不会改变已发起请求或保存任务。

| 拍摄比例 | 裁切与最终方向 |
| --- | --- |
| `3:4` / `9:16` | 在正立竖屏坐标中心裁切，固定竖版输出，横握不改变它 |
| `4:3` / `16:9` | 先完成相应 `3:4` / `9:16` 竖版裁切，再整体旋转 90° |
| `1:1` | 固定正方形裁切，画面内容按可靠握持方向选择 0 / −90 / +90° |

横版旋转在快门时优先使用重力：`|x| ≥ 0.5` 且 `|x| > |y|`，x 为负向左、为正向右；
不明确时依次使用系统横握方向、本次页面最后明确的横握方向，最终默认向左。正方形优先使用
当前可靠重力、最近可靠握持、系统方向，仍无依据时不旋转。平放手机的绕屏幕法线旋转不能
靠重力可靠区分。真机曾出现左右横握都由 `UIDevice.orientation` 报告 portrait，因此保留
Core Motion 策略；采样频率为 10 Hz。

静态图通过 `UIImage` 解读源方向与镜像，在同一不透明 renderer 中合并归一化、中心裁切、
最终旋转，最后在输出坐标加水印。输出像素矩阵与目标比例一致，方向标签归一为 up，不能只改
EXIF 标签掩盖错误像素方向。Live 静态图与配对视频消费同一比例及最终 quarter turn；
视频读取 track `preferredTransform` 与有效区域，再裁切、旋转与合成水印。

比例和部分竖/横拍已经真机验证；预览四边与成片内容的精确对应仍需按比例、倍率、镜头验收。
当前没有迁入旧相机的显式可见区域映射。比例正确或本地几何回归通过不能替代取景一致性验收。

## 镜头、缩放、对焦与曝光

后置优先逻辑多摄，按设备能力回退；快捷档位来自虚拟镜头切换点与常用数字倍率，物理镜头
选择由 AVFoundation 决定。初始 `.photo` 会话接入并提交配置后设置显示 `1×`，恢复读取实际倍率。
后置连续捏合和快捷档位共用范围：设备最小倍率到 `min(maxAvailable, oneXFactor × 25)`，
显示上限为 `25×`，设备范围更小时采用设备上限。

快捷切换使用系统 `ramp(toVideoZoomFactor:withRate:)`。倍率跨度为 `abs(log2(target/current))`，
名义时长为 `min(0.15 + max(distance − 1, 0) × 0.04, 0.20)` 秒；系统平滑加速度，名义参数
不保证实际完成时间。连续点击从当前倍率重定向，捏合立即接管；Reduce Motion 时直接赋值。
用户已接受系统动画，不引入逐帧自定义动画、双摄预采集或型号偏移补偿。

前置默认宽档（设备最小可用倍率），窄档为宽档 `1.3×` 中心裁切并受设备范围限制；无法提供
不同档位时只显示宽档。它是可逆基线，不表示已与系统相机取景完全对齐。前置捏合收拢至 `0.9`
切窄、张开至 `1.1` 切宽，同次手势只选一档，取消后状态自动清理。每次前后切换重置倍率：
前置宽档、后置 `1×`；拍照/停止时未完成的前置 ramp 落到所选档位。

前置预览与照片输出连接关闭自动镜像，显式镜像前置、关闭后置；保存文字也会镜像。
闪光灯按真实 supported modes 提供 off → auto → on 并持久化选择，不使用 torch。
支持前置 Retina Flash 的设备复用系统闪光拍摄设置，没有自定义白色覆盖层。
前置取景、镜像和补光效果仍需真机验收。

点按通过 preview layer 转为设备坐标，设置连续自动对焦/测光的兴趣点，并在同次配置中把
曝光补偿归零；曝光滑杆采用设备实际 EV 范围。对焦/曝光基础控件已真机验收。选择闲置
3.5 秒后，零 EV 隐藏控件，非零 EV 保留并在 0.25 秒内降至 50% 不透明度；触摸区域独立，
淡化后可直接拖动，触摸恢复显示，拍照不主动清除非零选择。淡化拖动修复已获真机确认，
零 EV 消失与连续拍摄保留仍待逐项验收。

点按后系统主体变化通知与相对点按时镜头朝向约 30° 变化并行，任一路触发即恢复中心对焦、
测光及 0 EV，并清除页面选择。30° 是产品阈值；仅绕镜头轴转动不触发，纯平移仍依赖系统通知。
拖曝光或拍摄期间延后退出；新点按重建参考并使旧回调无效。移动方案已被接受，调整到 30° 后的
灵敏度与延后退出体验仍需验证，详情见 [实验记录](camera-experiments.md#2026-09-27-点按对焦退出的验证记录)。

依据：[系统 zoom ramp](https://developer.apple.com/documentation/avfoundation/avcapturedevice/ramp(tovideozoomfactor:withrate:))、
[videoZoomFactor](https://developer.apple.com/documentation/avfoundation/avcapturedevice/videozoomfactor)、
[最大可用倍率](https://developer.apple.com/documentation/avfoundation/avcapturedevice/maxavailablevideozoomfactor)、
[镜像](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored)、
[自动镜像](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/automaticallyadjustsvideomirroring)、
[Retina Flash](https://developer.apple.com/library/archive/documentation/DeviceInformation/Reference/iOSDeviceCompatibility/Cameras/Cameras.html)、
[闪光拍摄设置](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/flashmode)、
[主体变化](https://developer.apple.com/documentation/avfoundation/avcapturedevice/subjectareadidchangenotification)、
[Core Motion 数据](https://developer.apple.com/documentation/coremotion/getting-processed-device-motion-data)、
[rotationMatrix](https://developer.apple.com/documentation/coremotion/cmattitude/rotationmatrix)。

## 采集、处理与保存

在支持配置下启用 Zero Shutter Lag 与 Responsive Capture；使用 readiness coordinator 和每拍
独立 delegate，允许系统就绪时接受另一请求。当前 Controller 的进行中照片上限为 3，覆盖采集
及保存任务，保存结束/失败后释放名额。Screen 用每拍 ID 防止交错结果互相覆盖；拍摄期间设备
控制受锁但保持外观，快门还受 readiness 与反馈遮罩约束（普通 450 ms、Live 760 ms）。
资源交付后即把保存交给独立任务，不等待裁切、视频导出或 PhotoKit 才完成采集回调。

每拍使用独立设置，质量保持 `.balanced`。启动、镜头切换、恢复后查询 `availablePhotoCodecTypes`，
支持 `.hevc` 时选 HEIF，否则 JPEG；普通与 Live 静态照片采用同一策略。处理器按实际源类型编码，
保留相机元数据及 Live 配对标识，只有最终处理完成后编码一次；Image I/O 保持默认编码质量。

正式版本固定开启「logo + 蒙版相机」水印。logo 来自 `design-system/brand/logo-lens-golden-v4.png`，
字体使用统一字体资源；文字固定中文，水印在最终右下角保持正立，logo 带圆角、透明背景。
静态图同次绘制加水印；视频五种比例统一用复用 CIContext 与自定义 compositor，以最高质量
preset 一次导出，保留配对元数据、音轨与时间元数据。

静态图处理 actor 串行，限制全尺寸位图同时展开；每张 Live 的静态图与视频通过 `async let`
并行。actor 在 await 处可重入，不表示整个保存流程串行。处理后的 MOV 用 `shouldMoveFile`
移交 PhotoKit；原文件、导出文件在成功或失败后清理，视频成功而图片失败也清理导出文件。
保存成功无提示，处理/写入失败由根页面接收通知，离开相机后仍能反馈。应用进程内异步保存
已实现；系统挂起或终止后的保证尚未实现。

正式实现没有无水印开关、照片无损像素复用、视频直通/header 修改、B/C/D 对照、Scheme
benchmark、细分首帧日志或 signpost。它们只属于 [实验记录](camera-experiments.md)。
未采用 Fast Capture Prioritization 或 Deferred Photo Processing：前者会按需牺牲画质；
后者代理照片加工不能直接满足当前保存前裁切/旋转/水印契约。

依据：[响应式拍摄](https://developer.apple.com/videos/play/wwdc2023/10105/)、
[readiness coordinator](https://developer.apple.com/documentation/avfoundation/avcapturephotooutputreadinesscoordinator)、
[照片/Live 拍摄示例](https://developer.apple.com/documentation/avfoundation/capturing-still-and-live-photos)、
[可用照片编码](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/availablephotocodectypes)、
[照片保存](https://developer.apple.com/documentation/avfoundation/saving-captured-photos)、
[文件移交](https://developer.apple.com/documentation/photos/phassetresourcecreationoptions/shouldmovefile)、
[不透明 renderer](https://developer.apple.com/documentation/uikit/uigraphicsimagerendererformat/opaque)、
[视频合成](https://developer.apple.com/documentation/avfoundation/avvideocompositing)、
[CIContext 视频性能](https://developer.apple.com/videos/play/wwdc2020/10008/)。
当前 iOS 26 composition / pixel-buffer API 有 iOS 18–25 回退，不提高部署版本。

## 会话生命周期与恢复

离开页面或应用非 active 时停止会话，回到 active 重新启动。当前生命周期内只监听自己的
session 中断、中断结束及 runtime error；UI 更新在 MainActor，会话操作在已有串行队列。
停止时取消观察并使旧启动、切换、恢复回调失效，旧通知不能在离开或后台后重新启动相机。

中断暂停快门与设备控制，显示暂不可用；中断结束自动尝试恢复，设备被其他客户端占用时还
提供重试。已成功启动后的 `mediaServicesWereReset` 自动尝试恢复；初次启动失败、恢复期间
再次 runtime error 或一般 runtime error 停止并交给用户重试，不循环重启。

恢复重用视频输入与照片输出，重读权限/真实能力并同步 Live 偏好；成功后回到中心连续对焦、
测光和 0 EV，发布实际倍率，前置未完成动画落到所选档位。中断前采集继续接收成功/失败回调，
但不能将暂停页面改成就绪；已交给 saver 的任务继续处理。切换失败恢复原视频、音频、Live
状态与镜像，并重新读取原能力。

依据：[AVCaptureSession 通知](https://developer.apple.com/documentation/avfoundation/avcapturesession)、
[startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning())、
[Apple AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)。
简单真机试用未发现问题；电话/占用、Live 采集中断、媒体服务重置、暂停后离开尚未逐项验收。

## 当前诊断与验证边界

`CameraSessionPerformance` 在 Debug 和 Release 用 Logger.info 记录 `[CameraSession]`；每次权限、
启动、恢复、切镜头、Live 配置、停止有独立 UUID，包含 build、operation、phase、duration、
elapsed、outcome、detail。结果区分 success/fallback/failure/interrupted/cancelled/skipped。
日志写入系统日志存储，Xcode/Console 需启用 Info 级别；不生成应用日志文件。

| 阶段 | 边界 |
| --- | --- |
| `permission_check` / `permission_request` / `permissions_total` | 权限检查与请求，系统弹窗等待计入权限耗时 |
| `session_queue_wait` / `camera_permission_check` / `session_configuration` | 命令排队、相机授权校验和会话配置，复用配置可记 skipped |
| `session_start` / `session_stop` | 同步 startRunning / stopRunning |
| `live_photo_queue_wait` / `live_photo_configuration` / `live_photo_result` | Live 排队、配置/降级和返回 MainActor |
| `startup_total` / `recovery_total` | 命令开始到会话运行且实际 Live 状态发布 |
| `capture_ready` | 首次满足系统 readiness 和任务数量上限；停止/中断前未就绪记录对应结果 |
| `switch_total` / `stop_total` | 镜头切换或停止总耗时 |

`startup_total` 不含进入页面前导航、权限弹窗与布局；`capture_ready` 不证明预览首帧已显示，
也不能把不同 UUID 的权限耗时直接相加。Logger（iOS 14）及 ContinuousClock（iOS 16）覆盖 iOS 18。

Debug 的 `[CameraCapture]` 同 UUID/单调时钟记录快门、采集交付、静态图开始/绘制/编码结束、
视频开始/结束、PhotoKit 写入/成功，附镜头、编码类型/字节数/像素尺寸、Live 视频时长与照片时间。
`photoEncodeStarted` 是编码边界，`movieRecordingFinished` 不等于 MOV 完整交付，`saved`
只表示 PhotoKit 回调成功，不表示相册缩略图或 iCloud 已刷新。Release 没有拍摄细分日志。

历史记录确认 generic iOS Simulator 无签名构建通过；HEIF、降级与恢复还做过 macOS 临时
替身检查。它们不验证实际 AVFoundation 输入协商、iOS 水印/镜像/补光或真机 PhotoKit 播放。
构建与本地回归只能证明其检查范围，真机验收按 [功能状态](current-status.md) 和
[后续工作](next-steps.md) 分别记录。HEIF 样本保存成功、约 3000 ms Live 反馈、首拍调查
均见 [实验记录](camera-experiments.md)，不当作跨设备性能承诺。

## 旧相机迁移收尾（2026-09-28）

2026-09-20 前的旧相机已从活跃 target 移除，2026-09-28 移除当前工作树快照。
删除前 23 个旧文件均已跟踪、未修改，当前 target 和运行代码没有依赖；删除后无签名构建通过。
旧代码只在 Git 提交 `7810b0b` 的历史路径 `archive/ios-camera-legacy-2026-09-20/` 追溯，
快照原始来源为 `e7b40b9`。标题带“归档”的文档仅记录旧版本，不能证明新版本能力。

基础预览、普通/Live 捕获与保存、镜头和拍摄控制、恢复、HEIF、Live 自动降级与启动日志以
当前代码为准。用户确认以下旧行为暂不迁移；未写入当前需求的旧行为不自动成为重写要求：

| 旧行为 | 当前决定 |
| --- | --- |
| Live 开关后的短暂状态徽标 | 以实际 Live 图标表达模式；`CameraStatusBadge` 仅组件 preview，未接入 |
| 模板/握持不一致的“请旋转手机” | 保留当前方向与成片规则，暂不新增提示 |
| 权限与启动分阶段说明面板 | 保留当前权限入口、加载表现、分段日志 |
| 设备/输入/拍摄/处理/保存的细分文案和按原因操作 | 保留权限引导、现有相机错误及全局保存失败提示 |
| 预览可见区域到照片的旧显式映射 | 暂不迁移，按当前管线验证成片正确性 |

Live 降级提示与中断/恢复反馈已实现。相册入口在旧/新版本均为占位；当前多蒙版控件具备切换
逻辑，但产品入口没有真实关联 ID。它们与未来提示/精确映射需求统一在后续文档讨论，
不因旧实现存在而自动补齐。

## 已查阅的成熟实现

这些项目仅作实现参考，没有新增依赖。记录时核对的固定源码保留用于追溯：

| 主题 | 来源与适用范围 |
| --- | --- |
| zoom | [VisionCamera V5，91bae1f](https://github.com/margelo/react-native-vision-camera/blob/91bae1f08d549b50444ee16661dc4f4375cba0b6/packages/react-native-vision-camera/ios/Hybrid%20Objects/HybridCameraController.swift#L319) 直接系统 ramp；[NextLevel，2fa4250](https://github.com/NextLevel/NextLevel/blob/2fa42500caf7edd7136d23b64d9ecb5684d93d07/Sources/NextLevel.swift#L2446) 锁设备后限幅赋值；[Mijick Camera，0f02348](https://github.com/Mijick/Camera/blob/0f02348fcc8fbbc9224c7fbf444f182dc25d0b40/Sources/Internal/Manager/CameraManager.swift#L191) 与 [CaptureDevice](https://github.com/Mijick/Camera/blob/0f02348fcc8fbbc9224c7fbf444f182dc25d0b40/Sources/Internal/Manager/Helpers/Capture%20Device/CaptureDevice.swift#L59) 同样限制设备 zoom |
| 前置手势 | [Apple 手势](https://developer.apple.com/documentation/swiftui/adding-interactivity-with-gestures)、[updating](https://developer.apple.com/documentation/swiftui/gesture/updating(_:body:)) 与 [Zoomable 源码](https://github.com/ryohey/Zoomable/blob/main/Sources/Zoomable/Zoomable.swift)：实时响应和结束校正，仅参考手势生命周期，前置使用预设档位 |
| Live/恢复 | [AVCam 历史源码](https://github.com/AppTyrant/AVCamBuildingACameraApp/blob/master/Swift/AVCam/CameraViewController.swift)：独立请求与恢复流程；当前用自身 readiness/生命周期规则，不照搬持续保留音频输入 |
| 视频 compositor | [MetalPetal 实现](https://github.com/MetalPetal/MetalPetal/blob/master/Frameworks/MetalPetal/MTIVideoComposition.swift)：自定义合成器读取源 pixel buffer，在系统输出 buffer 合成；性能与 clean aperture 修正见实验文档 |
| 快门触感 | [SwiftUI sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))、[impact](https://developer.apple.com/documentation/swiftui/sensoryfeedback/impact(weight:intensity:))、[录音期间触感](https://developer.apple.com/documentation/avfaudio/avaudiosession/setallowhapticsandsystemsoundsduringrecording(_:))：light / 0.5 表示接受快门，非保存成功；实际触感及 Live 音频仍需验收 |

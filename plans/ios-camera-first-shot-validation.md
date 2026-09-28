# 首张拍摄延迟：调查结论与实验记录

日期：2026-09-28。状态：本轮调查已结束，不再继续采样或调整代码。

本文及 [Instruments 分析](ios-camera-trace-2026-09-28.md) 作为文档整理到 `main`；诊断日志、signpost 等代码保留在 `codex/camera-first-shot-performance` 实验分支，不随文档进入 `main`。本文描述实验状态，不代表主分支已实现这些诊断能力。

## 最终结论

- 用户每张都等待 `saved` 后才再次拍摄，排除了不同照片保存任务重叠；每张 Live Photo 内的静态照片与视频加工仍并行。
- Debug 日志多次出现 Live 首张较慢，主要差异在视频 export 启动至首次自定义合成请求之间。静态 renderer 返回前也出现额外耗时。尚未确认具体系统组件或因果关系。
- 关闭 Live 的对照没有出现同等幅度的首次成本。图标／字体加载、静态水印绘制和 CIContext 创建都不足以解释主要差异，没有证据归因于此前的字体或圆角改动。
- 静态照片先处理、视频后处理的串行实验使整张保存更慢，已撤回。实验分支恢复 Debug / Release 并行，不采用“仅首张串行”。
- 用户提供的 trace 实际为 Release，缺少诊断标记和等待线程数据。它确认了部分 CPU 工作位置，但不能解释之前 Debug 日志中的数百毫秒等待，也不能证明问题已消失。
- 本轮没有产出经过验证、值得合入主分支的性能优化。未引入预热，未降低画质，未改变编码或输出几何。

## 测试范围与主要结果

以当前 `ios/Framewise/Core/Camera/` 为依据，不沿用归档相机的结论。日志测试均为 4:3、turns=-1、4032×3024 JPEG；Live 视频为 1744×1308、约 29.5 fps、约 3 秒。各日志组未完整附带机型、系统版本、调试器状态及重启过程，不能视作严格控制变量的统计基准。

下表来自细分边界后的三组日志，单位 ms。每格按首张／第二张／第三张排列；区间包含并行及父子关系，不能逐行相加。累计值沿用每张 performance 时间线；并行 Live 第二张 shutter 标记为 +7.5 ms，其他偏移较小。

| 指标 | 关闭 Live | Live 并行 | Live 串行实验（已撤回） |
| --- | --- | --- | --- |
| captureDelivered 累计 | 457.7 / 434.6 / 423.7 | 2260.7 / 2206.3 / 2178.2 | 2352.1 / 2232.3 / 2361.2 |
| 交付后至相册写入开始 | — | 1306.2 / 740.3 / 678.2 | 1691.6 / 915.2 / 906.8 |
| 静态加工整体 | 282.8 / 234.7 / 245.0 | 771.3 / 262.3 / 263.8 | 329.4 / 254.9 / 241.6 |
| 绘制闭包结束至 renderer 返回 | 125.0 / 102.3 / 110.8 | 579.3 / 124.4 / 124.4 | 137.0 / 119.6 / 103.4 |
| export 至首次合成请求开始 | — | 552.1 / 83.3 / 69.1 | 657.2 / 38.3 / 38.0 |
| 首次合成请求处理 | — | 62.6 / 8.0 / 5.3 | 31.7 / 5.0 / 6.1 |
| 首次合成完成至 export 返回 | — | 616.6 / 615.7 / 571.1 | 614.2 / 602.0 / 607.5 |
| 相册写入 | 88.9 / 55.0 / 58.8 | 155.4 / 99.5 / 104.8 | 190.6 / 115.4 / 99.8 |
| saved 累计 | 832.2 / 727.1 / 729.9 | 3722.3 / 3046.1 / 2961.2 | 4234.3 / 3262.9 / 3367.8 |

对应日志 UUID 前缀：

- 关闭 Live：`1F5F3DE5`、`32574A51`、`A1658660`。
- Live 并行：`5A3A93B1`、`57EECE7A`、`172B144F`；视频时长 2.980、2.982、2.913 秒。
- Live 串行：`74E0C123`、`D83B5F46`、`CBB1BB0D`；视频时长 3.010、2.977、3.010 秒。

### 如何解释这些结果

并行组首张比第二张累计多 676.2 ms，其中交付多 54.4 ms、交付后加工多 565.9 ms、相册写入多 55.9 ms。首张 renderer 返回与首次合成开始仅相隔 6.7 ms，这是时间关联，不能直接证明 GPU、解码器或内部锁竞争。

串行组首张 renderer 收尾降至 137.0 ms，但照片完成后视频仍等待 657.2 ms 才开始首次合成。视频首次延迟可在没有同时进行静态处理的情况下出现，不能全部归因于两者竞争。稳态照片加工不再被视频覆盖，第二张交付后加工比并行多 174.9 ms。第三张还存在素材时长及采集耗时差异，不宜将总时间差全部归因于串行。

更早一组并行日志（`CE3F5C0A`、`03AD5DFC`、`96A1FB3C`）的 saved 为 4195.0 / 3056.8 / 3016.6 ms，export 至首请求为 729.9 / 62.1 / 64.4 ms；相册写入为 456.5 / 112.9 / 101.7 ms。与后续组相比，首张相册成本明显波动，不能认定存在固定约 350 ms 的首次写入开销。

两组 Live 首次 CIContext 创建分别为 33.1、44.2 ms，静态水印绘制约 18 ms，图标／字体资源加载不足 1 ms。最终 `cgImage` 获取在 0.1 ms 日志精度内几乎无成本。主要静态耗时已收窄到 `renderer.image` 内、绘制闭包结束之后；Release trace 的绘制列表执行栈支持这一工作位置，但不能替代对 Debug 等待的解释。

## 官方与成熟项目参考

- [Apple：预备拍摄资源](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/setpreparedphotosettingsarray(_:completionhandler:))：提前声明预计使用的设置可准备按需资源。当前 `prepareLivePhotoCapture` 仅启用／挂起 Live 管线；未调用此 API 本身不是瓶颈证据。
- [VisionCamera v4.7.3](https://github.com/mrousavy/react-native-vision-camera/blob/v4.7.3/package/ios/Core/CameraSession%2BPhoto.swift#L74-L82)：提交拍摄后准备后续相同设置的拍摄资源；该位置不提前准备首张，也不包含本项目的双资源水印链路。
- [NextLevel](https://github.com/NextLevel/NextLevel/blob/master/Sources/NextLevel.swift)：惰性创建并复用 `sharedCIContext`，与 Framewise 的 context 复用方式相近。动态 master 查阅于本记录日期。
- [Apple：Core Image 预热](https://developer.apple.com/documentation/coreimage/cicontext/preparerender(_:from:to:at:))：可提前编译 kernel、分配缓冲，收益依赖后续相同渲染参数。本轮没有证据支持直接加入预热。
- [Apple：Instruments 诊断](https://developer.apple.com/videos/play/wwdc2026/268/)：CPU 采样与调度／阻塞分析需要区分；缺少 CPU 样本不等于没有墙钟等待。

未找到能直接证明相同 Live Photo 双资源水印链路首拍延迟根因的成熟项目。参考方案用于选择测量边界，没有作为已修复的证据。

## 新增计时的读法

所有 `+...ms` 仍以该张快门为起点，用相同 UUID 的两个标记相减。并行任务交错输出是正常的；不要直接相减控制台相邻行。

| 待区分的成本 | 起点 → 终点 |
| --- | --- |
| 系统回调后的照片文件表示生成 | photoProcessingCallback → photoReceived |
| 照片元数据读取 | photoProcessingStarted → photoMetadataRead |
| 照片水印图标／字体资源加载 | photoWatermarkResourcesStarted → photoWatermarkResourcesReady |
| UIImage／CGImage 对象取得 | photoImageLoadStarted → photoImageLoaded |
| renderer 配置及对象创建 | photoRendererSetupStarted → photoRendererReady |
| 绘制上下文准备 | photoRendererReady → photoCanvasReady |
| 照片底图绘制（可能含延迟解码、颜色转换、旋转裁剪） | photoBaseDrawStarted → photoBaseDrawFinished |
| 静态水印测量、栅格化及叠加 | photoWatermarkDrawStarted → photoWatermarkDrawFinished |
| 绘制闭包结束至 renderer.image 返回 | photoDrawingActionsFinished → photoRendererReturned |
| renderedImage 函数返回／局部对象清理等 | photoRendererReturned → photoCGImageStarted |
| 最终 UIImage 的 CGImage 获取 | photoCGImageStarted → photoCGImageReady |
| 照片编码 | photoEncodeStarted → photoProcessingFinished |
| 视频轨道与属性加载 | movieProcessingStarted → movieAssetLoaded |
| 首次 CIContext 创建 | movieContextCreationStarted → movieContextCreated |
| 已有 context 复用 | movieContextReused（单点） |
| 视频水印资源加载 | movieWatermarkResourcesStarted → movieWatermarkResourcesReady |
| 视频水印栅格化／CIImage 包装 | movieWatermarkResourcesReady → movieWatermarkOverlayReady |
| 导出器创建 | movieExporterSetupStarted → movieExporterCreated |
| 导出配置及 metadata 加载 | movieExporterCreated → movieTranscodeStarted |
| 实际 export 调用至返回 | movieTranscodeStarted → movieTranscodeFinished |
| export 至首次合成请求开始 | movieTranscodeStarted → movieFirstFrameStarted |
| 首次合成请求处理 | movieFirstFrameStarted → movieFirstFrameFinished |

注意：旧日志的 `movieTranscodeStarted` 在创建 context／合成配置之前，新标记已移到真正调用 `export` 前。旧区间应与新日志 `movieCompositionStarted → movieProcessingFinished` 比较，不能直接拿新旧同名转码区间比较。

`photoImageLoaded` 不代表像素已全部解码；`movieFirstFrameStarted` 指第一个被处理的合成请求，不保证是影片时间线的第 0 帧。首次合成区间包含取帧、分配输出缓冲、Core Image 渲染及 finish 调用，不是纯 GPU kernel 计时。它是 export 的子区间，不能再次加到 export 耗时上。只记录一次首帧，不逐帧输出日志。

`movieCaptureInfo` 记录系统回调的影片时长与静态照片在影片内的时间点；`movieAssetLoaded` 记录实际轨道尺寸、帧率和素材时长。先确认处理工作量相近，再比较视频导出耗时。所有新增日志仅在 Debug 输出，Release 不计算日志字符串及其中的元数据查询。

## 实验分支保留内容

- `CameraCapturePerformance`：Debug 阶段日志与 signpost，Release 不计算日志字符串。
- `CameraEngine`：照片回调及影片时长信息。
- `CameraPhotoProcessor`、`PhotoAspectRatio`：资源加载、绘制闭包、renderer 返回、CGImage 获取及编码边界。
- `LivePhotoProcessor`、`LivePhotoWatermarkCompositor`：素材属性、context 复用、导出启动和首个合成请求；每次导出只记录一次首帧。
- 串行实验已撤回，当前 Debug 标记为 `liveProcessingMode mode=parallel`。

signpost 使用 `com.leviegu.framewise` subsystem 与 `.pointsOfInterest` 类别，文本日志仍为 `CameraCapture`。保留 `PhotoRenderer`、`PhotoRendererFinalize`、`MovieExport`、`MovieExportToFirstFrame`、`MovieFirstFrame` 区间与带 UUID 的 `CaptureStage` 事件。

`MovieExportToFirstFrame` 结束点位于自定义合成器的 renderLock 内，包含到达该处理点前的等待，不等于纯解码或编码初始化。未交付首帧就结束时以 `exportEndedBeforeFirstFrame` 收尾；不能将它解释为正常首帧到达。首次合成区间返回也不单独证明导出成功。

## 验证与未解决事项

实验代码完成 generic iOS Simulator、无签名的 Debug / Release 构建验证；最后的 signpost 类别修正再次通过 Debug 构建。没有新增 Swift 警告，仅有未依赖 AppIntents 的 metadata extraction 提示。未启动模拟器或安装、操作真机；真机日志和 trace 由用户提供。构建通过不代表性能改善。

实际构建工具为 Xcode 27 / iOS 27 SDK，target 保持 iOS 18、Swift 5，未修改工程设置。OSSignposter（iOS 15）、OSAllocatedUnfairLock（iOS 16）均满足最低版本。

本轮在无法进一步确定等待来源、继续追踪收益有限的情况下结束。若未来实际使用仍受影响，应先建立独立的 Release 总保存延迟基线，再决定是否继续。要追踪本轮 Debug 现象，需要 Debug Profile、拍摄前开启的 Points of Interest 标记，以及能覆盖等待区间的线程状态数据；这是重新启动调查时的前提，不是当前待办。

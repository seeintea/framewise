# 相机实验与验证记录

> 状态：历史实验与验收证据。整理日期：2026-09-28。
> 本文集中保存新相机重写期间的测量、失败、撤回方案和验收边界；不按临时实验分支组织，
> 不承诺实验代码、提交、stash 或本地附件在 Git 中可恢复。文中的“本轮”“当前”均指该节记录时。
> 实验参数、B/C/D 对照、细分计时与 signpost 不是当前产品接口。当前实现见
> [功能状态](current-status.md)，设计见 [相机架构](ios-camera-architecture-v2.md)，后续事项见
> [待实现与待优化](next-steps.md)。迁移过程见 [迁移记录](migration-history.md)。

## 阅读结论

| 记录 | 已得到的结论 | 不能外推的范围 |
| --- | --- | --- |
| 2026-09-27 静态照片绘制融合 | 一次绘制可保持既有尺寸与方向，减少重复生成全尺寸图片 | 本地合成素材不证明 HEIF、HDR 或真机提速 |
| 2026-09-27 无水印快速路径 | 4:3 / turns=-1 小样本中，普通约 572 ms、Live 约 2.47 s | 正式版本固定水印，已不保留这些快速路径 |
| 2026-09-27 水印对照 | Core Image 在同 MOV 转码对照中接近无水印强制导出的成本；已采用全比例 CI 视频水印 | 首拍未优化，所有镜头/系统/色彩组合未验收 |
| 2026-09-28 首拍调查 | 首次 export 到首个合成请求及 renderer 收尾有额外等待；串行处理更慢，已撤回 | 未找到根因，未产出可验证的性能修复，调查已结束 |
| 2026-09-28 Release trace | 确认 renderer 绘制列表的工作位置 | 缺少捕获标记与等待线程，不能解释 Debug 首拍等待 |
| 2026-09-28 HEIF 比较 | 9 张成功保存为 HEIC；后续普通/Live 比既有 JPEG 约慢 160/244 ms | 非同素材单变量实验，不能把总差值全部归因于 HEIF |

采集交付、快门再次可用和 PhotoKit 写入成功是不同时间边界。阶段中位数不能相加；
Live 静态图与视频加工并行，其耗时也不能相加当作端到端等待。历史旧相机的 2026-09-15
基线继续保留在 [归档性能文档](ios-camera-performance.md#43-2026-09-15-首轮真机基线)，
不与新相机直接混用。

## 2026-09-27 静态照片优化的早期基线

以下记录来自重写相机的一次绘制融合之前；当时的双 renderer、普通照片 UIImage 写入和
未加水印状态已被后续实现替代。


快门何时恢复与最终资源何时保存完成是不同问题。图片加工优化主要减少资源交付后的成本，
不直接消除系统成像或 Live MOV 交付等待。

2026-09-27 首批真机日志各包含五张普通照片和五张 Live；以下为分段中位数，单位毫秒。
该组为 `4:3`、`quarterTurns=-1`、闪光关闭、画质 `.balanced`，静态图 `4032×3024`。
未覆盖全部比例、方向、机型和温度条件。

| 阶段 | 普通照片 | Live Photo |
| --- | ---: | ---: |
| 系统静态图交付 | 440.0 | 444.5 |
| 静态图解码、方向归一化与裁切绘制 | 318.8 | 348.9 |
| 静态图第二次绘制：最终旋转 | 198.2 | 201.6 |
| 静态图显式重新编码 | 由 Photos 区间包含 | 301.4 |
| 静态图完整加工 | 525.5 | 872.1 |
| Live 视频导出 | — | 555.7 |
| 按下至保存任务完成 | 1387.3 | 4027.5 |

各阶段中位数独立计算，不能相加当作总耗时。裁切阶段同时包含解码与方向处理，不能将
其全部成本归为裁掉边缘。Photos 完成回调不等于相册已展示或 iCloud 已同步。

实验还观察到：

- 去掉应用加工的性能对照显著缩短了资源交付后的保存区间，支持优化加工链路的价值，
  不代表应取消必要的裁切、水印或其他输出要求。
- 连拍后单张加工和视频导出可能更慢；actor 方法遇到 await 可重入，不能把 actor 当成
  覆盖完整异步保存流程的串行队列。并发数量和资源竞争需单独验证，不在图片融合改动中调参。
- 系统 Live MOV 交付也会波动。不能将所有等待都归因于 PhotoKit 或应用视频导出。
- 实验做过裁切与旋转的单次绘制，说明这是一条可行的实现方向；不把实验整套代码作为
  当时正式实现已经验收通过。

### 一次绘制的本地回归验证

验证记录（2026-09-27）：

- 使用本机 Xcode 27.0，保持 Swift 5 与最低 iOS 18。首次执行工程要求的
  `-scheme Framewise` 命令时，checkout 没有该 scheme；直接对现有 target 做 Debug
  无签名 `iphonesimulator` 构建，arm64 与 x86_64 均通过。用户随后新建共享
  `xcshareddata/xcschemes/Framewise.xcscheme`，检查其 target 引用及各 action 配置无误，
  再次使用规定的 scheme 与 `generic/platform=iOS Simulator` 命令构建通过。
- 在 Mac 上直接运行临时 Mac Catalyst UIKit 命令行程序，对照优化前的两次绘制与
  融合入口。1005 个用例覆盖 JPEG、带 alpha 的 sRGB PNG、8 种 EXIF 方向、5 个比例、
  `-1/0/1` 旋转，以及 `96×128`、`97×131`、`98×130` 和 `1×1` 源尺寸与无效数据。
  768 个有效输出的尺寸、正立方向与 `scale = 1` 检查通过；192 个过小源图用例的新旧
  nil 行为一致，45 个无效输入用例均被拒绝。
- 有效输出统一转为 sRGB RGBA8 后，640 组逐像素一致；128 组在 `97×131` 的半像素
  居中裁切且非零旋转时存在最大 `1/255` 通道差异。差异与采样或取整舍入相符，未发现
  几何偏移；不承诺融合后逐字节相同。临时脚本和差异表保存在
  `/private/tmp/framewise-render-regression/`，未加入应用 target。

以上不覆盖 HEIF、广色域或 HDR，也不替代 iOS 真机成片、Live 配对播放与 PhotoKit 写入
验收。未启动模拟器、安装应用或操作真机，具体耗时收益仍待同组实际相机资源对比。

### 当时查阅的实现依据

- [Apple UIGraphicsImageRenderer](https://developer.apple.com/documentation/uikit/uigraphicsimagerenderer)、
  [UIImage.draw(in:)](https://developer.apple.com/documentation/uikit/uiimage/draw(in:))：在同一 CGContext
  中组合变换，UIKit 解读源方向。
- [SDWebImage 图像变换源码](https://github.com/SDWebImage/SDWebImage/blob/master/SDWebImage/Core/UIImage%2BTransform.m)：
  renderer 中用 CGContext 处理图像几何，仅作源码参考。
- [Apple ImageIO 输出](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/ikpg_dest/ikpg_dest.html)、
  [CIImage](https://developer.apple.com/documentation/coreimage/ciimage)、
  [AVVideoComposition](https://developer.apple.com/documentation/avfoundation/avvideocomposition)、
  [Core Animation 合成工具](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool)。

目标是应用侧一次最终图片生成与一次最终编码，不承诺系统内部没有中间 buffer，也不把
Core Image 延迟求值等同于硬件只有一个 pass。未新增上述开源项目作为依赖。


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

## 2026-09-27 水印方案实验

> 以下启动参数、无水印路径、C/D 选择与 benchmark 步骤仅描述当时实验方法，当前代码已移除。
> 后续正式实现固定开启水印，五种比例统一采用 Core Image；黑底样式也已被当前透明水印样式替代。

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
当时实验末期策略见下方“全部比例统一使用 Core Image”。
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

**当时提出的后续调查项：首次拍摄偏慢。** 本轮先完成全比例水印路径统一，首次拍摄开销尚未优化，
单独纳入后续工作，不在这次验收中视为已解决。此前 D 的 4:3 日志可作为现象参考：
首张总耗时 3972.9 ms，后五张为 2884.5–3076.7 ms；首张封面处理 968.5 ms、
视频导出 1309.5 ms，两者并行，不能相加。该组数字不代表这次所有比例的首次耗时。

后续定位与验证要求：

- 分开记录应用重新启动后的首张与后续拍摄，固定设备、镜头、场景、比例及水印设置。
- 分别检查采集交付、封面绘制/编码、视频合成准备/导出和相册写入，定位首次额外等待；
  初始化、缓存建立或资源竞争仅作为待验证方向，不预先认定为根因。
- 优化后同时对比首张和后续拍摄的耗时与成片效果；若尝试预热，还需检查启动耗时及资源
  占用，避免把首次拍照的等待简单搬到应用启动阶段。

首拍调查已在 2026-09-28 结束，结论见下节。上面的定位要求是重新启动调查时的参考，
不表示仍在持续采样；是否继续优化先看独立的 Release 实际保存延迟。

## 首张拍摄延迟：调查结论与实验记录

日期：2026-09-28。状态：本轮调查已结束，不再继续采样或调整代码。

诊断日志、signpost 等代码仅属于当时实验，不纳入当前正式实现；不承诺实验代码在 Git 中留有记录。本文保留测量证据与局限。

### 最终结论

- 用户每张都等待 `saved` 后才再次拍摄，排除了不同照片保存任务重叠；每张 Live Photo 内的静态照片与视频加工仍并行。
- Debug 日志多次出现 Live 首张较慢，主要差异在视频 export 启动至首次自定义合成请求之间。静态 renderer 返回前也出现额外耗时。尚未确认具体系统组件或因果关系。
- 关闭 Live 的对照没有出现同等幅度的首次成本。图标／字体加载、静态水印绘制和 CIContext 创建都不足以解释主要差异，没有证据归因于此前的字体或圆角改动。
- 静态照片先处理、视频后处理的串行实验使整张保存更慢，已撤回。实验结束时恢复 Debug / Release 并行，不采用“仅首张串行”。
- 用户提供的 trace 实际为 Release，缺少诊断标记和等待线程数据。它确认了部分 CPU 工作位置，但不能解释之前 Debug 日志中的数百毫秒等待，也不能证明问题已消失。
- 本轮没有产出经过验证、值得纳入正式实现的性能优化。未引入预热，未降低画质，未改变编码或输出几何。

### 测试范围与主要结果

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

#### 如何解释这些结果

并行组首张比第二张累计多 676.2 ms，其中交付多 54.4 ms、交付后加工多 565.9 ms、相册写入多 55.9 ms。首张 renderer 返回与首次合成开始仅相隔 6.7 ms，这是时间关联，不能直接证明 GPU、解码器或内部锁竞争。

串行组首张 renderer 收尾降至 137.0 ms，但照片完成后视频仍等待 657.2 ms 才开始首次合成。视频首次延迟可在没有同时进行静态处理的情况下出现，不能全部归因于两者竞争。稳态照片加工不再被视频覆盖，第二张交付后加工比并行多 174.9 ms。第三张还存在素材时长及采集耗时差异，不宜将总时间差全部归因于串行。

更早一组并行日志（`CE3F5C0A`、`03AD5DFC`、`96A1FB3C`）的 saved 为 4195.0 / 3056.8 / 3016.6 ms，export 至首请求为 729.9 / 62.1 / 64.4 ms；相册写入为 456.5 / 112.9 / 101.7 ms。与后续组相比，首张相册成本明显波动，不能认定存在固定约 350 ms 的首次写入开销。

两组 Live 首次 CIContext 创建分别为 33.1、44.2 ms，静态水印绘制约 18 ms，图标／字体资源加载不足 1 ms。最终 `cgImage` 获取在 0.1 ms 日志精度内几乎无成本。主要静态耗时已收窄到 `renderer.image` 内、绘制闭包结束之后；Release trace 的绘制列表执行栈支持这一工作位置，但不能替代对 Debug 等待的解释。

### 官方与成熟项目参考

- [Apple：预备拍摄资源](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/setpreparedphotosettingsarray(_:completionhandler:))：提前声明预计使用的设置可准备按需资源。当前 `prepareLivePhotoCapture` 仅启用／挂起 Live 管线；未调用此 API 本身不是瓶颈证据。
- [VisionCamera v4.7.3](https://github.com/mrousavy/react-native-vision-camera/blob/v4.7.3/package/ios/Core/CameraSession%2BPhoto.swift#L74-L82)：提交拍摄后准备后续相同设置的拍摄资源；该位置不提前准备首张，也不包含本项目的双资源水印链路。
- [NextLevel](https://github.com/NextLevel/NextLevel/blob/master/Sources/NextLevel.swift)：惰性创建并复用 `sharedCIContext`，与 Framewise 的 context 复用方式相近。动态 master 查阅于本记录日期。
- [Apple：Core Image 预热](https://developer.apple.com/documentation/coreimage/cicontext/preparerender(_:from:to:at:))：可提前编译 kernel、分配缓冲，收益依赖后续相同渲染参数。本轮没有证据支持直接加入预热。
- [Apple：Instruments 诊断](https://developer.apple.com/videos/play/wwdc2026/268/)：CPU 采样与调度／阻塞分析需要区分；缺少 CPU 样本不等于没有墙钟等待。

未找到能直接证明相同 Live Photo 双资源水印链路首拍延迟根因的成熟项目。参考方案用于选择测量边界，没有作为已修复的证据。

### 新增计时的读法

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

### 当时的诊断内容（当前未提供）

- `CameraCapturePerformance`：Debug 阶段日志与 signpost，Release 不计算日志字符串。
- `CameraEngine`：照片回调及影片时长信息。
- `CameraPhotoProcessor`、`PhotoAspectRatio`：资源加载、绘制闭包、renderer 返回、CGImage 获取及编码边界。
- `LivePhotoProcessor`、`LivePhotoWatermarkCompositor`：素材属性、context 复用、导出启动和首个合成请求；每次导出只记录一次首帧。
- 串行实验已撤回，当前 Debug 标记为 `liveProcessingMode mode=parallel`。

signpost 使用 `com.leviegu.framewise` subsystem 与 `.pointsOfInterest` 类别，文本日志仍为 `CameraCapture`。保留 `PhotoRenderer`、`PhotoRendererFinalize`、`MovieExport`、`MovieExportToFirstFrame`、`MovieFirstFrame` 区间与带 UUID 的 `CaptureStage` 事件。

`MovieExportToFirstFrame` 结束点位于自定义合成器的 renderLock 内，包含到达该处理点前的等待，不等于纯解码或编码初始化。未交付首帧就结束时以 `exportEndedBeforeFirstFrame` 收尾；不能将它解释为正常首帧到达。首次合成区间返回也不单独证明导出成功。

### 验证与未解决事项

实验代码完成 generic iOS Simulator、无签名的 Debug / Release 构建验证；最后的 signpost 类别修正再次通过 Debug 构建。没有新增 Swift 警告，仅有未依赖 AppIntents 的 metadata extraction 提示。未启动模拟器或安装、操作真机；真机日志和 trace 由用户提供。构建通过不代表性能改善。

实际构建工具为 Xcode 27 / iOS 27 SDK，target 保持 iOS 18、Swift 5，未修改工程设置。OSSignposter（iOS 15）、OSAllocatedUnfairLock（iOS 16）均满足最低版本。

本轮在无法进一步确定等待来源、继续追踪收益有限的情况下结束。若未来实际使用仍受影响，应先建立独立的 Release 总保存延迟基线，再决定是否继续。要追踪本轮 Debug 现象，需要 Debug Profile、拍摄前开启的 Points of Interest 标记，以及能覆盖等待区间的线程状态数据；这是重新启动调查时的前提，不是当前待办。


## Untitled.trace 分析：CPU 热点与采集边界

分析日期：2026-09-28。输入为用户提供的 `Untitled.trace`，原始文件未修改、未纳入仓库。本轮调查已结束；总结果见 [首张拍摄延迟调查记录](ios-camera-first-shot-validation.md)。本文记录证据边界，不代表已找到或修复根因。

### 录制事实

- 模板 Time Profiler，单次运行约 29.270 秒，启动了 Framewise 新进程。
- 系统识别的硬件为 iPhone 16 Pro Max，iOS 27.0（24A437）；设备的自定义名称不作为机型依据。
- **构建为 Release**：trace 中 Framewise 主二进制 UUID 为 `15464400-8904-37CF-B934-F99D10DF25B8`，与本机 `Release-iphoneos/Framewise.app/Framewise` 的 dwarfdump 结果一致；Debug 主二进制 UUID 不同。不是仅凭函数优化形式推断构建配置。
- CPU 采样间隔约 1 ms，导出 time-profile 共 1810 个样本、总计 1810 ms 的采样权重。
- 录制目录显示 `record-waiting-threads=0`、`all-thread-states=NO`，没有完整线程状态／System Trace 数据。采样中偶见 wait/trap 函数不代表已测到其完整等待时间。
- signpost 采集配置针对 `PointsOfInterest`。导出的 signpost 没有 `CameraCapture`、`MovieExportToFirstFrame` 或捕获 UUID，无法对齐每张的快门及保存区间。当前诊断原本只在 Debug 编译；Release 构建和类别过滤是两项独立的采集缺口。

### 可确认的 CPU 热点

由应用方法调用栈可识别约第 11 秒与第 20 秒的两组照片加工。下面按 10–13 秒、19–22 秒两段隔离应用加工采样，**不是通过缺失的 capture UUID 得到的区间**。数字是包含下层调用的 CPU 采样权重，不能当作墙钟耗时，父子行不能相加，也不能涵盖系统服务或 GPU 的全部工作。

| 应用路径 | 第一组 CPU 权重 | 第二组 CPU 权重 |
| --- | ---: | ---: |
| CameraPhotoProcessor.process | 207 ms | 209 ms |
| PhotoAspectRatio.renderedImage | 105 ms | 115 ms |
| 最终 JPEG finalize（CGImageDestinationFinalizeEx） | 56 ms | 57 ms |
| 自定义视频合成请求 startRequest（所有采到的帧） | 98 ms | 100 ms |

静态处理采样在工作线程，并非 Main Thread。第一组 renderer 方法的样本时间约为 11.087–11.245 秒，第二组为 20.373–20.515 秒；这只是首次／末次被采到的时间，不是精确进入／退出时刻。

静态 renderer 的主要调用路径为：

```text
PhotoAspectRatio.renderedImage
  UIGraphicsImageRenderer.imageWithActions
    UIGraphicsImageRendererContext.currentImage
      rip_auto_context_create_image
        rip_auto_context_rasterization_loop
          CGDisplayListDrawInContextDelegate
            CG::DisplayList::executeEntries
              ripc_DrawImage / 图像读取 / 颜色转换
```

这证明本次执行中有绘制列表在生成最终 UIImage 时执行，可以解释为什么之前闭包中的 `image.draw` 返回很快、renderer 返回前还有明显耗时。不能仅由函数名 `img_data_lock` 推断锁竞争。

还观察到 `RGBAf16_mark_inner` 和 vImage 色彩／像素格式转换、内存拷贝。它们属于后续可调查的渲染成本，但两组成本相近，尚不能解释首拍额外等待。不能据此直接改成 SDR 或较低位深，避免无证据地改变照片输出效果。

第一组 context 创建路径包含 `CI::MetalContext::init`、系统 kernel library / binary archive 加载等，`CIContext.init` 的采样权重约 12 ms。这支持首次创建有初始化工作，但并不等于之前数百毫秒的全部延迟。

视频自定义渲染的可见 CPU 权重两组接近。没有证据把以前首拍增加约 600 ms 归因于逐帧水印计算；也没有足够信息排除系统服务、调度或其他启动等待。

### 结论与修正

1. 本份数据确认了静态 renderer 的实际工作发生位置，并显示两次静态加工的 CPU 权重接近。
2. 缺少 capture 标记和等待线程数据，不能精确框选 export 至首个合成请求，更不能把该等待定位为某个锁或编码器初始化。
3. 当前样本为 Release，而之前逐阶段日志来自 Debug，不能直接将两者的首拍差异归因于某个代码改动，也不能宣称问题已消失。
4. 后续实验已将 signposter 改为 `.pointsOfInterest`，文本 logger 保留原类别。与本次录制配置匹配；依据 [Apple 的 CPU 分析与 signpost 示例](https://developer.apple.com/documentation/xcode/analyzing-cpu-profiles-with-call-tree-views)。类别 API 自 iOS 12 可用，符合项目最低 iOS 18。该改动的 Simulator 无签名构建通过；诊断代码未纳入正式实现。
5. 若继续复现旧日志的问题，应明确 Profile 使用 Debug，并在拍照前录制、确认 Points of Interest 中出现 `MovieExportToFirstFrame`。如要分析等待原因，还需 Thread State Trace / System Trace。最终是否值得优化，应以 Release 的真实保存延迟独立判断。

本轮未调整图像格式、画质、context 或并行策略。原始 trace 保持不变，导出 XML 和统计文件仅作为本地临时分析产物，不纳入仓库，也不作为长期可用附件。只保留整理后的文档证据，不承诺诊断代码可从 Git 恢复。


## HEIF 真机耗时与既有 JPEG 数据比较

日期：2026-09-28。结论：本轮 HEIF 后续拍摄的总保存时间比最近的 JPEG 记录增加，
普通照片约 160 ms，Live Photo 约 244 ms。照片编码区间也更长，但采集、视频处理与
PhotoKit 写入均有变化，不能将全部总时间差归因于编码格式。

### 数据来源与比较范围

- 本轮 HEIF 原始日志（会话附件 `9acd6a21-7f7a-4c12-8ba5-d300ac589890`，不随仓库保存）：
  6 张 Live Photo，随后 3 张普通照片。
- 最近的 JPEG 普通照片日志（会话附件 `883bda39-594c-46d6-b8c2-8b47252e3587`，不随仓库保存）：
  `1F5F3DE5`、`32574A51`、`A1658660`，共 3 张。
- 最近的 JPEG 并行 Live 日志（会话附件 `151c6c9a-74b2-48ff-8706-90985d18412f`，不随仓库保存）：
  `5A3A93B1`、`57EECE7A`、`172B144F`，共 3 张。
- 更早的 JPEG / Core Image 水印实际保存日志（会话附件 `61c8f198-dc30-4663-b544-efe927076887`，不随仓库保存）：
  `3E93FD11`、`464B6C07`、`CC2EA8E8`、`0E6385AD`、`F8335F8F`、`2DA4BA1D`，共 6 张。

既有记录见 [首张调查文档](ios-camera-first-shot-validation.md) 与
[水印真机验收记录](#core-image-真机验收与默认路径)。
比较选取带水印、静态照片与视频并行处理的路径；不使用已撤回的串行实验，也不使用
更早无水印直存的 572 ms / 2.47 s 作为基线。

本轮快门条件均为后置、`4:3`、`turns=-1`，最终静态图为 `4032×3024`，与最近 JPEG
记录的比例、旋转与尺寸一致。9 张均记录到 `saved`，静态输入与输出均为 `public.heic`，
最终照片大小为 1,856,215–1,946,258 字节（十进制约 1.86–1.95 MB）。这确认编码选择和
保存链路成功；实际画质、水印效果、Live 播放和声音仍需观察成片。

各组没有完整的设备、系统、温度及调试状态信息，场景和资源也非同一份。最近 JPEG 测试
按当时说明分别重启应用采集普通/Live 三张；本轮普通照片位于六张 Live 之后，不是普通
照片冷启动首拍。下表取 JPEG 后两张、HEIF 后五张 Live / 全部三张普通照片的中位数。

### 后续拍摄比较

单位 ms；编码取 `photoEncodeStarted → photoProcessingFinished`，静态加工取
`photoProcessingStarted → photoProcessingFinished`，视频加工取
`movieProcessingStarted → movieProcessingFinished`，写入取 `libraryWriteStarted → saved`。
采集交付和总保存沿用已有记录的 `captureDelivered`、`saved` 累计值。

| 指标 | JPEG 普通（n=2） | HEIF 普通（n=3） | JPEG Live（n=2） | HEIF Live（n=5） |
| --- | ---: | ---: | ---: | ---: |
| 采集交付 | 429 | 478 | 2192 | 2306 |
| 静态加工整体 | 240 | 291 | 263 | 346 |
| 其中照片编码 | 100 | 129 | 109 | 158 |
| 视频加工整体 | — | — | 709 | 763 |
| 相册写入 | 57 | 113 | 102 | 173 |
| 总保存 | 729 | 888 | 3004 | 3247 |

精确总保存中位数：普通照片 728.50 → 888.20 ms，增加 159.70 ms（21.9%）；
Live Photo 3003.65 → 3247.30 ms，增加 243.65 ms（8.1%）。
普通编码增加 28.70 ms，Live 静态编码增加 49.05 ms。静态加工整体分别增加 50.65 / 83.35 ms，
编码前的读取、解码和绘制区间也有增加。

JPEG Live 第二张的 `shutter` 日志在计时起点之后 7.5 ms 输出。如果严格按每张
`saved − shutter` 计算，JPEG / HEIF 后续 Live 中位数为 2999.85 / 3247.00 ms，
差 247.15 ms；普通照片差 159.75 ms。与沿用旧累计值的结论一致。

更早的 JPEG / Core Image 水印组后五张中位数为 3007.9 ms，HEIF 比它增加 239.4 ms
（8.0%）；该组与最近 JPEG 后续总时间接近，支持本轮约 0.24 秒的差异。

各阶段中位数独立计算，不能相加还原中位数总时间。Live 的图片与视频并行：本轮后续
照片处理在 +2633–2679 ms 完成，视频在 +3039–3088 ms 完成，相册写入仍等待视频。
因此静态编码增加约 49 ms 不能直接当作 Live 总等待增量。与最近 JPEG 后两张比较，
采集交付增加约 114 ms、视频加工增加约 54 ms、相册写入增加约 71 ms，也都影响端到端结果。

本轮后续 Live 源视频为 2.987–3.020 秒；最近 JPEG 两条为 2.982 / 2.915 秒，工作量
略有差别。正式实现与诊断实验的 `movieTranscodeStarted` 位置也不同，本次比较采用完整
视频加工区间，避免把标记位置变化误算成导出性能变化。

### 本轮逐张数据与首次成本

单位 ms；首列按日志顺序，所有总保存值沿用 `saved` 累计时间。

| 顺序 / UUID 前缀 | 模式 | 采集交付 | 静态加工 | 照片编码 | 视频加工 | 相册写入 | 总保存 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 / `274FCD38` | Live | 2285.6 | 1022.4 | 173.8 | 1555.4 | 258.0 | 4099.2 |
| 2 / `58138BEC` | Live | 2253.3 | 378.9 | 167.8 | 785.0 | 154.5 | 3193.1 |
| 3 / `7F14A08F` | Live | 2332.9 | 346.3 | 158.3 | 755.1 | 173.4 | 3261.5 |
| 4 / `C3647DCB` | Live | 2306.1 | 339.6 | 153.5 | 757.5 | 183.5 | 3247.3 |
| 5 / `4983958E` | Live | 2305.0 | 361.8 | 158.2 | 766.0 | 172.3 | 3243.6 |
| 6 / `A3AC20B5` | Live | 2308.1 | 346.4 | 158.8 | 763.1 | 182.2 | 3253.6 |
| 7 / `E73CB2BC` | 普通 | 458.4 | 290.5 | 126.9 | — | 104.0 | 854.1 |
| 8 / `6A56F0BD` | 普通 | 477.6 | 300.4 | 135.2 | — | 112.5 | 891.7 |
| 9 / `94F827A2` | 普通 | 479.9 | 289.6 | 128.7 | — | 117.5 | 888.2 |

本轮 Live 首张 4099.2 ms；此前并行 JPEG 首张记录有 3722.3、3972.9、4195.0 ms，
此次仍在历史波动范围内，不能据单张断定 HEIF 放大了冷启动成本。

本轮首张编码 173.8 ms，后续中位数 158.3 ms，相差 15.5 ms；编码前的照片加工为
848.6 ms，后续约 188 ms，视频加工为 1555.4 ms，后续 763.1 ms。首张大段额外等待
仍集中在绘制和视频处理。两者并行，当前基础日志不足以继续定位内部等待的根因。

本轮确认有耗时增加的观察结果，尚不是排除场景、温度、系统调度等因素后的 HEIF 单变量
因果结论；不据此自动调整画质、添加预热或改变编码策略。本次仅分析已有数据并记录结果。


## 2026-09-27 点按对焦退出的验证记录

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

## 2026-09-27 早期延迟方案讨论（部分后续已实现）

> 以下描述优化前状态，只用于保存论证与参考来源。此后 readiness、每拍独立 delegate、
> 阶段计时、一次静态绘制、并行加工和水印均已实现；直存/header 路径已因固定水印移除。
> 其中“尚未实施”“当前未实现”不描述整理后的正式代码。

### 用户反馈与原因边界

用户反馈：已有闪屏反馈后，从拍照到处理、最终进入系统相册仍感觉慢；快门恢复与相册出现
两个环节都明显，普通照片也存在，不限于 Live Photo。后续第一轮验证优先覆盖普通照片。

此前实现优先保证单次拍摄资源完整交付，以及裁切、镜像和输出方向正确，带来两项性能代价：

- 单个拍摄请求占用全局拍摄状态，完整请求结束前不能开始下一张，没有利用采集与处理重叠的能力。
- 保存前进行全尺寸像素重绘；需要最终旋转时再绘制一次，增加自定义处理工作。

这些实现选择确实增加等待或处理工作，但系统采集、计算摄影、编码和 PhotoKit 写入也需要时间。
尚无阶段计时，不能将全部延迟归因于此前决策，或断言某个阶段占据最多耗时。
成片要求本身继续保留，优化重点是状态划分与实现方式。

### 优化前实际链路（当时优化前版本）

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
完整 Live Photo 方案。上述镜像与资源库链接核对日期为 2026-09-27，链接使用其查阅时的默认源码。

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

## 2026-09-28 本地功能验证的证据边界

以下记录是该轮代码检查与构建的历史结果，不是本次文档整理重新执行的验证。
替身检查和 macOS 编码检查不能替代 iOS 相机设备、完整 UIKit 绘制与真机 PhotoKit 验收。

### Live 降级与启动日志

已通过无签名 generic iOS Simulator 的 Debug 与 Release 构建，确认 Release 产物保留日志。
临时 macOS 替身检查运行真实 Controller，以及从当前 Access/Engine 提取的权限流程、启停、
切换、Live 配置与能力发布方法，覆盖权限拒绝/受限、麦克风缺失/创建失败/接入失败、不支持
Live 的前置降级、切回后置恢复、采集中幂等配置、权限请求取消、旧回调失效和输入/设备锁/
启动失败回滚。该检查不会启动相机，
不能替代实际 AVFoundation 输入协商、预览和成片验收。仍需真机验证拒绝麦克风后普通拍照、
支持能力变化后的镜头切换、系统设置授权后重入，以及采集一份 Debug/Release 启动日志。

### HEIF 选择与元数据

已通过无签名 generic iOS Simulator 构建。临时替身依赖检查真实 `CameraController` 的普通/
Live 编码选择、不支持 HEIF 时回退、切换与恢复后能力更新、旧回调失效和每拍独立设置。
另在 macOS 执行真实 `CameraPhotoProcessor` 的 Image I/O 编码路径，验证 HEIF 输入与输出
类型一致、像素可解码、尺寸与方向标签、Live Photo 配对标识、EXIF/GPS 保留及无效输入失败。
该检查替换了 UIKit 绘制，不验证 iOS 水印、镜像或实际相册 Live Photo 播放，也不用于测量
iPhone 编码速度。

### 会话中断与运行时错误恢复

已通过无签名 generic iOS Simulator 构建；另以临时替身依赖执行真实 `CameraController` 的
通知与生命周期检查，覆盖中断结束、媒体服务重置、旧恢复与切换回调失效、保存继续执行、
一般运行时错误和重复恢复错误不会循环重启。该检查不启动摄像头，也不代替 AVFoundation
真机行为验收。用户已完成简单真机试用，反馈未发现问题；电话或设备占用、Live Photo
拍摄中断、媒体服务重置以及暂停后离开页面的实际恢复效果尚未逐项验收。

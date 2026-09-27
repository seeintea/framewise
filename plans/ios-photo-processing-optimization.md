# iOS 图片加工优化：实验结论与实施起点

记录日期：2026-09-27。

本文件从 `codex/camera-latency-validation` 提取继续有价值的事实与方案，用于新的
`codex/photo-processing-optimization` 分支。完整实验代码、逐张统计和讨论过程保留在
实验提交 `2d5894c`；新分支从实验前的 `main`（`d6f6c1b`）开始，不整体移植实验代码。

当前只聚焦必要的照片加工：减少重复绘制与编码，为后续水印留出同一次输出的处理位置。
直出、成片比例异常排查、采集并发和快门 readiness 改造不属于本次范围。
此文档保留实施起点与候选方案；首轮绘制融合已实现，验证状态见第 7 节。水印尚未实现。

## 1. 保留的产品约束

- 后续商业化需要对图片添加水印；带水印成品需要修改像素，不能把纯原始资源直存作为
  覆盖所有正式场景的方案。
- 模板是否必须限定最终比例、横竖方向和裁切范围仍待产品讨论。未改变决策前，图片优化
  先保持当前输出规则，只减少重复加工，不顺带更改模板、预览、镜像或握持方向语义。
- 水印样式、大小、位置、添加时机尚未确定；本次不自行生成水印或商业化流程。
- Live 静态照片与播放视频是否都加水印仍待确定；图片需要水印不自动意味着 MOV 每帧
  都必须加水印。最终配对资源要保持有效。

## 2. 实验中有价值的事实

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
  新分支已经验收通过的正式实现。

## 3. 新分支的实际代码起点

以下以 `d6f6c1b` 的 Swift 代码为准，不引用归档相机的类型或几何方案：

- `PhotoAspectRatio.croppedImage(from:)`：解码照片，在方向归一化后的竖版坐标中计算整数
  比例与居中裁切，使用一个 UIGraphicsImageRenderer 输出图片。
- `PhotoOutputRotation.applied(to:quarterTurns:)`：非零旋转时再创建一个 renderer，得到
  最终图片。普通照片与 Live 静态照片都使用上述两步。
- `CameraPhotoSaver`：普通照片将最终 UIImage 交给 PhotoKit 创建资源，没有应用侧中间
  JPEG 编码。
- `LivePhotoProcessor`：静态照片最终用 ImageIO 编码一次，保留 Live 配对信息；之后处理
  MOV。视频裁切与旋转已经放在同一次 composition 和一次 export 中。
- 没有水印实现，没有实验分支的计时类型、原始直存开关或两张请求 readiness 改造。

## 4. 处理方式与取舍

| 方式 | 做法 | 当前选择方向 |
| --- | --- | --- |
| UIKit / Core Graphics 单次目标绘制 | 在最终大小的画布中组合方向、裁切与旋转；底图绘制结束后，在最终输出坐标画水印。 | 优先考虑，直接复用现有系统框架，普通与 Live 静态图共用。水印未定时先合并已有操作。 |
| 一次最终编码 | 全部像素处理完成后才编码，避免“编码、再解码添加水印、再编码”的往返。 | Live 现有显式编码已是一次；普通照片是否改为同一 ImageIO Data 输出单独评估，不把它与首轮绘制融合强绑。 |
| Core Image 组合处理 | 将裁切、旋转、水印组成一个 CIImage 处理图，最终统一输出。 | 备选绘制实现，性能确有需要时再验证；不叠在 UIKit 后再处理一次，也不预设 GPU 一定更快。 |
| Live 视频一次合成、一次导出 | 将视频方向、裁切与视频水印放在同一 composition，最后只导出一次。 | 仅在视频水印范围确认后研究。本次先保持现有 MOV 处理。 |

照片的目标链路：

```text
源编码数据 → 解码 → 同一次目标绘制：裁切 / 旋转 / 水印 → 最终编码 → PhotoKit
```

这里的“一次”是应用侧一次最终图片生成与一次最终资源编码，不承诺系统内部没有中间
buffer 或处理。Core Image 延迟求值也不等于硬件上必然只有一个 pass。

## 5. 最小实施顺序

1. 先把现有静态照片的裁切和最终旋转融合为一次目标绘制，保留同一尺寸计算、裁切坐标、
   镜像和输出规则；普通照片与 Live 静态照片共用。首轮不加入额外的像素复用快捷分支。
2. 保持现有编码与相册写入路径，分离验证绘制减少的收益；不同时调整画质、拍摄设置、
   采集并发或 MOV 导出。必要计时只围绕此次变更，不整套搬入实验控制。
3. 确定水印样式与范围后，将水印绘制放入同一次画布，使用最终输出坐标，避免水印跟着
   源图的裁切或旋转错误移动。
4. 如后续需要统一普通与 Live 编码，独立核对格式、色彩、方向与配对 metadata，再统一
   最终 Data 写入。视频水印与 Core Image 性能对照另行安排。

实施后运行工程要求的 unsigned generic iOS Simulator build。效果验证对比同一组实际
相机资源的输出与耗时，覆盖有无旋转、不同裁切比例和镜像；构建通过不替代真机输出验证。
本轮不启动模拟器、操作真机，也不继续讨论历史比例异常。

## 6. 参考依据与追溯

- [当前相机架构](ios-camera-architecture-v2.md)：新相机的已确认规则与模块边界。
- [Apple UIGraphicsImageRenderer](https://developer.apple.com/documentation/uikit/uigraphicsimagerenderer)
  与 [UIImage.draw(in:)](https://developer.apple.com/documentation/uikit/uiimage/draw(in:))：在同一
  CGContext 中处理几何变换并绘制图像，UIImage.draw 尊重源方向。
- [SDWebImage 图像变换源码](https://github.com/SDWebImage/SDWebImage/blob/master/SDWebImage/Core/UIImage%2BTransform.m)：
  在 renderer 中通过 CGContext 变换绘制图像的成熟实现参考，不新增依赖。
- [Apple ImageIO 输出](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/ikpg_dest/ikpg_dest.html)：
  编码最终像素并指定资源属性。
- [Apple CIImage](https://developer.apple.com/documentation/coreimage/ciimage)：延迟求值的组合处理图。
- [Apple AVVideoComposition](https://developer.apple.com/documentation/avfoundation/avvideocomposition)
  与 [Core Animation 合成工具](https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool)：
  视频变换与叠加的系统方案。

基础能力覆盖最低 iOS 18，当前 Swift 5 与部署版本不变；新 configuration API 按各自实际
availability 分支使用。上述 API 不代表当前已经完成水印实现。

完整实验记录可从原分支或 `2d5894c` 查看
`plans/ios-camera-architecture-v2.md`；提交之后关于商业化水印和处理方式的讨论已提取到
本文件。原分支未提交的两份文档补充已保存为 stash 对象
`6182bbf10b343360399dccb5fa12d00057a3bcee`，标题为
`camera-latency-validation: output policy and watermark follow-up docs`。
原分支保留不删除，新分支开始实施前的 Swift 与工程配置已确认和 `main` 相同。

## 7. 首轮实施：静态照片一次绘制

`PhotoAspectRatio.renderedImage(from:quarterTurns:)` 现在承担静态照片的方向归一化、
居中裁切和最终旋转。仍按源 `UIImage.imageOrientation` 决定正立宽高，使用原整数比例
计算和居中偏移；最终画布在非零旋转时交换裁切宽高，在同一 CGContext 中先平移、旋转，
再通过 `UIImage.draw(in:)` 绘制源图。源方向与镜像仍由 UIKit 解读，不手工重复变换。

普通照片与 Live 静态照片都调用这一入口，移除不再使用的 `PhotoOutputRotation`。无旋转
照片仍绘制一次，需要旋转的照片从两次绘制减少为一次；没有加入原始像素复用分支。
renderer 保持 `scale = 1` 和已有默认色彩、透明度设置。

普通照片仍将最终 `UIImage` 交给 PhotoKit；Live 静态图仍使用原格式编码一次，保留配对
metadata 并将方向标签设为正立。MOV 裁切、旋转、导出及资源写入路径保持原样。没有添加
水印、采集并发或 readiness 改造，也未建立新实现的真机耗时基线。

验证记录（2026-09-27）：

- 使用本机 Xcode 27.0，保持 Swift 5 与最低 iOS 18。首次执行工程要求的
  `-scheme Framewise` 命令时，checkout 没有该 scheme；直接对现有 target 做 Debug
  无签名 `iphonesimulator` 构建，arm64 与 x86_64 均通过。用户随后新建共享
  `xcshareddata/xcschemes/Framewise.xcscheme`，检查其 target 引用及各 action 配置无误，
  再次使用规定的 scheme 与 `generic/platform=iOS Simulator` 命令构建通过。
- 在 Mac 上直接运行临时 Mac Catalyst UIKit 命令行程序，对照 `d6f6c1b` 的旧两次绘制与
  当前入口。1005 个用例覆盖 JPEG、带 alpha 的 sRGB PNG、8 种 EXIF 方向、5 个比例、
  `-1/0/1` 旋转，以及 `96×128`、`97×131`、`98×130` 和 `1×1` 源尺寸与无效数据。
  768 个有效输出的尺寸、正立方向与 `scale = 1` 检查通过；192 个过小源图用例的新旧
  nil 行为一致，45 个无效输入用例均被拒绝。
- 有效输出统一转为 sRGB RGBA8 后，640 组逐像素一致；128 组在 `97×131` 的半像素
  居中裁切且非零旋转时存在最大 `1/255` 通道差异。差异与采样或取整舍入相符，未发现
  几何偏移；不承诺融合后逐字节相同。临时脚本和差异表保存在
  `/private/tmp/framewise-render-regression/`，未加入应用 target。

以上不覆盖 HEIF、广色域或 HDR，也不替代 iOS 真机成片、Live 配对播放与 PhotoKit 写入
验收。未启动模拟器、安装应用或操作真机，具体耗时收益仍待同组实际相机资源对比。

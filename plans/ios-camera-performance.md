# iOS 相机性能与感知延迟

> 状态：问题记录与方案讨论，尚未进入实现。
>
> 创建时间：2026-09-14。
>
> 范围：原生 iOS 相机的启动、快门响应、照片处理与相册保存。本文不改变
> `plans/ios-camera-module-phase-1.md` 的当前 M6 验收顺序。

## 1. 问题背景

2026-09-14 真机验证中观察到两类明显等待：

1. 从进入 Camera 页面到相机可拍摄需要一定时间。
2. 按下快门后，从捕获、裁切到保存完成需要一定时间，Live Photo 更明显。

目前只有体感结论，尚无分阶段耗时数据。因此暂不直接判断瓶颈属于 AVFoundation
启动、系统计算摄影、Framewise 输出处理还是 PhotoKit 保存，也暂不为了追求速度降低
照片质量。

需要分别看待：

- **实际延迟**：底层完成某个阶段所需的真实时间。
- **感知延迟**：用户在这段时间内是否看到可理解的反馈，是否还能继续取景或拍摄。

优化目标不是让所有后台工作同时结束，而是让预览尽快可见、快门反馈及时，并尽可能
避免输出处理和相册保存阻塞下一次拍摄。

## 2. 当前实现链路

### 2.1 启动

```text
CameraView 创建 CameraModel
  → 检查或请求相机权限
  → 创建并配置 AVCaptureSession、视频输入与 AVCapturePhotoOutput
  → 根据 Live Photo 偏好检查麦克风权限
  → 配置音频输入与 Live Photo capture pipeline
  → startRunning
  → 页面进入 ready
```

当前每次重新进入 Camera 都会创建新的 `CameraModel` 和 capture service。退出时停止
session，重新进入时重新走配置流程。Live Photo 默认开启时，首轮启动还包含麦克风
权限和音频管线配置。

### 2.2 普通照片

```text
点击快门
  → AVCapturePhotoOutput 捕获并完成系统处理
  → 获取完整照片数据
  → Core Image 解码、方向归一化和模板比例裁切
  → ImageIO 重新编码
  → PhotoKit 写入系统相册
  → 页面恢复 ready
```

当前快门锁一直保持到输出处理和 PhotoKit 保存全部结束。即使传感器已经完成捕获，用户
仍会处于“拍摄中”或“保存中”，不能立即开始下一次拍摄。

### 2.3 Live Photo

```text
点击快门
  → 等待静态照片与 paired movie 都完成
  → 裁切并重新编码静态照片
  → AVAssetExportSession 裁切并重新编码 paired movie
  → PhotoKit 将 photo 与 pairedVideo 写成同一个资源
  → 页面恢复 ready
```

Live Photo 比普通照片多一次完整视频导出，预计是拍摄后等待的重要来源，但需要数据
确认。

## 3. Apple 公开的低延迟机制

系统 Camera App 的完整实现没有公开，不能假设其私有架构细节。Apple 公开的
AVFoundation 能力体现了以下设计方向：

### 3.1 启动阶段

- 优先建立并显示预览，延后准备非关键照片或视频输出。
- iOS 26 支持 deferred output start；支持时可以先启动预览，再准备照片输出。
- 不依赖 capture output 的控件可以稍后淡入，避免用户看到不能操作的按钮。

### 3.2 快门阶段

- Zero Shutter Lag 使用滚动帧缓冲区，选择更接近用户按下快门时刻的帧。
- Responsive Capture 允许上一张进入处理或编码阶段后，下一张开始捕获。
- Fast Capture Prioritization 在短时间连续拍摄时动态平衡画质和 shot-to-shot 时间。
- `AVCapturePhotoOutputReadinessCoordinator` 提供底层真实 readiness，UI 不需要以
  “是否已经保存到相册”作为快门可用性的唯一条件。
- `setPreparedPhotoSettingsArray` 可以提前准备将要使用的照片设置，减少按快门后临时
  分配资源的情况。

### 3.3 后处理阶段

- Deferred Photo Processing 可以先把轻处理 proxy 写入 PhotoKit，稍后由系统生成最终
  高质量照片。
- Framewise 当前会修改照片像素以完成模板比例裁切。Apple 明确说明，对 proxy 像素的
  修改不会自动进入稍后生成的最终照片，因此这一能力不能直接接入，除非重新设计为
  PhotoKit adjustment 工作流。

官方资料：

- [Create a more responsive camera experience](https://developer.apple.com/videos/play/wwdc2023/10105/)
- [Building a responsive camera app that launches quickly](https://developer.apple.com/documentation/avfoundation/building-a-responsive-camera-app-that-launches-quickly)
- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [AVCapturePhotoOutputReadinessCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturephotooutputreadinesscoordinator)
- [Preparing photo settings](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/setpreparedphotosettingsarray(_:completionhandler:))
- [Photo quality prioritization](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/photoqualityprioritization)

## 4. 先测量再优化

在决定实现前，为每次启动和拍摄记录同一单调时钟下的阶段时间。第一版只需开发日志或
OSLog signpost，不上传用户数据。

### 4.1 启动指标

| 指标 | 起点 | 终点 |
| --- | --- | --- |
| 权限耗时 | Camera 页面出现 | 所需权限状态确定 |
| session 配置耗时 | 开始 configure | commitConfiguration 完成 |
| Live 配置耗时 | 开始准备 Live Photo | 音频与 Live 状态确定 |
| session 启动耗时 | 调用 startRunning | startRunning 返回 |
| 首帧耗时 | Camera 页面出现 | 预览层收到第一帧并可见 |
| 可拍摄耗时 | Camera 页面出现 | 快门真实 ready |

需要区分首次授权、冷启动、退出后重进和后台恢复，不能把系统权限弹窗时间当作相机管线
性能。

### 4.2 拍摄指标

| 指标 | 起点 | 终点 |
| --- | --- | --- |
| 快门响应 | 用户触摸快门 | `willCapturePhoto` / 快门动画开始 |
| 传感器捕获 | 用户触摸快门 | `didCapturePhoto` |
| 系统照片处理 | `didCapturePhoto` | `didFinishProcessingPhoto` |
| Live movie 完成 | 用户触摸快门 | paired movie delegate 完成 |
| 静态输出处理 | 开始裁切 | 照片重新编码完成 |
| Live 视频处理 | 开始导出 | paired movie 导出完成 |
| 相册保存 | PhotoKit 请求开始 | performChanges 完成 |
| 总耗时 | 用户触摸快门 | 当前保存成功反馈 |
| 连拍间隔 | 第一次触摸快门 | 下一次快门真实可用 |

测试至少区分普通照片、Live Photo、闪光灯、前后摄和 `3:4` / `4:3` 输出。

## 5. 可讨论的底层优化方向

以下方向互不等价，需要在测量后按瓶颈选择：

### 5.1 启动优化

1. 让预览首帧成为独立状态，不等待所有照片能力准备完才移除启动遮罩。
2. 合并首次 session 与 Live Photo 配置，减少重复 `commitConfiguration`。
3. 离开 Camera 后停止 session，但在合适的上层保留已配置的 capture service，优化短时间
   内重新进入；同时确保不继续占用摄像头。
4. 评估 iOS 26 的 deferred output start，让预览优先于照片输出完成启动。
5. 评估 Live Photo 默认开启对首次启动、麦克风权限和音频输入准备的影响。

### 5.2 捕获优化

1. 显式检查和记录 Zero Shutter Lag、Responsive Capture 与 Fast Capture
   Prioritization 的设备支持状态。
2. 使用 readiness coordinator 控制快门，而不是让单个 capture task 覆盖捕获、处理和
   保存的全部生命周期。
3. 为普通、Live、闪光灯等代表性设置预热资源，并测量预热的收益和内存成本。
4. 保持默认 `balanced` 作为质量基线；只有数据证明必要时，才为连续拍摄或用户选项启用
   `speed` / Fast Capture Prioritization。
5. 支持多项 in-flight capture 前，必须先让 delegate、状态和错误处理能够安全处理回调
   交错。

### 5.3 输出与保存优化

1. 把“画面已捕获”“输出已生成”“相册已保存”拆成不同状态。
2. 传感器捕获结束并且底层 readiness 恢复后允许下一次拍摄；裁切和保存进入有上限的后台
   队列。
3. 分别测量 Core Image 渲染、ImageIO 编码和 PhotoKit，不把它们作为一个黑盒。
4. 评估直接使用 Core Image 的 HEIF 写出路径，避免不必要的完整中间 `CGImage`，但必须
   验证 EXIF、色彩空间、方向和 Live Photo asset identifier。
5. 优先减少 Live Photo paired movie 的重编码成本；如果无法避免，则让视频导出不阻塞
   快门 UI，并限制同时存在的处理任务数量。

## 6. UI 感知延迟缓解

UI 只能缓解感知等待，不能掩盖失败、假成功或不可恢复的阻塞。建议按真实阶段给出反馈：

### 6.1 启动

- Camera 页面立即显示稳定的黑色或上一帧过渡层，第一帧到达后快速淡出。
- 预览可见后再淡入倍率、镜头切换和其他依赖 session 的控件，避免整页等待。
- 快门可以提前显示，但必须根据真实 readiness 禁用或降低强调度。
- 冷启动、权限等待和恢复中断使用不同文案；权限弹窗不表现为相机性能问题。

### 6.2 按快门

- 在 `willCapturePhoto` 时立即播放快门视觉反馈，不等照片处理或相册保存。
- 使用短暂屏幕闪白、快门缩放或触觉反馈明确表示“已经捕获”。
- 普通照片不使用覆盖整个预览的长时间 loading；保存状态放在缩略图或轻量提示上。
- 底层 readiness 恢复后快门立即恢复，不等待缩略图和 PhotoKit 全部结束。

### 6.3 处理与保存

- 左下角相册入口后续可承担处理状态：临时缩略图、环形进度、成功或失败标记。
- 多张照片后台排队时显示数量或状态，但不阻挡继续取景。
- Live Photo 可以明确显示“正在处理实况照片”，同时允许用户继续调整取景；是否允许下一次
  拍摄由内存、队列上限和 readiness 共同决定。
- 只有 PhotoKit 确认成功后才显示“已保存”；失败必须保留可理解提示和重试路径。

## 7. 决策顺序

建议后续按以下顺序推进：

1. 增加阶段计时，不改变相机行为。
2. 用真机记录冷启动、重进、普通照片和 Live Photo 的基线。
3. 先拆分捕获反馈与后台保存状态，验证 UI 是否已经显著改善体感。
4. 再根据数据选择启动预热、Responsive Capture、设置预热或编码优化。
5. 完成连续拍摄、后台队列、内存压力和失败恢复验收后，才把优化视为完成。

当前不决定：

- 是否以照片质量换取速度。
- 是否默认启用 Fast Capture Prioritization。
- 是否跨页面保留 capture service。
- 是否改变 Live Photo 默认开关。
- 是否引入 Deferred Photo Processing 或 PhotoKit adjustment。

这些选择必须由阶段耗时、成片质量和真机稳定性共同决定。

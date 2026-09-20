# [归档] iOS 相机性能与感知延迟

> [!WARNING]
> 本文的链路、指标埋点、真机数据和优化结论对应 2026-09-20 已归档的旧相机实现。
> 旧代码保存在
> [`archive/ios-camera-legacy-2026-09-20/`](../archive/ios-camera-legacy-2026-09-20/README.md)。
> 新相机不得把本文描述的类型、状态或性能瓶颈当作当前事实；需要重新建立基线。

> 归档前状态：阶段计时与首轮真机基线已完成；2026-09-19 已完成第一阶段反馈层改造，
> 当前等待真机验收，尚未开始第二阶段的状态拆分与后台保存。
>
> 创建时间：2026-09-14。
>
> 最近更新：2026-09-19。
>
> 范围：原生 iOS 相机的启动、快门响应、照片处理与相册保存。本文不改变
> 归档文档 `plans/ios-camera-module-phase-1.md` 中 M6 已完成的历史状态。

## 1. 问题背景

2026-09-14 真机验证中观察到两类明显等待：

1. 从进入 Camera 页面到相机可拍摄需要一定时间。
2. 按下快门后，从捕获、裁切到保存完成需要一定时间，Live Photo 更明显。

阶段计时接入前只有体感结论，无法判断瓶颈属于 AVFoundation 启动、系统计算摄影、
Framewise 输出处理还是 PhotoKit 保存。2026-09-15 已完成首轮真机采样，结果记录在
4.3；当前仍不为了追求速度降低照片质量。

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

### 4.0 当前实现

2026-09-15 已接入基于 `ContinuousClock` 与统一日志的阶段计时，不改变 capture session
配置和现有拍摄状态流。日志 subsystem 为 `com.leviegu.framewise`，category 为
`CameraPerformance`，每条记录均以 `camera_metric` 开头。

启动阶段当前记录：

- `camera_authorization`
- `session_configuration`
- `microphone_authorization`
- `live_photo_configuration`
- `session_start`
- `camera_ready`

拍摄阶段当前记录：

- `shutter_response`
- `sensor_capture`
- `system_photo_processing`
- `live_movie_capture`
- `capture_delegate_total`
- `photo_crop_and_encode`
- `live_movie_crop_and_export`
- `output_processing_total`
- `photo_library_authorization`
- `photo_library_save`
- `photo_library_total`
- `capture_pipeline_total`

同一次拍摄通过 `operation_id` 关联，并记录 `capture_kind`、`outcome` 与毫秒耗时；日志
不包含照片数据、文件路径或错误详情。可在 Xcode 控制台或 Console.app 中按
`camera_metric` 过滤。

当前保留 `CameraPerformance` 与全部 `camera_metric` 埋点，用于后续 UI / 状态拆分前后的
同口径真机对比。完成复测并确认最终方案后再移除这些临时 logger；本轮不提前删除，也不把
它们扩展为长期分析或数据上传能力。

首帧时间尚未记录。`AVCaptureVideoPreviewLayer` 不提供可靠的首帧回调；为了不通过新增
`AVCaptureVideoDataOutput` 改变待测管线，第一轮基线先使用 `session_start` 与
`camera_ready`，首帧测量留到后续采用不会污染结果的方案。

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

### 4.3 2026-09-15 首轮真机基线

本轮包含 5 次相机启动、5 张普通照片和 3 张 Live Photo。启动样本由首次进入和 4 次
退出重进组成；拍摄指标使用中位数（P50），毫秒值四舍五入。样本量只用于确定下一步
方向，不作为跨设备性能承诺，也不计算 P95。

启动结果：

| 指标 | 首次进入 | 重进 P50 | 结论 |
| --- | ---: | ---: | --- |
| `camera_ready` | 527 ms | 298 ms | 当前不是主要体感瓶颈 |
| `session_start` | 466 ms | 275 ms | 占启动时间的大部分 |
| `session_configuration` | 39 ms | 20 ms | 优化空间有限 |
| `live_photo_configuration` | 21 ms | 3 ms | 优化空间有限 |

普通照片结果：

| 指标 | P50 |
| --- | ---: |
| `shutter_response` | 36 ms |
| `sensor_capture` | 241 ms |
| `system_photo_processing` | 379 ms |
| `capture_delegate_total` | 621 ms |
| `photo_crop_and_encode` | 115 ms |
| `photo_library_total` | 100 ms |
| `capture_pipeline_total` | 845 ms |

普通照片的快门响应已经及时。当前 UI 会等待完整管线才恢复；若在 capture delegate 完成且
底层 readiness 恢复后释放拍摄状态，把裁切与 PhotoKit 保存移入受限后台队列，典型锁定
时间可从约 845 ms 降至约 621 ms，理论减少约 215 ms（约 25%）。这只减少用户等待和
连拍阻塞，不缩短照片最终保存完成的真实时间。

Live Photo 结果：

| 指标 | P50 |
| --- | ---: |
| `shutter_response` | 52 ms |
| `sensor_capture` | 251 ms |
| `system_photo_processing` | 439 ms |
| `live_movie_capture` | 2,199 ms |
| `capture_delegate_total` | 2,199 ms |
| `photo_crop_and_encode` | 120 ms |
| `live_movie_crop_and_export` | 330 ms |
| `output_processing_total` | 451 ms |
| `photo_library_total` | 123 ms |
| `capture_pipeline_total` | 2,855 ms |

Live Photo 的主要耗时是约 2.2 秒的系统 paired movie 捕获，不能在不改变产品语义的前提下
直接消除。状态拆分可把典型锁定时间从约 2.86 秒降至约 2.2 秒，理论减少约 575 ms
（约 20%）；后台仍需继续完成视频导出与相册保存。

首张普通照片的裁切编码为 164 ms、PhotoKit 保存为 300 ms，随后分别稳定在约
113～115 ms 和 86～103 ms。首张 Live Photo 的视频导出为 1,023 ms，随后两张约为
327～330 ms。首笔冷路径存在预热空间，但只影响首张；当前不为此引入额外预热、内存占用
或生命周期复杂度。

控制台中的 PointerUI、Fig 和 `cannot add handler` 信息未与失败样本关联，不计入相机
性能结论。`glassEffect() tried to update multiple times per frame` 属于 UI 更新警告，留在
后续 UI 阶段定位。

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

### 6.0 改造前交互审计

当前 `CameraView` 直接根据 `CameraModel.state` 选择反馈，正常操作和真正需要阻断的状态尚未
完全分开：

| 用户操作或状态 | 当前反馈 | 主要问题 |
| --- | --- | --- |
| 首次授权、启动相机 | 全屏半透明状态面板 | 权限和冷启动需要阻断，形式基本合理 |
| 开关 Live Photo | 进入 `configuring`，复用“正在启动相机” | 文案与操作不匹配，并且正常切换过度打断预览 |
| 切换前后摄像头 | 进入 `configuring`，显示全屏启动状态 | 预览切换被表现为重新启动整个相机 |
| 普通照片或 Live Photo 捕获 | 底部 loading 胶囊 | 快门已经有及时响应，但 UI 仍持续强调等待 |
| 输出处理与 PhotoKit 保存 | 底部“正在保存到相册” | 后台工作阻断了正常取景体验 |
| 保存成功 | 中央确认面板显示 1.5 秒 | 普通成功路径反馈过重，遮挡取景 |
| 权限拒绝、中断、不可用和失败 | 全屏状态或错误提示 | 这类状态仍需要清楚、可操作的阻断反馈 |

第一轮改造遵守以下原则：

1. 正常成功路径不使用全屏遮罩或持续 loading。
2. 快门反馈表达“已经收到并开始捕获”，不能提前表达“已经保存成功”。
3. 捕获、输出处理和相册保存是三个不同阶段，UI 不再把它们压成一个等待状态。
4. 权限、首次启动、中断、不可用和不可恢复失败继续使用明确的阻断状态。
5. 视觉反馈与真实拍摄能力分离；隐藏 loading 不代表底层已经支持连续拍摄。

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

### 6.4 Live Photo 与摄像头切换

- Live Photo 按钮先即时更新图标，再使用 `Core/UI/StatusBadge` 短暂显示“实况”或
  “关闭实况”；正常切换不显示 loading。
- 首次启用 Live Photo 时仍按需要请求麦克风权限。系统权限等待可以阻断操作，但不能复用
  “正在启动相机”文案。
- Live Photo 配置失败时恢复按钮真实状态，并显示具体降级或权限提示，不能只让胶囊消失。
- 切换前后摄像头时保持页面结构稳定，可使用预览淡入淡出或短暂冻结；只有真正失败时才进入
  全屏错误状态。
- 快速重复点击期间禁用会产生配置冲突的按钮，但不额外展示全屏 loading。

### 6.5 轻量提示的并存规则

相机页顶部已经可能显示模板方向提示，后续 Live Photo 等操作也会使用同一区域。不能让多个
`StatusBadge` 重叠：

1. 错误或降级提示优先级最高，并保留到用户处理或主动关闭。
2. “实况”与“关闭实况”等操作确认短暂覆盖方向提示，建议显示约 1 秒。
3. 操作确认消失后，如果模板方向仍不匹配，恢复“请旋转手机”。
4. 同一时刻最多显示一个顶部状态标签；连续操作更新当前标签，不堆叠动画。
5. 标签旋转方向必须与相机控件一致，并支持 Reduce Motion、VoiceOver 和 Dynamic Type。

## 7. 分阶段实施与验收

### 7.1 第一阶段：只优化反馈层

实施状态：已于 2026-09-19 完成代码改造与 iOS Simulator 通用目标编译，待真机验收。
本阶段没有改变单个 `captureTask`、捕获处理顺序或相册保存边界。

第一阶段保持现有单个 `captureTask` 和拍摄期间的互斥约束，不承诺后台保存期间可以继续按
快门。目标是先移除正常路径中过重且文案不准确的反馈：

1. 为相机页增加独立于生命周期状态的瞬时提示状态，用于 Live Photo 开关等操作确认。
2. Live Photo 开关使用黄色与浅色 `StatusBadge`，不再复用相机启动面板。
3. 快门接入按压、捕获瞬间视觉反馈和适度触觉反馈。
4. 移除普通拍摄与保存成功路径中的持续 loading 和中央成功面板。
5. 保存失败继续提供可理解的错误信息；不得因为移除成功反馈而吞掉失败。
6. 切换摄像头改为预览局部过渡，不再显示“正在启动相机”。

第一阶段验收：

- 普通照片和 Live Photo 的正常成功路径不出现全屏 loading。
- Live Photo 开关状态、提示文案与真实配置结果一致。
- 快门被暂时禁用时仍有明确的按压与捕获反馈，不产生“点击无反应”的感觉。
- 相册写入失败、权限拒绝、相机中断和配置失败仍能被用户发现并恢复。
- 顶部操作提示和模板方向提示遵守单提示优先级，不重叠、不被预览裁掉。
- Reduce Motion 开启时不依赖大幅缩放或闪烁表达状态。

### 7.2 第二阶段：拆分捕获与后台保存

只有第一阶段完成真机复测后，再改变底层状态和并发边界：

1. 将 session 生命周期、底层 capture readiness、输出处理和 PhotoKit 保存拆成独立状态。
2. 在底层 readiness 恢复后释放快门，不再等待裁切、编码和 PhotoKit 完成。
3. 为后台处理建立有上限的队列，并明确内存压力、取消、页面退出和失败恢复行为。
4. 相册入口显示临时缩略图、处理中状态和失败标记，取代全局保存弹窗。
5. 评估并接入 `AVCapturePhotoOutputReadinessCoordinator`；支持多项 in-flight capture 前，
   必须先保证 delegate 和 operation ID 能正确处理回调交错。

第二阶段验收：

- 普通照片下一次可拍时间不再被 Core Image、ImageIO 或 PhotoKit 保存串行阻塞。
- Live Photo 捕获期间不虚假开放快门；paired movie 完成后的处理可以转入后台队列。
- 快速连续拍摄不会覆盖状态、错配 Live Photo 资源、丢失失败或无限积压任务。
- 离开页面、进入后台、相机中断和内存压力下均能安全完成或取消队列任务。
- 使用第 4 节同一组 `camera_metric` 重新采集真机数据，并与 2026-09-15 基线比较。

## 8. 决策顺序

建议后续按以下顺序推进：

1. ~~增加阶段计时，不改变相机行为。~~ 已于 2026-09-15 完成。
2. ~~用真机记录冷启动、重进、普通照片和 Live Photo 的基线。~~ 首轮基线已于
   2026-09-15 完成。
3. ~~先实施 7.1 的反馈层优化，不改变 capture task 和后台队列边界。~~ 已于
   2026-09-19 完成代码改造，等待真机验收。
4. 使用真机验证快门、Live Photo、摄像头切换、失败反馈和提示优先级。
5. 只有第一阶段仍存在明显锁定感时，再实施 7.2 的状态拆分与后台保存。
6. 状态拆分后使用同一指标重新测量；只有数据仍显示不可接受的真实延迟时，再选择启动预热、
   Responsive Capture、设置预热或编码优化。
7. 完成连续拍摄、后台队列、内存压力和失败恢复验收后，才把优化视为完成。
8. 最终方案完成并取得对比数据后，移除临时 `CameraPerformance` logger 和调用点；除非届时
   出现明确的长期本地诊断需求。

2026-09-15 决策：当前启动与快门响应已经足够快，普通照片和 Live Photo 均有约 20%～25%
的锁定时间来自 Framewise 输出处理与 PhotoKit 保存。下一步选择 UI / 状态拆分，不继续
死磕底层耗时；具体实现留到后续单独推进。

2026-09-19 决策：先以非阻断反馈改善普通拍照、Live Photo 开关和摄像头切换体验；第一阶段
不提前开放连续拍摄。只有真机复测证明保存锁仍明显影响使用时，才拆分 capture readiness、
输出处理和 PhotoKit 保存。

当前不决定：

- 是否以照片质量换取速度。
- 是否默认启用 Fast Capture Prioritization。
- 是否跨页面保留 capture service。
- 是否改变 Live Photo 默认开关。
- 是否引入 Deferred Photo Processing 或 PhotoKit adjustment。

这些选择必须由阶段耗时、成片质量和真机稳定性共同决定。

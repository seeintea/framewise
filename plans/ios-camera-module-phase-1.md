# iOS 相机模块第一阶段

> 状态：M0～M5 已实现，进入 M6 稳定性与真机验收。
>
> 最近更新：2026-09-14。当前实现状态以
> `ios/Framewise/Core/Camera/` 与 `ios/Framewise/Features/Camera/` 为准。
>
> 基线：以当前 Xcode 工程配置为准，最低支持 iOS 18.0；使用 Xcode 26 构建。
>
> 关系：本计划承接 [iOS 单模板相机链路](./ios-single-template-camera-flow.md)，只实现相机能力，不继续打磨当前 Camera UI。

## 1. 阶段目标

在现有“模板 ID → Camera → `CompositionCanvas`”链路上接入真实 iOS 相机，完成最小但可靠的拍摄闭环：

```text
进入单模板 Camera
  → 请求权限并启动真实预览
  → 根据设备能力调整镜头、倍率、闪光灯与焦点
  → 按当前模板视口拍摄普通照片或 Live Photo
  → 保存到系统相册
  → 留在 Camera 继续拍摄或返回
```

这一阶段以功能正确、状态可靠和真机可验证为目标。控件先沿用现有布局，只补充完成流程所需的最低限度状态反馈，不做视觉细节打磨。

## 1.1 当前实施记录

截至 2026-09-14，M0～M5 的代码链路已经完成，并经过多轮 iPhone 真机分段验证：

- 相机、麦克风与相册 add-only 权限，以及拒绝、限制和设置入口状态已接入。
- 真实预览、前后台生命周期、中断与 media services reset 恢复已接入。
- 普通照片和带声音 Live Photo 可以捕获、处理并保存到系统相册。
- 前后摄切换、真实倍率档位、静态照片闪光灯和 Live Photo 开关已接入设备能力。
- 点击对焦与测光、曝光补偿和对焦位置反馈已接入。
- 预览、Canvas、点击坐标和输出裁切使用同一模板视口；普通照片与 Live Photo 配对 movie 共用输出比例与方向处理。
- `3:4` 与 `4:3` 模板已经完成真机拍摄验证。模板
  `5aa983db-8730-4307-b18f-88ffe4735206` 的输出已确认保存为正确的横向 `4:3`。
- 通用 iOS Simulator destination 构建通过；裁切矩形纯几何检查通过。

横拍专用交互暂不继续：曾尝试根据物理方向旋转取景与控件，随后已撤销。当前保持现有页面方向与布局，横向模板在竖屏页面中显示居中的横向取景矩形，但最终输出仍按模板的 `4:3` 比例保存。后续只有在重新确认横拍交互方案后再实现，不作为当前 M6 的阻塞项。

尚未完成的工作：

1. M6 系统稳定性验收：连续拍摄、快速点击、反复进入退出、前后台切换、系统中断、权限恢复和 Live Photo 失败清理。
2. 补齐 `1:1`、`16:9`、前置镜像、横竖方向和 Live Photo 静态/动态边界的真机矩阵。
3. 使用至少一台不同镜头组合的 iPhone 验证倍率枚举和降级行为。
4. 相册入口仍为禁用占位；最近照片缩略图或系统照片选择器留作后续 V1 打磨。
5. 当前只有真实倍率按钮，尚未实现双指连续缩放。
6. `CameraTemplateRequest` 已保留多个模板 ID 契约，但相机内左右切换模板尚未实现。
7. 工程尚无测试 target；状态转换、倍率过滤和裁切几何还未形成可持续运行的正式测试。

## 2. 已确认的产品与平台边界

- 最低系统版本是 iOS 18.0，不使用 iOS 19～26 专属 API 作为基础能力。
- 支持普通静态照片和 Live Photo，不实现独立的视频录制模式。
- Live Photo 包含声音，因此仅在启用 Live Photo 时使用麦克风输入和权限；麦克风不可用时降级为普通照片。
- 当前只处理一个已解析的模板；不实现多模板左右滑动。
- 模板数据和 `CompositionCanvas` 不依赖 AVFoundation。
- 构图线与 annotation 只叠加在预览上，不写入最终照片。
- 相机控件必须反映当前设备的真实能力；不支持的倍率、闪光灯或镜头不伪造。
- 模拟器只要求不崩溃并显示“相机不可用”状态，最终行为必须使用真机验收。

## 3. 本期必须实现

### 3.1 权限

- 在首次进入 Camera 时检查并请求相机权限。
- Live Photo 开启时检查并请求麦克风权限；用户拒绝后仍可继续拍普通照片。
- 保存照片只申请 PhotoKit 的 `addOnly` 权限，不提前申请读取整个相册的权限。
- 相机、麦克风和相册写入权限按实际需要顺序处理，避免同时出现多个系统弹窗。
- 对未决定、已授权、已拒绝、受限制四种状态给出明确页面状态。
- 权限被拒绝后提供前往系统设置的入口。
- 在 Info.plist 及本地化资源中补充相机、麦克风和相册写入用途说明。

### 3.2 相机会话与真实预览

- 使用 `AVCaptureSession`、`AVCaptureDeviceInput` 和 `AVCapturePhotoOutput` 建立照片会话。
- Live Photo 可用时为同一 session 增加默认音频输入；不增加 `AVCaptureMovieFileOutput`。
- 默认选择设备可用的后置逻辑多摄相机；不可用时回退到后置广角相机。
- 使用 `AVCaptureVideoPreviewLayer` 承载实时预览，并通过轻量 UIKit bridge 嵌入 SwiftUI。
- 预览使用 aspect fill，填满当前模板定义的相机视口。
- 会话配置、启动、停止和设备切换不能阻塞 MainActor。
- Camera 出现时启动；离开页面或应用进入后台时停止；回到前台时按状态恢复。
- 监听会话中断、恢复和 runtime error，避免黑屏后只能重启应用。

### 3.3 设备能力与相机控制

- 后置与前置摄像头切换；只有真实存在的方向才能切换。
- 当前闪光灯按钮控制静态照片的 flash mode，不把 torch 当作闪光灯。
- 增加 Live Photo 开关；只在 `AVCapturePhotoOutput` 报告支持且麦克风可用时启用。
- Live Photo capture pipeline 必须在 session 启动前完成配置，避免用户切换时反复冻结预览。
- 前置相机或当前设备不支持闪光灯时，按钮禁用或隐藏，并把状态恢复为关闭。
- 从当前 `AVCaptureDevice` 的可用范围和虚拟镜头切换信息生成倍率选项。
- 现有 `0.5× / 1× / 2×` 只是 UI 候选值：仅展示和启用设备实际支持的档位，不硬编码所有设备都有三档。
- 切换镜头后重新发布能力、当前倍率和闪光灯状态。
- 支持点击预览区域进行自动对焦与测光，并显示简单的对焦位置反馈。
- 支持设备能力范围内的曝光补偿；第一版可使用最简单的临时控件，不在本期打磨样式。

### 3.4 普通照片、Live Photo 与保存

- 快门只在会话 ready 时可用。
- 使用 `AVCapturePhotoOutput` 获取完整照片数据，不能使用预览截图作为成片。
- 普通照片与 Live Photo 共用一个 `AVCapturePhotoOutput`；每次拍摄通过 `AVCapturePhotoSettings` 决定是否提供 `livePhotoMovieFileURL`。
- Live Photo 捕获必须同时等待静态照片和配对 movie 的 delegate 结果，不能在静态帧返回时提前报告成功。
- Live Photo 拍摄期间显示最低限度的 Live 状态，直到配对 movie 完成。
- 配对 movie 使用当前 capture 的唯一临时文件 URL；无论成功、失败或取消都清理残留文件。
- 拍摄期间锁定快门以及会修改 session 的操作，避免重复拍摄或切换冲突。
- 正确处理设备方向、预览方向和照片输出方向。
- 前置相机的预览镜像与成片映射必须使用同一个明确规则。
- 按模板预览视口的比例和 aspect-fill 裁切规则生成最终照片。
- Live Photo 的静态图与配对 movie 必须使用同一裁切、旋转和镜像规则，并保留匹配的 asset identifier 与 photo display time。
- 使用 PhotoKit 把普通照片保存为照片资源；把 Live Photo 的静态图和 movie 作为 `.photo` 与 `.pairedVideo` 在同一个 asset creation request 中保存。
- PhotoKit 成功接管配对 movie 后使用 move 语义，避免不必要的大文件复制。
- 区分捕获失败、图像处理失败和相册保存失败，并允许用户恢复后再次拍摄。
- 保存成功后留在 Camera 页面，支持连续拍摄。

### 3.5 模板、预览与成片一致性

模板比例不能只影响黄色引导线，还必须参与预览和输出裁切。当前实现遵守以下不变量：

1. 相机预览层、`CompositionCanvas` 和点击对焦区域共用同一个可见矩形。
2. 模板仍使用自身的归一化坐标；AVFoundation 坐标转换集中在 Camera 层完成。
3. aspect fill 从传感器画面裁掉的区域，也必须从最终照片裁掉。
4. `1:1`、`3:4`、`4:3` 和 `16:9` 都按当前页面真正显示出的预览矩形计算成片比例，不各自维护特殊分支。
5. 旋转和前置镜像只计算一次，再同时用于预览、对焦点转换和成片处理。
6. annotation 的三秒显示与手动开关保持现有行为，并且永远不进入照片输出。
7. Live Photo 的静态图与配对 movie 必须保持相同可见内容；不能只裁静态图而让按压播放时画面跳变。

首轮可以采用居中 aspect-fill 裁切；暂不加入用户可移动的裁切区域。

## 4. 模块边界

建议只建立当前已出现的两层，不增加 coordinator、repository 或跨平台抽象：

```text
ios/Framewise/
├── Core/Camera/
│   ├── CameraCaptureService.swift
│   ├── CameraCapabilities.swift
│   ├── CameraCaptureResult.swift
│   ├── LivePhotoProcessor.swift
│   └── CameraError.swift
└── Features/Camera/
    ├── CameraModel.swift
    ├── CameraPreview.swift
    ├── PhotoLibraryWriter.swift
    └── 现有 Camera View 与 Controls
```

职责如下：

- `CameraCaptureService` 使用 actor 隔离 AVFoundation session、输入、输出、拍照 delegate 与硬件配置。
- `CameraCapabilities` 只表达 UI 需要知道的镜头方向、倍率范围、可选倍率、闪光灯和曝光范围，不向 View 暴露 `AVCaptureDevice`。
- `CameraCaptureResult` 区分普通照片与 Live Photo，返回照片数据、可选配对 movie URL，以及输出方向、尺寸、镜头和倍率等处理所需信息。
- `LivePhotoProcessor` 负责对静态图和配对 movie 应用同一输出变换，并保持两项资源的 Live Photo 关联元数据。
- `CameraModel` 位于 MainActor，维护页面状态，把用户操作转换成异步相机命令。
- `CameraPreview` 只负责把 capture session 显示到模板视口，并上报预览坐标转换所需信息。
- `PhotoLibraryWriter` 先作为 Camera feature 的小型实现存在；出现第二个使用方后再迁移为独立领域模块。
- `CameraView` 继续负责布局和 `CompositionCanvas` 叠加，不直接配置 AVFoundation 对象。

## 5. 页面状态

Camera 页面至少明确表达以下状态：

| 状态 | 行为 |
| --- | --- |
| `idle` | 尚未开始授权或配置 |
| `requestingAuthorization` | 等待系统授权，禁用拍摄控件 |
| `configuring` | 正在配置或启动 session，禁用快门 |
| `ready` | 显示实时预览并允许拍摄 |
| `capturing` | 已触发快门；Live Photo 需要等待静态图和配对 movie 都完成 |
| `saving` | 正在处理并写入系统相册 |
| `interrupted` | 相机被系统或其他应用占用，等待或允许重试 |
| `unavailable` | 模拟器、无摄像头或设备能力不满足 |
| `failed` | 显示可理解的错误，并在可恢复时提供重试 |

相机状态与 annotation 可见性互不影响。关闭自动显示提示不能影响相机会话启动，手动显示提示也不能改变拍摄状态。

## 6. 实施顺序

### M0：权限和状态骨架

状态：已实现。

- 增加用途说明和权限检查。
- 建立 `CameraModel` 的页面状态与错误类型。
- 确保拒绝权限、模拟器和无设备场景不会崩溃。

### M1：真实预览

状态：已实现并通过真机启动验证。

- 建立照片 capture session。
- 将 `AVCaptureVideoPreviewLayer` 放入当前模板视口。
- 完成进入、退出、前后台和基本中断恢复。

### M2：普通照片保存闭环

状态：已实现并通过真机保存验证。

- 接入快门、普通照片捕获和 add-only 相册保存。
- 完成拍摄锁、成功反馈和分阶段错误反馈。
- 暂时保留相册入口的现有占位行为。

### M3：Live Photo 保存闭环

状态：已实现并通过真机基础验证；完整失败与中断矩阵留在 M6。

- 增加音频 input、麦克风权限和 Live Photo 能力状态。
- 捕获静态照片与配对 movie，并作为一个 Live Photo asset 保存。
- 完成 Live 状态反馈、普通照片降级和临时文件清理。

### M4：现有控件接入真实能力

状态：已实现并通过当前测试设备验证。

- 接入前后摄切换、闪光灯、Live Photo 开关和设备提供的倍率档位。
- 移除 `CameraView` 中对应的纯 UI 假状态。
- 完成切换后的能力刷新和降级行为。

### M5：构图坐标闭环

状态：已实现；`3:4` 与 `4:3` 已完成真机验证，其余比例与前置、方向、Live Photo 组合留在 M6。

- 统一预览、Canvas、点击对焦和照片输出的变换。
- 接入点击对焦、测光和曝光补偿。
- 完成各模板比例、方向和前置镜像的裁切校准。
- 确保 Live Photo 的静态图与配对 movie 使用完全相同的可见区域。

### M6：稳定性与真机验收

状态：待推进。

- 验证连续拍摄、快速点击、反复进入退出、前后台切换和系统中断。
- 修复 runtime reset、相机占用、Live Photo 中断和保存失败后的恢复路径。
- 完成单摄与多摄 iPhone 的能力差异记录。

## 7. 本期暂不实现

- UI 视觉打磨、复杂动画和正式拍摄结果页。
- 多模板左右滑动和拍摄中切换模板。
- 独立视频录制、RAW、ProRAW、景深、人像模式与空间照片。
- 手动 ISO、快门速度、白平衡、直方图和峰值对焦。
- AI / Vision 实时分析、自动构图评分和自动拍摄。
- 完整的应用内相册、照片编辑、滤镜和用户可调裁切。
- 自定义物理镜头选择面板；本期只通过设备能力生成少量倍率入口。
- Camera Control、锁屏相机扩展等 iOS 18 之后出现的系统入口。

## 8. 验收标准

### 8.1 自动检查

- 通用 iOS Simulator destination 构建通过。
- 纯状态转换、倍率过滤和裁切矩形计算可独立测试，不依赖真实摄像头。
- 不新增编译警告，也不修改最低部署版本。

### 8.2 真机功能

- 首次授权、拒绝授权、从系统设置恢复权限都能继续到正确状态。
- Camera 能稳定启动和退出，不持续占用摄像头。
- 后置和前置切换符合设备实际能力。
- 闪光灯和倍率只在支持时出现并真实生效。
- 点击对焦、测光与曝光补偿有可观察的效果。
- 拍照完成后照片可靠保存到系统相册；失败时没有假成功提示。
- 支持 Live Photo 的设备上可以开启和关闭 Live；不支持或麦克风被拒绝时明确降级为普通照片。
- 保存后的 Live Photo 被系统照片 App 识别为单个可播放、带声音的 Live Photo，而不是两项独立资源。
- Live Photo 失败、中断或退出后不遗留临时 movie 文件。
- 连续拍摄和快速重复点击不会崩溃、黑屏或产生并发错误。

### 8.3 构图一致性

- `1:1`、`3:4`、`4:3`、`16:9` 至少各验证一个模板。
- 预览中的模板视口与最终照片边界不存在明显偏移。
- 竖屏、横屏、前置和后置照片方向正确且不被拉伸。
- 点击位置转换正确，对焦点与用户触摸位置一致。
- 最终照片不包含构图线和 annotation。
- Live Photo 静态画面与按压播放的动态画面边界一致，不发生比例或位置跳变。

真机验收至少覆盖一台 iOS 18 iPhone；条件允许时再增加一台具有不同镜头组合的设备，验证倍率降级行为。模拟器结果不能代替上述验收。

## 9. 实施前需要最终确认的产品规则

下面三项会直接影响体验或成片，但不阻塞 M0～M1：

1. 前置成片是否默认与镜像预览一致。当前建议一致，以保证构图位置与用户按快门时看到的画面相同。
2. 相册按钮在相机闭环完成后如何处理。当前建议本期继续占位，后续再选择“最近照片预览”或“系统照片选择器”，避免为了入口提前申请相册读取权限。
3. Live Photo 已确定纳入本期。第一版建议在支持的设备上默认开启并允许手动关闭；应用记住用户最近一次选择。麦克风未授权或当前 capture 配置不支持时自动回退到普通照片，不阻塞 Camera。

## 10. Apple API 依据

- [AVCam: Building a camera app](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)：参考 CaptureService actor、CameraModel 和 SwiftUI preview 的职责拆分。当前示例工程要求 iOS 26，但本计划不会使用其 iOS 26 专属能力。
- [Setting up a capture session](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)：capture session、输入、照片输出与 preview layer 的基础关系。
- [AVCaptureDevice authorization](https://developer.apple.com/documentation/avfoundation/avcapturedevice/authorizationstatus(for:))：相机授权状态与请求流程。
- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)：普通静态照片捕获。
- [Capturing and saving Live Photos](https://developer.apple.com/documentation/avfoundation/capturing-and-saving-live-photos)：音频 input、静态照片与配对 movie 的捕获和 PhotoKit 保存流程。
- [Live Photo movie file URL](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/livephotomoviefileurl)：每次 Live Photo 捕获的临时 movie 文件要求。
- [PHAssetCreationRequest](https://developer.apple.com/documentation/photos/phassetcreationrequest)：把 `.photo` 与 `.pairedVideo` 作为同一个系统相册 asset 保存。
- [Capture device zoom](https://developer.apple.com/documentation/avfoundation/capture-device-zoom)：设备倍率范围与虚拟多摄切换信息。
- [AVCaptureDevice.RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)：预览与照片方向校正；该能力可用于 iOS 18 基线。
- [PHPhotoLibrary](https://developer.apple.com/documentation/photos/phphotolibrary)：使用最小的 add-only 权限保存照片。
- [AVCaptureSession runtime errors](https://developer.apple.com/documentation/avfoundation/avcapturesession/runtimeerrornotification)：相机会话错误与中断恢复。

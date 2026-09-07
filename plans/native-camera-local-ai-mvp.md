# Framewise 原生相机与本地 AI MVP

> 状态：已停止，不再作为当前执行计划。本文件保留原技术探索方案；当前范围见 [产品 V1 计划](./product-v1.md)。

> 状态：实施中。M1 原生相机最短链路已通过 Android 真机验证；M2 设备能力与相机控制已接入，等待多摄设备验证。

> 阶段关系：上一轮 MVP 已验证“静态构图蒙版能够给新手提供可执行的拍摄目标”。本轮继续验证技术底座，不建设完整产品版本。远期产品范围见 `plans/product-v1.md`，不作为本轮实施依据。

## 1. 阶段目标

本轮只验证两个尚未解决的核心问题：

1. Framewise 能否通过自有原生相机层取得真实设备能力，并避免为了对齐模板而依赖不透明的数码缩放。
2. 设备端轻量视觉模型能否理解纯景取景画面，并从少量内置模板中快速找到当前场景可复现的候选。

最小闭环：

```text
打开现场模式
  → 原生相机显示取景画面
  → 本地 AI 低频分析纯景画面
  → 返回少量候选模板和推荐镜头
  → 用户选择模板
  → 显示现有 Skia 构图蒙版
  → 使用真实设备能力调整并拍摄
  → 保存原尺寸照片与测试元数据
```

这仍然是工程与产品假设验证。界面只需支持观察状态和完成测试，不新增正式产品导航、视觉体系或长期运营能力。

## 2. 已确认的产品边界

### 2.1 原生相机解决“怎么拍清楚”

- 查询设备实际存在的相机和能力，不把归一化 zoom 伪装成真实倍率。
- 选择物理相机或系统提供的逻辑多摄相机，并记录实际生效结果。
- 拍摄原尺寸照片，不使用预览截图作为成片。
- 提供点击聚焦、测光、曝光补偿、闪光灯和连续缩放的最小控制能力。
- 让预览、点击坐标、Skia 蒙版和最终照片使用同一裁切与方向模型。

不同 Android 设备不必暴露相同镜头或控制，但必须诚实报告能力；不支持的能力不显示、不模拟。

### 2.2 本地 AI 解决“纯景可以怎么拍”

本轮 AI 只处理没有明确人物主体的纯景场景，例如建筑、道路、山水、湖面和树林。它的职责是：

- 从低分辨率预览帧提取视觉特征。
- 与少量内置纯景模板的离线特征进行匹配。
- 返回最少且可解释的候选结果。
- 为候选模板附带推荐镜头和简单匹配依据。

本地 AI 不评价照片是否好看，不生成模板，不处理人像姿态，也不直接控制快门或自动切换镜头。

## 3. 本轮范围

### 3.1 必须完成

- Android 原生相机 View。
- 后置相机能力查询与真实 zoom ratio。
- 可验证的镜头选择或切换行为。
- 原生预览、点击聚焦与测光、曝光补偿和闪光灯。
- 原尺寸普通照片捕获与系统相册保存。
- `Preview`、`ImageCapture` 与 `ImageAnalysis` 同一会话运行。
- 原生层低频消费分析帧；相机帧不经过 React Native/JavaScript。
- 一个随应用打包的端侧模型和一组小型模板匹配数据。
- 返回最多三个纯景模板候选、置信度、推荐镜头和分析状态。
- 复用当前模板数据、Skia Canvas 和模板选择后的拍摄能力。
- 记录测试所需的模板、相机、倍率、输出尺寸、分析耗时和错误信息。

### 3.2 可以简化

- 只实现后置相机和竖屏 `3:4` 流程。
- 首轮只覆盖 4～6 个差异明确的纯景模板。
- AI 可以按固定低频率运行，不追求逐帧实时反馈。
- 推荐结果只在测试界面展示，不建设正式的模板发现页面。
- 测试元数据只需在当前会话查看或导出，不建设照片数据库。
- iOS 只保留接口兼容性，不在 Android 验证完成前实现。

### 3.3 明确不包含

- 完整 iOS 相机与 Live Photo。
- 人像检测、人体关键点、姿态或人物蒙版生成。
- AI 审美评分、自动构图评分和自动拍摄。
- 云端推理、账号、同步、社区和远程模板。
- AI 自动生成模板或用户编辑模板。
- 大规模模板库、向量数据库和训练平台。
- 收藏、最近使用、“我的”、复杂成片页和正式新手引导。
- 崩溃平台、分析平台、热更新、强制更新和商店发布建设。
- 品牌视觉、完整动效和产品级 UI 打磨。

## 4. 技术架构

项目继续保持 Expo SDK 57、React Native 0.86 和 React 19.2。使用本地 Expo Module 承载 Kotlin 原生 View 与相机能力，不手工维护生成的 `android/` 和 `ios/` 目录。

建议模块边界：

```text
React Native / TypeScript
├── 路由与 MVP 测试界面
├── 模板数据与候选展示
├── Skia 构图蒙版
└── 低频状态和结果
        ↕ 类型化命令与事件
modules/framewise-camera
├── CameraX Preview
├── CameraX ImageCapture
├── CameraX ImageAnalysis
├── 相机能力与控制
├── 端侧模型推理
└── 模板特征匹配
```

约束：

- 视频帧、YUV/RGB 缓冲区、模型张量和 embedding 不传给 JavaScript。
- JavaScript 只发送相机控制命令，并接收低频、可序列化结果。
- 原生平台类型不扩散到 route、template 或 canvas 模块。
- Skia 蒙版继续作为原生预览 View 的 sibling，不进入照片输出。
- 原生依赖通过本地 Expo Module 和 config plugin 管理；安装 Expo/React Native 相关包时只使用 `npx expo install --npm`。

官方依据：

- [Expo SDK 57](https://docs.expo.dev/versions/v57.0.0/)
- [Expo 本地模块](https://docs.expo.dev/more/create-expo-module/)
- [Expo 原生 View](https://docs.expo.dev/modules/native-view-tutorial/)
- [CameraX 架构](https://developer.android.com/media/camera/camerax/architecture)
- [CameraX 图像分析](https://developer.android.com/media/camera/camerax/analyze)
- [CameraX 配置与相机控制](https://developer.android.com/media/camera/camerax/configuration)

## 5. 原生相机设计

### 5.1 原生接口

首轮 TypeScript 边界只表达本轮实际需要的能力：

```ts
type CameraLens = {
  id: string;
  facing: 'back' | 'front';
  focalLengths: number[];
  minimumZoomRatio: number;
  maximumZoomRatio: number;
  supportsFlash: boolean;
  supportsFocusMetering: boolean;
  exposureCompensationRange: {
    minimum: number;
    maximum: number;
    step: number;
  } | null;
};

type CameraCapabilities = {
  lenses: CameraLens[];
  activeLensId: string;
  zoomRatio: number;
};

type CaptureResult = {
  uri: string;
  width: number;
  height: number;
  lensId: string;
  zoomRatio: number;
};
```

字段以实际可获得的数据为准。设备无法可靠报告的内容使用明确缺失值，不根据营销倍率或机型名称猜测。

### 5.2 CameraX 会话

同一次生命周期绑定中组合：

- `Preview`：原生取景 View。
- `ImageCapture`：高质量普通照片输出。
- `ImageAnalysis`：低分辨率 AI 输入。

分析使用非阻塞策略，只保留最新帧；分析未完成时丢弃旧帧，不能反向阻塞预览或快门。每个分析帧必须在完成或跳过后及时释放。

### 5.3 真实镜头验证

Android 厂商对逻辑多摄和物理相机的暴露方式并不一致，因此先做能力探针，再确定最终控制方式：

1. 枚举 CameraX 可用相机、逻辑多摄信息、物理相机信息、焦距与 zoom 范围。
2. 验证 CameraX zoom ratio 在测试机上何时发生视场和相机切换。
3. 验证显式选择 CameraInfo 或通过 Camera2 interop 指定物理相机的可用性。
4. 对比预览视场、输出 EXIF/尺寸和同场景细节，确认实际行为。
5. 只有经过真机验证的倍率才进入界面；其余设备退化到连续 zoom 和默认后摄。

本轮不承诺所有 Android 设备都能强制启用指定物理镜头。MVP 要证明的是能力可以被正确发现、使用和降级。

### 5.4 坐标一致性

原生相机需要输出统一的预览变换信息，供以下消费者共用：

- Skia 模板坐标到屏幕坐标。
- 屏幕点击到相机测光坐标。
- `ImageAnalysis` 画面到模板结构坐标。
- 最终照片裁切范围。

旋转、前置镜像、`aspect fill` 裁切和输出画幅不得由不同层分别推算。

## 6. 本地 AI 设计

### 6.1 首轮任务定义

首轮使用检索而不是生成：

```text
低分辨率预览帧
  → 原生预处理
  → 轻量视觉 embedding
  → 与内置模板向量计算相似度
  → 规则过滤与重排
  → 返回最多三个候选
```

embedding 负责场景相似性；简单结构信息负责排除明显不可复现的候选，例如横竖方向、天空/水面比例、道路纵深或建筑主体位置。首轮可以只实现 embedding，并通过离线评测决定是否需要第二阶段重排。

### 6.2 模型与运行时选型

规划阶段不写死具体模型或推理组件。实施时用同一组样本比较候选方案：

- 包体和模型体积。
- 首次加载时间与单次推理耗时。
- CPU、GPU 或 NPU 委托的设备覆盖。
- 连续运行对预览帧率、发热和内存的影响。
- 对本轮纯景模板的 top-k 匹配效果。
- 模型许可、离线分发和后续双平台迁移成本。

选型结果必须随模型版本、输入尺寸、归一化方式和输出维度一起记录，避免业务代码依赖未版本化的向量。

### 6.3 数据契约

本轮新增的 AI 数据与现有构图几何分开保存：

```ts
type ScenicTemplateMatchData = {
  presetId: string;
  modelVersion: string;
  embeddings: number[][];
  preferredLens: 'ultra-wide' | 'wide' | 'telephoto';
  orientation: 'portrait' | 'landscape';
  sceneTags: string[];
};

type SceneAnalysisResult = {
  analysisId: string;
  modelVersion: string;
  latencyMs: number;
  candidates: Array<{
    presetId: string;
    confidence: number;
    recommendedLens: ScenicTemplateMatchData['preferredLens'];
  }>;
};
```

- `CompositionTemplateDocumentV1` 继续只描述模板内容与几何。
- AI 匹配数据可以由离线工具生成，但运行时只读取随应用打包的版本化结果。
- 候选必须通过 `presetId` 查询现有模板，不复制标题、几何和提示文案。
- 首轮不引入向量数据库；小规模数据直接在内存中比较。

### 6.4 运行策略

- 只在相机 ready、应用位于前台且现场模式开启时分析。
- 初始目标频率为每秒 1～2 次，并根据实测结果调整。
- 画面移动明显、正在拍摄或正在切换镜头时允许暂停分析。
- 连续多个结果稳定后再更新候选，避免界面来回跳动。
- 模型加载、推理和匹配失败不能影响预览、手动选模板或拍照。

## 7. 实施顺序

### M0：固定基线

- 记录当前 `expo-camera` 在测试设备上的启动、缩放、输出尺寸、拍摄耗时和成片表现。
- 固定第一批 Android 测试设备与 4～6 个纯景模板。
- 准备每个模板的少量匹配和不匹配场景样本，仅作为技术验证集。

完成条件：后续原生相机和 AI 结果可以与同一套基线比较。

### M1：原生相机最短链路

- 创建本地 Expo Module 和 Android 原生 View。
- 完成 Preview、ImageCapture、生命周期和相册保存。
- 用原生 View 替换相机页的 `expo-camera` 预览，但保留现有 Skia 和控件层。

完成条件：能够连续拍摄和保存原尺寸照片，退出、返回和前后台切换不会黑屏或占用相机。

### M2：设备能力与相机控制

- 完成相机枚举、镜头探针、zoom ratio、点击聚焦/测光、曝光和闪光灯。
- 对比不同镜头与数码缩放结果。
- 打通统一预览坐标变换。

完成条件：测试设备上的能力展示真实，模板对齐不再依赖未知含义的归一化 zoom。

### M3：离线 AI 探针

- 选择候选端侧模型与运行时。
- 使用静态测试图片生成 embedding 并完成模板 top-k 匹配。
- 记录准确率、体积、加载时间和推理耗时。

完成条件：至少有一个方案在小型验证集上达到进入实时取景测试的标准。

### M4：实时帧分析

- 将 ImageAnalysis 低频帧直接送入原生推理链路。
- 返回稳定的模板候选和分析状态。
- 验证推理不会阻塞预览、镜头切换和拍照。

完成条件：连续运行时推荐可用，相机操作保持稳定。

### M5：集成外拍验证

- 在真实纯景场景中使用 AI 推荐选择模板。
- 按推荐镜头与蒙版完成拍摄。
- 保存相机、AI、模板和性能测试数据。
- 与手动寻找模板及上一轮 Expo 相机结果对比。

完成条件：能够判断原生相机和本地 AI 是否值得进入下一轮迭代，而不是继续扩展 MVP 功能。

## 8. 验收标准

### 8.1 原生相机

- 同一测试设备连续完成 20 次拍摄和保存，不出现崩溃、黑屏、相机占用或假成功。
- 输出为相机捕获的完整照片文件，尺寸、方向和 EXIF 行为可解释。
- 点击聚焦、曝光、闪光灯和 zoom 只在设备支持时提供，并能从失败状态恢复。
- 至少在一台多摄 Android 设备上证明真实相机能力可以被枚举，并验证一种可用的镜头选择或切换路径。
- 预览、蒙版、点击位置和最终成片在当前 `3:4` 流程中保持一致。

### 8.2 本地 AI

- 关闭网络后仍能完成模型加载、分析和模板推荐。
- 在固定验证集上，正确或可用模板进入 top-3 的比例达到 80% 以上；验证集与模板向量生成样本分开。
- 目标测试机单次分析延迟的 P95 不高于 500 ms，实际目标随模型探针结果记录并调整。
- 每秒 1 次分析连续运行 10 分钟时，不出现明显预览卡顿、内存持续增长或导致拍摄失败的热降频。
- 候选连续稳定后才更新；低置信度时明确返回无推荐，不强行匹配。

### 8.3 MVP 结果

- 新手在纯景现场无需预先记住模板，可以从本地推荐中找到至少一个可执行的构图。
- 推荐模板、推荐镜头、实际镜头和最终照片能够形成一条可复盘记录。
- 失败时仍可手动选择模板并正常拍照，本地 AI 不成为相机的单点故障。

## 9. 阶段结束后的决策

本轮结束只回答以下问题：

1. 自有原生相机是否解决了真实能力、成片质量和坐标一致性问题。
2. 纯景模板检索是否比用户手动浏览模板更快、更容易得到可执行结果。
3. Android 端的模型体积、耗时、发热和设备兼容性能否接受。
4. 下一轮应优化模型与模板数据、扩展 iOS，还是停止该方向。

未完成这四项判断前，不进入产品 V1、完整 UI、运营设施或大规模模板建设。

# Framewise MVP 架构

## 1. 目标和范围

MVP 验证一个产品假设：用户选择构图模板后，能否借助相机上的静态黄色引导线更快完成构图并拍出更满意的照片。

```text
模板列表 → 选择 Preset → 相机对齐 → 拍照 → 结果预览 → 重拍或完成
```

MVP 不包含：

- 人体、姿态或场景识别。
- 实时 AI 调整提示。
- 用户自定义或编辑模板。
- 模板下载、后台管理和登录同步。
- 视频拍摄、滤镜和手动裁切。
- 保存到系统相册。
- 横竖屏 variant 自动切换。

## 2. 技术边界

- Expo SDK 57 + React Native 0.86。
- Expo Router 管理页面路由。
- `expo-camera` 的 `CameraView` 提供相机预览和拍照。
- `@shopify/react-native-skia` 绘制模板黄色引导线。
- iOS 与 Android 都使用 Expo 实现，不维护自定义原生模块。
- MVP 只使用后置镜头和竖屏 `3:4` variant。

相机引导层是 `CameraView` 上方的透明 Skia Canvas，不参与照片输出。最终照片中不能包含构图线条。

Expo SDK 57 的实现必须以版本化文档为准：

- [Expo Camera v57](https://docs.expo.dev/versions/v57.0.0/sdk/camera/)
- [Expo MediaLibrary v57](https://docs.expo.dev/versions/v57.0.0/sdk/media-library/)

MVP 不使用 MediaLibrary；链接保留给 MVP 后的相册保存实现。

## 3. 页面与导航

```text
/
└── 模板列表
    └── /camera/[presetId]
        └── /review
```

### 模板列表

- 从本地 `CompositionTemplateDocumentV1` 读取 presets。
- 展示 preset 名称、用途和 MVP `3:4` variant 的缩略图。
- 点击 preset 时只传递 `presetId`，不通过路由传完整对象。
- 未知 `presetId` 返回模板列表并展示轻量错误。

### 相机页

- 根据 `presetId` 查询 preset。
- MVP 从 preset 中选择唯一的 `3:4` variant。
- 进入页面后请求相机权限。
- 相机准备完成前禁止快门。
- 页面失去焦点时卸载 `CameraView`；Expo Camera 同一时间只允许一个预览处于活动状态。
- 拍照成功后保存临时照片信息和本次使用的 preset、variant ID，再进入结果页。

### 结果页

- 显示本次拍摄的临时照片，不显示模板引导线。
- “重拍”清除照片并返回同一 preset 的相机页。
- “完成”清除拍摄会话并返回模板列表。
- 临时 URI 丢失或失效时返回模板列表。

## 4. 模板数据边界

模板模型以 `plans/template-data-model.md` 为唯一规范。顶层结构为：

```text
CompositionTemplateDocumentV1
└── presets: CompositionPresetV1[]
    └── variants: CompositionTemplateVariantV1[]
        └── elements: CompositionElementV1[]
            ├── type
            └── shape
```

关键规则：

- 顶层 `schemaVersion` 为 `1`。
- V1 允许 `3:4`、`4:3`、`9:16`、`16:9` 和 `1:1` 五种比例。
- MVP 数据只包含 `3:4` variant。
- `3:4` 和 `4:3` 是不同设计，不能自动旋转或拉伸生成。
- 所有坐标使用 `0...1` 模板画布坐标。
- Element type 表达构图语义，Shape 表达完整几何。
- 引导颜色、线宽和通用提示属于代码或主题，不进入模板数据。
- 模板数据是随应用发布的只读 TypeScript 数据，不需要数据库和网络请求。

模板加载时执行开发期校验。校验规则完整定义在 `plans/template-data-model.md`，架构层不维护第二份模型。

## 5. 构图视口和相机输出

MVP 使用固定竖屏 `3:4` 构图视口。模板坐标只相对于该视口计算，不相对于整个设备屏幕计算。

```text
┌──────────────────────┐
│                      │
│   CameraView 3:4     │
│   + Skia Canvas      │
│                      │
├──────────────────────┤
│ 提示、快门等控件      │
└──────────────────────┘
```

相机控件位于构图视口之外，不参与模板坐标变换。模板缩略图和相机页复用同一套 Shape 到像素坐标映射函数。

Expo Camera v57 的相关约束：

- `getAvailablePictureSizesAsync()` 返回当前设备支持的照片尺寸。
- `pictureSize` 决定照片尺寸；设置后 `ratio` 会被忽略。
- `ratio` 仅适用于 Android 预览。
- `takePictureAsync()` 必须等待 `onCameraReady`。
- 未启用 `skipProcessing` 时，照片会按设备方向处理并缩放以匹配预览。

实现阶段需要从设备支持尺寸中选择与 MVP 目标画幅兼容的照片尺寸，并在 iPhone 与 Android 真机上校准预览与成片的坐标一致性。

产品当前倾向采用与 iOS 相册相同的裁切处理。具体裁切算法、预览映射和跨平台一致性在相机实现阶段确定，不写入模板数据。

## 6. 状态管理

MVP 不引入 Redux、Zustand 或服务端状态库。

| 状态     | 所属位置                 | 生命周期           |
| -------- | ------------------------ | ------------------ |
| 模板文档 | `templates/data`         | 随应用发布，只读   |
| 相机状态 | 相机页本地 state         | 当前相机页面       |
| 拍摄会话 | `CaptureSessionProvider` | 从拍照到结果页结束 |

相机本地状态包括：

- 权限状态。
- 相机是否准备完成。
- 是否正在拍照。
- 页面是否处于焦点。

拍摄会话保存：

```ts
type CaptureSession = {
  presetId: string;
  variantId: string;
  photoUri: string;
  width: number;
  height: number;
};
```

临时照片位于 Expo Camera 返回的缓存目录。MVP 不长期持久化照片。

## 7. 目录设计

```text
src/
├── app/
│   ├── _layout.tsx
│   ├── index.tsx
│   ├── camera/
│   │   └── [presetId].tsx
│   └── review.tsx
├── features/
│   ├── templates/
│   │   ├── components/
│   │   ├── data/
│   │   ├── model/
│   │   └── screens/
│   ├── camera/
│   │   ├── components/
│   │   ├── model/
│   │   └── screens/
│   └── photo-review/
│       ├── model/
│       └── screens/
└── shared/
    ├── theme/
    └── ui/
```

边界规则：

- `src/app` 只解析路由参数并组合 feature screen。
- `templates` 不依赖相机实现，可以独立渲染缩略图。
- `camera` 读取 preset 和 variant，但不修改模板数据。
- `photo-review` 只读取拍摄会话。
- `shared` 不包含 Framewise 特有业务规则。

## 8. 核心组件

Skia 构图层的坐标、基准宽度、视口计算、组件拆分和测试策略统一遵守 `plans/skia-rendering-guide.md`。

### `SkiaCompositionOverlay`

- 输入：variant、视口宽高和渲染场景。
- 输出：覆盖构图视口的透明 Skia Canvas。
- 只负责坐标映射和黄色引导线绘制。
- 根据 element type 选择特别绘制方式和通用提示语义。
- 不读取相机权限，不持有相机状态。
- 缩略图和相机页共用同一个几何渲染器。
- 不把 `SkPath`、Paint 等运行时对象写回模板数据。

### `CameraViewport`

- 组合 `CameraView` 与 `SkiaCompositionOverlay`。
- MVP 保持固定 `3:4` 布局。
- 负责相机 ref、准备状态和拍照调用。
- 防止连续点击快门造成并发拍照。

### `CaptureSessionProvider`

- 持有当前临时照片和本次使用的 preset、variant ID。
- 提供设置和清除拍摄会话的操作。
- 不承担相机控制和模板查询。

## 9. 权限策略

- 打开相机页时请求相机权限。
- 显式处理权限加载、拒绝、永久拒绝和重试状态。
- MVP 不请求相册权限。
- 权限文案必须说明功能用途。

MVP 之后如增加相册保存，应在用户主动保存时请求写入权限，并按照 Expo SDK 57 MediaLibrary 文档使用 `Asset.create(fileUri)`；不使用会在新版入口运行时报错的 legacy API。

## 10. 错误处理

MVP 显式处理：

- 相机权限被拒绝。
- 相机挂载失败。
- 相机尚未准备完成。
- 拍照失败或返回空结果。
- 重复点击快门。
- 临时照片 URI 已失效。
- preset ID 不存在。
- preset 缺少 MVP `3:4` variant。
- 模板数据校验失败。

错误在最接近问题的页面展示，不建立全局错误总线。

## 11. 验证策略

### 自动检查

- 模板文档和 Shape 校验测试。
- Shape 到像素坐标映射测试。
- preset 和 variant 查询测试。
- 未知 preset ID 行为测试。
- 拍摄会话测试。
- TypeScript、lint 和 Expo 配置检查。

### 真机检查

- 至少一台 iPhone 和一台 Android。
- 预览引导与最终照片的构图区域是否一致。
- 照片方向是否正确且没有拉伸。
- 相机页失焦后是否停止预览。
- 权限首次请求、拒绝和恢复流程。
- 连续拍摄是否稳定。

最重要的验收标准是模板人物框、地平线等关键位置在成片中没有明显漂移。

## 12. 实现顺序

1. 安装并配置 `expo-camera` 和 `@shopify/react-native-skia`。
2. 实现 V1 模板类型、校验器、查询和两个测试 preset。
3. 实现共用的 `SkiaCompositionOverlay`。
4. 实现模板列表和缩略图。
5. 实现相机权限、固定 `3:4` 视口、引导层和快门。
6. 实现拍摄会话、结果页、重拍和完成。
7. 在 iPhone 和 Android 上校准预览、方向和成片区域。
8. 修复阻断链路的问题后进入用户验证。

在静态模板拍摄链路验证通过前，不增加动画、模板编辑、横屏、多画幅切换、相册保存或 AI 能力。

## 13. MVP 之后

- 保存照片到系统相册。
- 扩充真实 preset 和各画幅 variant。
- 根据设备方向选择 `3:4 ↔ 4:3` 或 `9:16 ↔ 16:9` variant。
- 对缺少对应方向 variant 的 preset 提示用户。
- 前后镜头、闪光灯、缩放和点击对焦。
- 本地 AI 主体识别和构图调整提示。

# Framewise MVP 架构

> 状态：与当前已实现的 MVP 保持一致。

## 1. 目标和范围

MVP 验证一个产品假设：用户选择构图模板后，能否借助相机上的静态黄色引导线更快完成构图并拍摄照片。

```text
模板列表 → 选择 Preset → 权限检查 → 相机对齐 → 拍照并保存 → 继续拍摄或退出
```

MVP 不包含结果预览页、拍摄会话、“重拍/完成”流程、AI 识别、用户自定义模板、视频、滤镜和手动裁切。

## 2. 技术边界

- Expo SDK 57 + React Native 0.86 + React 19.2。
- Expo Router 管理页面路由。
- Expo Camera `CameraView` 提供相机预览和拍照。
- Expo MediaLibrary `Asset.create()` 将照片写入系统相册。
- React Native Skia 绘制模板黄色引导线。
- React Native `PanResponder` 处理预览区域的双指缩放。
- iOS 与 Android 都使用 Expo 支持的实现，不维护自定义原生模块。

相机引导层是 `CameraView` 上方的透明 Skia Canvas，不参与照片输出。最终照片中不包含构图线条。

Expo SDK 57 的实现以版本化文档为准：

- [Expo Camera v57](https://docs.expo.dev/versions/v57.0.0/sdk/camera/)
- [Expo MediaLibrary v57](https://docs.expo.dev/versions/v57.0.0/sdk/media-library/)

## 3. 页面与导航

```text
/(tabs)/index
└── /camera?presetId=<id>
```

### 模板页

- 从本地 `CompositionTemplateDocumentV1` 读取 presets。
- 展示 preset 名称、用途和视觉预览。
- 用户选择模板时只传递 `presetId`，不通过路由传完整模板对象。
- 进入相机前顺序检查相机权限与照片写入权限。
- 任一权限未获得时停留在当前页面；不能再次申请时引导用户打开系统设置。

### 相机页

- 根据 `presetId` 查询 preset，并读取当前 variant。
- 相机准备完成前禁用快门。
- 在 `CameraView` 上叠加透明 Skia Canvas 和模板标注。
- 支持前后镜头、闪光灯、缩放档位和双指缩放。
- 拍摄期间锁定快门，避免并发调用 `takePictureAsync()`。
- 拍摄成功后立即通过 `Asset.create()` 写入系统相册。
- 保存成功后更新最近照片缩略图，并继续停留在相机页。
- 离开相机页时随页面卸载相机预览。

## 4. 模板数据边界

模板模型以 `plans/template-data-model.md` 为唯一规范：

```text
CompositionTemplateDocumentV1
└── presets: CompositionPreset[]
    └── variants: CompositionTemplateVariant[]
        └── elements: CompositionElement[]
            ├── type
            └── shape
```

关键规则：

- 顶层 `schemaVersion` 为 `1`。
- 所有坐标使用 `0...1` 的模板画布坐标。
- Element type 表达构图语义，Shape 表达完整几何。
- 引导颜色、线宽和屏幕像素值不进入模板数据。
- 模板数据是随应用发布的只读 TypeScript 数据，不依赖数据库或网络。
- 可序列化模板数据不保存 Skia 运行时对象。

## 5. 构图视口和相机输出

模板坐标只相对于相机预览视口计算，不相对于整个设备屏幕计算。

```text
┌──────────────────────┐
│ CameraView            │
│ + Skia Canvas         │
│ + Template Annotation │
└──────────────────────┘
│ 相机控件与状态反馈     │
└──────────────────────┘
```

Expo Camera v57 的相关约束：

- `zoom` 使用 `0...1` 的归一化值。
- `ratio` 只影响 Android 预览。
- `takePictureAsync()` 必须等待 `onCameraReady`。
- 不启用 `skipProcessing`，避免不同设备产生照片方向不确定性。

缩放按钮和双指手势共用同一个相机 zoom 状态。预览构图与最终照片的裁切一致性需要通过 iOS 和 Android 真机校准。

## 6. 状态管理

MVP 不引入 Redux、Zustand 或服务端状态库。

| 状态           | 所属位置                          | 生命周期         |
| -------------- | --------------------------------- | ---------------- |
| 模板文档       | `src/data/composition-templates/` | 随应用发布，只读 |
| 权限状态       | 模板路由与相机兜底检查            | 当前页面         |
| 相机与拍摄状态 | `src/features/camera/`            | 当前相机页面     |
| 最近照片缩略图 | `use-photo-library`               | 当前相机页面     |

相机本地状态包括准备状态、拍摄锁、保存反馈、镜头方向、闪光灯、缩放值和构图提示可见性。

## 7. 模块边界

```text
src/
├── app/
│   ├── (tabs)/index.tsx
│   └── camera.tsx
├── features/
│   ├── templates/
│   └── camera/
├── data/composition-templates/
├── canvas/
└── shared/
```

- `src/app/` 只处理路由参数、权限入口和 screen 组合。
- `features/templates` 负责模板列表界面，不依赖相机实现。
- `features/camera` 负责真实预览、相机控制、拍照和相册交互。
- `canvas` 负责模板几何解析与 Skia 绘制。
- `data/composition-templates` 保存只读模板文档和查询。
- `shared` 不依赖 feature 或 route 模块。

## 8. 权限策略

- 用户主动选择模板时开始权限流程。
- 先检查并申请相机权限，再检查并申请照片写入权限，避免并发显示系统弹窗。
- 两项权限都可用后才进入相机。
- 相机页只做权限失效兜底，不主动申请权限。
- 权限文案明确说明相机预览和照片保存用途。
- 使用 Expo MediaLibrary 新版 `Asset.create(fileUri)`，不使用 legacy API。

## 9. 错误处理

错误在最接近问题的页面显示，不建立全局错误总线。当前处理：

- 权限请求失败、被拒绝或不能再次申请。
- preset ID 不存在。
- 相机挂载失败或尚未准备完成。
- 拍照失败或返回空结果。
- 系统相册写入失败。
- 快速连续点击快门。

## 10. 验证策略

### 自动检查

- `npm run format:check`
- `npm run lint`
- `npm run typecheck`
- Expo 配置解析检查

### 真机检查

- 至少一台 iPhone 和一台 Android。
- 首次授权、拒绝和从系统设置恢复权限。
- 预览引导与最终照片构图区域的一致性。
- 照片方向正确且没有拉伸。
- 照片成功写入系统相册。
- 连续拍照、镜头切换、闪光灯和双指缩放稳定可用。

代码范围已经完成，当前阶段以双平台真机验收为主。

# Framewise 第一版架构

## 1. 目标

第一版只验证一个产品假设：用户选择一个构图模板后，能否通过相机上的静态引导线更快完成构图并拍出更满意的照片。

完整流程：

```text
模板列表 → 选择模板 → 相机对齐 → 拍照 → 预览 → 保存或重拍
```

第一版不包含：

- 人体、姿态或场景识别
- 实时 AI 调整提示
- 用户自定义模板
- 模板下载与后台管理
- 登录、云同步和作品历史
- 视频拍摄和照片编辑

## 2. 技术边界

- Expo SDK 57 + React Native 0.86
- Expo Router 管理页面路由
- `expo-camera` 提供相机预览和拍照
- `@shopify/react-native-skia` 绘制矩形、线条、定位点和后续动态引导
- `expo-media-library` 将确认后的照片写入系统相册
- iOS 与 Android 都使用 Expo 实现，不维护原生模块
- 开发阶段使用 Expo Go；需要验证正式权限文案时再构建应用
- 第一版仅支持竖屏拍照

相机蒙层是 `CameraView` 上方的透明 Skia Canvas，不参与照片输出。最终照片中不包含模板线条。

## 3. 页面与导航

```text
/
└── 模板列表
    └── /camera/[templateId]
        └── /review
```

### 模板列表

- 展示内置模板的封面、名称和一句用途说明。
- 点击模板时只传递 `templateId`，页面不传递完整模板对象。
- 未知或失效的 `templateId` 返回模板列表并显示轻量错误提示。

### 相机页

- 根据 `templateId` 从内置模板仓库读取模板。
- 进入页面后请求相机权限。
- 相机准备完成前禁止快门。
- 页面失去焦点时卸载 `CameraView`，避免预览在预览页背后继续运行。
- 拍照成功后把临时照片 URI 放入拍摄会话，再进入预览页。

### 预览页

- 显示本次拍摄的临时照片，不再显示模板蒙层。
- “重拍”清除当前照片并返回相机页。
- “保存”时再请求相册写入权限，保存成功后返回模板列表或停留并显示成功状态。
- 如果应用重启导致临时 URI 丢失，预览页返回模板列表。

## 4. 构图视口

第一版使用固定的竖屏 `3:4` 构图视口。模板坐标只相对于该视口计算，不相对于整个设备屏幕计算。

```text
┌──────────────────────┐
│                      │
│   CameraView 3:4     │
│   + Skia Canvas      │
│                      │
├──────────────────────┤
│ 提示、闪光灯、快门等  │
└──────────────────────┘
```

这样可以保证：

- 不同手机上的模板比例一致。
- 相机控件不会挤压或遮挡构图坐标。
- 模板可以同时用于列表缩略图和实时相机。
- 第二版 AI 检测结果可以映射到同一坐标空间。

相机实现需要优先选择 `4:3` 的照片尺寸。Android 可配置 `ratio="4:3"`；iOS 和 Android 都应从设备支持的 `pictureSize` 中选择一个 `4:3` 尺寸。由于不同设备的预览裁切行为可能不同，正式实现前必须在真机上校准“预览区域与成片区域一致性”。

## 5. 模板数据模型

模板作为随应用发布的只读 TypeScript 数据，不需要数据库或网络请求。

所有几何坐标使用 `0` 到 `1` 的归一化数值：

- `x=0, y=0` 表示构图视口左上角。
- `x=1, y=1` 表示构图视口右下角。
- 坐标在运行时映射为实际视口像素。

建议的数据契约：

```ts
type Point = {
  x: number;
  y: number;
};

type RectGuide = {
  id: string;
  type: 'rect';
  x: number;
  y: number;
  width: number;
  height: number;
  role: 'subject' | 'background' | 'safe-area';
};

type LineGuide = {
  id: string;
  type: 'line';
  from: Point;
  to: Point;
  role: 'horizon' | 'leading-line' | 'alignment';
};

type PointGuide = {
  id: string;
  type: 'point';
  position: Point;
  role: 'face' | 'focus' | 'vanishing-point';
};

type CompositionGuide = RectGuide | LineGuide | PointGuide;

type CompositionTemplate = {
  id: string;
  title: string;
  description: string;
  instruction: string;
  aspectRatio: '3:4';
  defaultFacing: 'back' | 'front';
  guides: CompositionGuide[];
};
```

模板加载时需要进行开发期校验：ID 唯一、坐标有限且位于 `0...1`、矩形不能超出视口、模板至少包含一个引导元素。第一版不引入运行时 schema 库，先使用小型断言函数完成校验。

## 6. 状态管理

第一版不引入 Redux、Zustand 或服务端状态库。

状态分为三类：

| 状态 | 所属位置 | 生命周期 |
| --- | --- | --- |
| 模板数据 | `templates/data` | 随应用发布，只读 |
| 相机状态 | 相机页本地 state | 当前相机页面 |
| 拍摄会话 | `CaptureSessionProvider` | 从拍照到预览结束 |

相机本地状态包括：

- 权限状态
- 相机是否准备完成
- 前后镜头
- 闪光灯模式
- 是否正在拍照
- 页面是否处于焦点

拍摄会话只保存：

```ts
type CaptureSession = {
  templateId: string;
  photoUri: string;
  width: number;
  height: number;
};
```

临时照片位于 Expo Camera 返回的缓存目录。用户保存前不写入相册，也不做长期持久化。

## 7. 目录设计

```text
src/
├── app/
│   ├── _layout.tsx
│   ├── index.tsx
│   ├── camera/
│   │   └── [templateId].tsx
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

assets/
└── templates/
```

边界规则：

- `src/app` 只解析路由参数并组合 feature screen，不写产品逻辑。
- `templates` 不依赖相机实现，可以独立渲染模板缩略图。
- `camera` 读取模板模型，但不修改模板。
- `photo-review` 读取拍摄会话并负责相册写入。
- `shared` 不包含 Framewise 特有业务规则。

## 8. 核心组件

### `SkiaCompositionOverlay`

- 输入：模板、视口宽高和显示样式。
- 输出：覆盖整个构图视口的透明 Skia Canvas。
- 使用透明背景和 `pointerEvents="none"`，不阻挡相机手势或控件。
- 只负责坐标映射和绘制，不读取权限、不持有相机状态。
- 模板卡片和相机页共用同一个渲染器，避免两套构图规则产生偏差。
- 模板只保存归一化几何数据，不保存 `SkPath`、`Paint` 等 Skia 运行时对象。

### `CameraViewport`

- 组合 `CameraView` 与 `SkiaCompositionOverlay`。
- 保持固定 `3:4` 布局。
- 负责相机 ref、准备状态和拍照调用。
- 防止连续点击快门造成并发拍照。

### `CaptureSessionProvider`

- 持有当前临时照片。
- 提供 `setCapture` 与 `clearCapture`。
- 不承担相机控制和模板查询。

## 9. 权限策略

- 打开相机页时请求相机权限，并提供拒绝、永久拒绝和重试状态。
- 只有用户点击“保存”时才请求相册权限。
- 相册权限只请求照片写入能力，不请求读取整个照片库。
- 权限文案必须说明功能用途，不使用泛化文案。

Expo SDK 57 的 MediaLibrary 新 API 应使用 `Asset.create(photoUri)` 保存文件；不使用已废弃且会在运行时报错的 `createAssetAsync` 或 `saveToLibraryAsync`。

## 10. 错误处理

第一版需要显式处理：

- 相机权限被拒绝
- 相机挂载失败
- 相机尚未准备完成
- 拍照失败或返回空结果
- 重复点击快门
- 照片缓存 URI 已失效
- 相册权限被拒绝
- 保存失败
- 模板 ID 不存在

错误只在最接近问题的页面展示。第一版不建立全局错误总线。

## 11. 验证策略

### 自动检查

- 模板数据校验与坐标映射单元测试
- 未知模板 ID 的行为测试
- 拍摄会话 reducer/provider 测试
- TypeScript、lint 和 Expo 配置检查

### 真机检查

- iPhone 与 Android 各至少两种屏幕比例
- 预览蒙层与最终照片的构图区域是否一致
- 前后镜头方向及镜像行为
- 相机切到预览页后是否停止
- 权限首次请求、拒绝和设置页恢复流程
- 连续拍摄与保存是否稳定

最重要的验收标准不是像素级一致，而是模板中的人物框、地平线等关键位置在成片中没有明显漂移。

## 12. 实现顺序

1. 安装并配置 `expo-camera`、`expo-media-library` 和 `@shopify/react-native-skia`。
2. 建立模板类型、校验函数和 2 个测试模板。
3. 完成模板列表及共用的 `CompositionOverlay`。
4. 完成相机权限、固定构图视口和拍照。
5. 完成拍摄会话、预览、重拍与保存。
6. 在真机校准预览与成片坐标，再扩充到首批 5 至 8 个模板。

在第 6 步通过前，不增加动画、模板编辑和 AI 能力。

## 13. 第二版扩展接口

第二版的本地 AI 可以输出同样采用归一化坐标的检测结果：

```text
相机帧检测结果 + CompositionTemplate
→ 比较当前位置与目标区域
→ 生成单条调整提示
```

第一版只保留稳定的模板坐标契约，不预先创建帧处理接口、原生模块或 AI 抽象层。等静态模板价值和端侧模型方案都得到验证后，再扩展相机 feature。

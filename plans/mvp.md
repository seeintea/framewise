# Framewise MVP

## 1. 验证目标

验证最短产品链路是否成立：用户选择一个内置构图 preset，在真实相机画面上看到对应黄色引导线，完成拍照，并在结果页检查照片。

```text
选择 Preset → 打开相机 → 按引导构图 → 拍照 → 检查结果 → 重拍或完成
```

MVP 只验证静态模板是否能帮助用户完成拍摄，不验证 AI、模板规模、多画幅切换和商业模式。

## 2. MVP 范围

### 必须完成

1. 在应用代码中内置一份 `schemaVersion: 1` 的模板文档和两个 preset。
2. 首页展示 preset 名称、用途和 `3:4` variant 缩略图。
3. 点击 preset 后通过 `presetId` 进入相机页。
4. 正常申请和处理相机权限。
5. 使用 Expo Camera 展示后置相机预览。
6. 使用 React Native Skia 绘制模板中的黄色引导线。
7. 点击快门拍摄一张照片。
8. 拍摄后进入结果页并展示本次照片。
9. 结果页支持“重拍”和“完成”。
10. 引导线只用于预览，不出现在最终照片中。

### 暂不实现

- 保存到系统相册。
- 前后镜头切换。
- 闪光灯、缩放和点击对焦。
- 横屏和多画幅 variant 自动切换。
- 用户自定义或编辑模板。
- 网络请求、远程模板和后台管理。
- 登录、作品历史和本地数据库。
- AI 识别、实时调整提示和自动评分。
- 用户手动裁切、照片滤镜和修图。
- 外部压暗、内部高亮、填充或蒙版。
- 动画和 Reanimated。

## 3. 模板数据

MVP 模板数据必须遵守 `plans/template-data-model.md`，不在本文件定义第二套类型。

MVP 数据边界：

- 顶层 `schemaVersion` 为 `1`。
- 用户选择 `CompositionPresetV1`。
- 每个测试 preset 只提供一个 `3:4` variant。
- Variant 使用 `{ width: 3, height: 4 }`，不使用字符串比例。
- Variant 通过 `elements` 保存构图元素，不使用 `guides`。
- Element 的几何全部保存在 `shape` 中。
- 坐标使用 `0...1` 模板画布归一化值。
- 数据不保存颜色、线宽、屏幕像素或 Skia 对象。

### Preset A：居中全身照

- 人物位于画面中央。
- 人物框约占画面高度的 76%。
- 头顶保留少量空间。
- 提示：“让人物完整站进框内”。

### Preset B：右侧留白半身照

- 人物位于画面左侧。
- 右侧保留环境空间。
- 使用一条三分安全线辅助对齐。
- 提示：“人物靠左，右侧留出环境”。

示例数据：

```ts
const templateDocument: CompositionTemplateDocumentV1 = {
  schemaVersion: 1,
  presets: [
    {
      id: 'centered-full-body',
      title: '居中全身照',
      description: '适合街道、建筑和旅行场景',
      variants: [
        {
          id: 'centered-full-body-3x4',
          aspectRatio: { width: 3, height: 4 },
          instruction: '让人物完整站进框内',
          defaultFacing: 'back',
          elements: [
            {
              id: 'main-subject',
              type: 'subject',
              shape: {
                type: 'rect',
                bounds: {
                  x: 0.24,
                  y: 0.12,
                  width: 0.52,
                  height: 0.76,
                },
              },
            },
          ],
        },
      ],
    },
    {
      id: 'left-half-body',
      title: '右侧留白半身照',
      description: '适合咖啡店、街景和环境人像',
      variants: [
        {
          id: 'left-half-body-3x4',
          aspectRatio: { width: 3, height: 4 },
          instruction: '人物靠左，右侧留出环境',
          defaultFacing: 'back',
          elements: [
            {
              id: 'main-subject',
              type: 'subject',
              shape: {
                type: 'rect',
                bounds: {
                  x: 0.08,
                  y: 0.2,
                  width: 0.42,
                  height: 0.64,
                },
              },
            },
            {
              id: 'third-line',
              type: 'safe-line',
              shape: {
                type: 'path',
                closed: false,
                nodes: [
                  { position: { x: 0.33, y: 0 } },
                  { position: { x: 0.33, y: 1 } },
                ],
              },
            },
          ],
        },
      ],
    },
  ],
};
```

## 4. 引导线绘制

`SkiaCompositionOverlay` 负责把 variant 的归一化 Shape 映射到实际视口。

具体的屏幕密度、整数坐标映射、referenceWidth、viewportSize、组件拆分和测试要求统一遵守 `plans/skia-rendering-guide.md`。

MVP 统一规则：

- 所有 element 使用黄色引导线。
- 开放 path 绘制线条。
- 闭合 path、rect、circle 和 ellipse 只绘制轮廓。
- 不填充、压暗或高亮任何区域。
- Element type 可以选择特别绘制方式和通用提示。
- 缩略图和相机页复用同一个几何渲染器。

## 5. 页面流程

### `/` 模板列表

- 读取本地 V1 模板文档。
- 校验 `schemaVersion` 和所有模板数据。
- 使用每个 preset 的 `3:4` variant 渲染缩略图。
- 点击卡片进入 `/camera/[presetId]`。

### `/camera/[presetId]` 相机页

- 根据路由参数查询 preset。
- 读取 preset 唯一的 MVP `3:4` variant。
- 请求相机权限并处理加载、拒绝和允许状态。
- 展示固定竖屏 `3:4` 的 `CameraView`。
- 在相机预览上叠加透明 Skia Canvas。
- `onCameraReady` 前禁用快门。
- 拍照期间锁定快门，避免并发调用。
- `takePictureAsync` 成功后，把 preset ID、variant ID、照片 URI 和尺寸放入拍摄会话。
- 离开相机页时卸载预览。

### `/review` 结果页

- 从拍摄会话读取照片 URI。
- 正确处理照片方向并完整展示，不叠加构图模板。
- “重拍”清除当前照片并返回同一 preset 的相机页。
- “完成”清除拍摄会话并返回模板列表。
- URI 缺失或失效时返回模板列表，不显示空白页面。

## 6. 状态

MVP 不引入第三方状态库。

- 模板文档：只读本地数据。
- 相机权限、准备状态和拍照状态：相机页本地 state。
- 拍摄会话：`CaptureSessionProvider`。

```ts
type CaptureSession = {
  presetId: string;
  variantId: string;
  photoUri: string;
  width: number;
  height: number;
};
```

## 7. 异常状态

MVP 必须能够显示并恢复：

- 相机权限尚未决定。
- 相机权限被拒绝。
- preset ID 不存在。
- preset 缺少 `3:4` variant。
- 模板文档或 Shape 校验失败。
- 相机挂载失败。
- 相机尚未准备完成。
- 拍照失败。
- 结果页没有有效照片。

错误处理保留在对应页面，不增加全局错误系统。

## 8. 完成标准

以下条件全部满足，MVP 才算完成：

- 两个 preset 都能从首页正确打开。
- 两个 preset 的缩略图和相机引导一致。
- 相机中展示不同且正确的黄色引导线。
- 引导线与相机预览保持相同的 `3:4` 构图区域。
- 用户可以连续完成“选择、拍照、检查、重拍或完成”。
- 结果照片方向正确，没有拉伸或明显裁切异常。
- 最终照片中没有黄色构图线。
- “重拍”返回同一 preset，“完成”返回模板列表。
- 快速连续点击快门不会触发多次拍摄或崩溃。
- 拒绝相机权限时不会出现黑屏或无响应。
- 至少在一台 iPhone 和一台 Android 真机上走通完整流程。
- TypeScript、lint 和 Expo 配置检查通过。

预览与成片的关键位置没有明显漂移，是相机链路的核心验收标准。裁切暂定倾向采用与 iOS 相册相同的处理方式，具体算法在相机实现阶段确定。

## 9. 实现顺序

1. 安装并配置 `expo-camera` 与 `@shopify/react-native-skia`。
2. 建立 V1 模板类型、校验器、查询和两个测试 preset。
3. 实现可复用的 `SkiaCompositionOverlay`。
4. 实现模板列表和缩略图。
5. 实现相机权限、固定 `3:4` 预览、引导线和快门。
6. 实现拍摄会话与结果页。
7. 真机检查预览和结果照片的比例、方向与裁切。
8. 修复阻断完整流程的问题后进入用户验证。

## 10. MVP 之后

1. 保存到系统相册。
2. 扩充真实 preset 和五种标准画幅 variant。
3. 根据设备方向选择对应横竖 variant，并处理缺失 variant 的提示。
4. 前后镜头、闪光灯等相机能力。
5. 本地 AI 主体识别和构图调整提示。

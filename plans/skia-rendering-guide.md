# [历史] Expo / Skia 构图引导实施指南

> 状态：过时的 React Native Skia 实施指南，保留用于理解早期渲染取舍。本文的 Canvas API、整数化策略、组件目录和执行步骤不适用于当前原生 iOS。
>
> 核对日期：2026-09-28。当前 iOS 使用 `Core/Canvas/MaskCanvas.swift` 与 `CanvasGeometry.swift`；后者直接把归一化值映射为浮点 `CGFloat`，没有沿用本文的 `Math.round` 规则。
> 平台无关的几何与文案分离原则仍可参考，当前文件格式见 [composition/README](../composition/README.md)。实现状态见 [当前状态](./current-status.md)。

## 1. 文档定位

本文是历史 Expo MVP 开发阶段的 Skia 实施指导，以下是当时采用的规范：

- `plans/template-data-model.md` 定义模板、Element 和 Shape 数据。
- `plans/architecture.md` 定义页面、相机和模块边界。
- 本文定义如何把 variant 中的归一化 Shape 稳定映射并绘制到屏幕 Skia Canvas。

MVP 的核心技术链路为：

```text
CompositionTemplateVariantV1
    ↓
CompositionElementV1[]
    ↓
ShapeV1
    ↓ 归一化坐标映射
整数逻辑坐标
    ↓
Skia 黄色引导线
```

核心能力是统一 Shape 渲染器；最大的集成风险是 CameraView 预览区域、Skia Canvas 和最终照片有效区域不一致。

## 2. 已冻结的渲染决策

### 2.1 屏幕 Canvas 不手动放大

屏幕上的 React Native Skia Canvas 使用 React Native 逻辑尺寸，不采用 Web Canvas 常见的手动 `2x` backing store 方案。

```tsx
<Canvas
  style={{
    width: viewportSize.width,
    height: viewportSize.height,
  }}
/>
```

禁止为了清晰度执行：

```ts
canvasWidth = viewportWidth * 2;
canvasHeight = viewportHeight * 2;
```

原因：

- 屏幕 Canvas 作为 React Native View 使用，底层原生 Surface 负责设备像素密度。
- 设备密度不一定是 2，也可能是 3 或其他值。
- 手动放大会使布局坐标、线宽和相机视口出现第二套缩放规则。
- 斜线锯齿由 Skia 抗锯齿处理，不通过扩大 Canvas 解决。

官方依据：

- [React Native Skia Canvas](https://shopify.github.io/react-native-skia/docs/canvas/overview/)
- [React Native Skia Paint properties](https://shopify.github.io/react-native-skia/docs/paint/properties/)

`highBitDepth` 提升的是颜色精度，不是 Canvas 分辨率，不用于解决黄色线条锯齿。

只有未来创建离屏 Surface、导出指定像素图片或使用不自动处理密度的 RuntimeShader 时，才单独引入 `PixelRatio`。这些情况不属于 MVP 相机覆盖层。

### 2.2 使用 Skia 抗锯齿

MVP 黄色引导线使用统一 Paint 属性：

```tsx
<Group
  color={GUIDE_COLOR}
  style="stroke"
  strokeWidth={GUIDE_STROKE_WIDTH}
  strokeCap="round"
  strokeJoin="round"
  antiAlias
>
  {/* elements */}
</Group>
```

初始建议：

```ts
const GUIDE_COLOR = '#FFD400';
const GUIDE_STROKE_WIDTH = 2;
```

实际黄色和线宽属于应用主题，不进入模板数据；最终数值在真机视觉检查后确认。

### 2.3 最终绘制坐标使用整数

模板继续保存 `0...1` 归一化小数。坐标计算过程中保持完整精度，只在生成最终 Skia 逻辑坐标时执行一次 `Math.round`。

```text
归一化模板数据
    ↓ 保持浮点
乘以实际 viewport 宽高
    ↓ 最终边界
Math.round
    ↓
Skia 整数逻辑坐标
```

允许每个最终坐标最多约 `0.5 pt` 的取整偏差。禁止在多个中间步骤反复取整。

## 3. 基准宽度和视口尺寸

### 3.1 referenceWidth 的语义

构图视口接受一个可选的外部基准宽度：

```ts
type CompositionViewportInput = {
  aspectRatio: AspectRatioV1;
  referenceWidth?: number;
  windowSize: Size;
};
```

`referenceWidth` 始终表示设备竖屏时的基准宽度，也可以理解为构图视口的基准短边：

- 竖屏 `3:4`、`9:16`：它是 Canvas 实际宽度。
- 横屏 `4:3`、`16:9`：它是 Canvas 实际高度。
- `1:1`：它同时是 Canvas 宽度和高度。

相同基准宽度下：

```text
referenceWidth = 390

3:4   → 390 × 520
4:3   → 520 × 390
9:16  → 390 × 693
16:9  → 693 × 390
1:1   → 390 × 390
```

横竖 variant 切换时继续使用相同 referenceWidth，避免引导整体突然放大或缩小。

### 3.2 默认值

未传入 `referenceWidth` 时，默认使用当前系统窗口的短边，而不是直接使用当前方向的 `window.width`：

```ts
function getDefaultReferenceWidth(windowSize: Size): number {
  return Math.floor(Math.min(windowSize.width, windowSize.height));
}
```

这样设备横屏时仍然使用原本的竖屏宽度语义。

### 3.3 从基准宽度计算 Canvas

```ts
function resolveViewportSize(
  referenceWidth: number,
  ratio: AspectRatioV1,
): Size {
  const base = Math.round(referenceWidth);

  if (ratio.width <= ratio.height) {
    return {
      width: base,
      height: Math.round((base * ratio.height) / ratio.width),
    };
  }

  return {
    width: Math.round((base * ratio.width) / ratio.height),
    height: base,
  };
}
```

### 3.4 特殊屏幕

折叠屏、分屏、平板或特殊可用区域，由外部先计算能够完整放入目标区域的最大 referenceWidth，再传给构图视口。

```ts
function getMaxReferenceWidth(
  availableSize: Size,
  ratio: AspectRatioV1,
): number {
  const widthScale =
    ratio.width <= ratio.height ? 1 : ratio.width / ratio.height;

  const heightScale =
    ratio.width <= ratio.height ? ratio.height / ratio.width : 1;

  return Math.floor(
    Math.min(
      availableSize.width / widthScale,
      availableSize.height / heightScale,
    ),
  );
}
```

组件只消费外部确定的 referenceWidth，不在内部维护 iOS、Android、折叠屏等平台分支。

### 3.5 CameraView 和 Canvas 必须共用尺寸

`viewportSize` 是 CameraView 和 Skia Canvas 的单一尺寸来源：

```tsx
const viewportSize = resolveViewportSize(
  resolvedReferenceWidth,
  variant.aspectRatio,
);

return (
  <View
    style={{
      width: viewportSize.width,
      height: viewportSize.height,
    }}
  >
    <CameraView style={StyleSheet.absoluteFill} />

    <SkiaCompositionOverlay variant={variant} viewportSize={viewportSize} />
  </View>
);
```

不允许 CameraView 和 Canvas 分别读取屏幕尺寸或分别计算比例。

## 4. 坐标映射

### 4.1 Point

```ts
function mapPoint(point: Point, viewport: Size): Point {
  return {
    x: Math.round(point.x * viewport.width),
    y: Math.round(point.y * viewport.height),
  };
}
```

Path 节点、`controlIn` 和 `controlOut` 全部使用同一函数。

### 4.2 Bounds

Rect 和 ellipse 必须映射并取整四条边，再通过边界差得到宽高。不要分别取整 `x` 和 `width`。

```ts
type PixelBounds = {
  x: number;
  y: number;
  width: number;
  height: number;
};

function mapBounds(bounds: Bounds, viewport: Size): PixelBounds {
  const left = Math.round(bounds.x * viewport.width);

  const top = Math.round(bounds.y * viewport.height);

  const right = Math.round((bounds.x + bounds.width) * viewport.width);

  const bottom = Math.round((bounds.y + bounds.height) * viewport.height);

  return {
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  };
}
```

这样不同 Shape 使用相同归一化边界时，会得到相同的整数边界。

### 4.3 短边长度

Circle radius 和 rect cornerRadius 使用实际视口短边：

```ts
function mapShortSideLength(value: number, viewport: Size): number {
  return Math.round(value * Math.min(viewport.width, viewport.height));
}
```

## 5. 核心组件结构

### 5.1 公开入口单一

对外只公开一个构图渲染入口：

```ts
type SkiaCompositionOverlayProps = {
  variant: CompositionTemplateVariantV1;
  viewportSize: Size;
  renderMode?: 'camera' | 'thumbnail';
};
```

```tsx
<SkiaCompositionOverlay variant={variant} viewportSize={viewportSize} />
```

调用方不需要知道 rect、circle、ellipse 或 path 如何转换成 Skia 节点。

### 5.2 内部不能成为巨型组件

内部结构固定为：

```text
SkiaCompositionOverlay
└── CompositionElementNode
    └── ShapeNode
        ├── RectShapeNode
        ├── CircleShapeNode
        ├── EllipseShapeNode
        └── PathShapeNode
```

职责：

- `SkiaCompositionOverlay`：创建 Canvas、统一 Paint、遍历 elements。
- `CompositionElementNode`：处理 `subject`、`horizon`、`safe-line` 语义。
- `ShapeNode`：按 `shape.type` 分发。
- 具体 ShapeNode：只负责一种几何的 Skia 表达。
- geometry mapping：只负责归一化坐标到整数逻辑坐标。
- path builder：只负责把 PathShape 转成 SkPath。

### 5.3 Overlay

```tsx
function SkiaCompositionOverlay({
  variant,
  viewportSize,
  renderMode = 'camera',
}: SkiaCompositionOverlayProps) {
  return (
    <Canvas
      style={{
        width: viewportSize.width,
        height: viewportSize.height,
      }}
      pointerEvents="none"
    >
      <Group
        color={GUIDE_COLOR}
        style="stroke"
        strokeWidth={getStrokeWidth(renderMode)}
        strokeCap="round"
        strokeJoin="round"
        antiAlias
      >
        {variant.elements.map((element) => (
          <CompositionElementNode
            key={element.id}
            element={element}
            viewportSize={viewportSize}
          />
        ))}
      </Group>
    </Canvas>
  );
}
```

### 5.4 Shape 分发

```tsx
function ShapeNode({ shape, viewportSize }: ShapeNodeProps) {
  switch (shape.type) {
    case 'rect':
      return <RectShapeNode shape={shape} viewportSize={viewportSize} />;

    case 'circle':
      return <CircleShapeNode shape={shape} viewportSize={viewportSize} />;

    case 'ellipse':
      return <EllipseShapeNode shape={shape} viewportSize={viewportSize} />;

    case 'path':
      return <PathShapeNode shape={shape} viewportSize={viewportSize} />;
  }
}
```

新增 Shape 时只修改 Shape 联合类型、校验器、分发器、对应 ShapeNode 和测试，不持续扩大 Overlay 本体。

## 6. Path 构建

Path 是 V1 最复杂的 Shape，应使用独立纯函数构建：

```ts
function buildSkiaPath(shape: PathShapeV1, viewport: Size): SkPath {
  const path = Skia.Path.Make();

  // moveTo / lineTo / cubicTo / close

  return path;
}
```

规则必须与数据模型一致：

- 第一个节点使用 `moveTo`。
- 没有控制柄的节点对使用 `lineTo`。
- A 到 B 使用 `A.controlOut` 和 `B.controlIn` 作为 `cubicTo` 控制点。
- 缺少某个控制柄时使用对应节点位置。
- `closed: true` 时调用 `close()`。
- 节点和控制点映射后统一取整数。

`PathShapeNode` 只消费构建结果：

```tsx
function PathShapeNode({ shape, viewportSize }: PathShapeNodeProps) {
  const path = useMemo(
    () => buildSkiaPath(shape, viewportSize),
    [shape, viewportSize],
  );

  return <Path path={path} />;
}
```

MVP elements 数量很少，不提前增加复杂缓存系统。只有性能测量证明有必要时，再扩大 memoization 范围。

## 7. 建议文件结构

V1 初期保持文件数量克制：

```text
src/features/templates/
├── components/
│   ├── SkiaCompositionOverlay.tsx
│   └── ShapeNode.tsx
├── model/
│   ├── template-types.ts
│   ├── validate-template-document.ts
│   ├── viewport.ts
│   ├── geometry-mapping.ts
│   └── build-skia-path.ts
└── data/
    └── template-document.ts
```

如果 ShapeNode 文件明显变大，再拆为：

```text
components/shapes/
├── RectShapeNode.tsx
├── CircleShapeNode.tsx
├── EllipseShapeNode.tsx
└── PathShapeNode.tsx
```

不要一开始创建大量空抽象，也不要把尺寸计算、数据校验、Element 语义和所有 Shape 绘制放入同一个文件。

## 8. 实现顺序

Skia 模块先脱离相机实现：

1. 实现 V1 TypeScript 类型和模板校验器。
2. 实现 `resolveViewportSize`、`mapPoint`、`mapBounds` 和 `mapShortSideLength`。
3. 实现 rect、circle、ellipse ShapeNode。
4. 实现 Path builder 和 PathShapeNode。
5. 创建固定 `3:4` 的静态测试页面，绘制两个 MVP preset。
6. 验证相同 variant 在不同 referenceWidth 下等比例缩放。
7. 将同一个 Overlay 用于模板缩略图。
8. 最后把 Overlay 覆盖到 CameraView，并校准预览与成片。

在第 6 步通过前，不接入相机；在静态渲染正确前，不同时调试几何和相机裁切。

## 9. 测试和验收

### 9.1 坐标单元测试

- Point 映射只在最终结果执行一次 `Math.round`。
- Bounds 通过 left、top、right、bottom 计算宽高。
- `3:4` 与 `4:3` 在同一 referenceWidth 下互换宽高。
- `9:16` 与 `16:9` 在同一 referenceWidth 下互换宽高。
- `1:1` 输出正方形。
- Circle radius 和 cornerRadius 使用视口短边。

### 9.2 Path 单元测试

- 两个无控制柄节点生成直线。
- 控制柄组合生成正确 `cubicTo` 顺序。
- 闭合 Path 最后调用 `close()`。
- 开放 Path 不被自动闭合。

### 9.3 视觉检查

- rect、circle、ellipse、水平线、垂直线和斜线边缘清晰。
- 贝塞尔曲线没有折点或错误控制方向。
- 黄色线宽在模板缩略图和相机页分别可辨认但不遮挡画面。
- 不同尺寸下元素相对位置和占比一致。
- iPhone 和 Android 真机均开启抗锯齿且没有明显锯齿。
- CameraView 和 Canvas 边界完全重合。

## 10. 开工检查表

- [ ] 使用 Expo SDK 57 兼容方式安装 React Native Skia。
- [ ] 模板类型与 `template-data-model.md` 完全一致。
- [ ] referenceWidth 的默认值使用系统窗口短边。
- [ ] 特殊屏幕可以由外部覆盖 referenceWidth。
- [ ] CameraView 与 Canvas 共用同一个 viewportSize。
- [ ] 屏幕 Canvas 不手动乘 2 或乘 PixelRatio。
- [ ] Shape 映射只在最终坐标处执行一次 `Math.round`。
- [ ] Bounds 取整四条边后再计算宽高。
- [ ] Circle 和 cornerRadius 使用短边基准。
- [ ] Overlay 对外单一、内部按 Element 和 Shape 分层。
- [ ] 黄色、线宽和 Paint 属性不写入模板数据。
- [ ] 静态页面验证完成后才接入 CameraView。

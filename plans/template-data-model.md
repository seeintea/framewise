# Framewise 模板数据结构设计草案

## 1. 文档目的

本文用于讨论构图模板的几何表达、蒙版结构和图片比例，不代表已经冻结的实现方案。

当前建议是：

- MVP 仍只支持竖屏 `3:4` 构图。
- 所有几何数据使用模板画布坐标，不保存屏幕像素或 Skia 对象。
- 编辑体验可以采用“点到点连接”，但存储模型不能只有点和边。
- 使用基础图形与自由路径的联合模型，覆盖矩形、圆形、椭圆和不规则轮廓。
- 模板比例是数据契约的一部分；相机预览、模板蒙层和最终照片必须使用同一套坐标变换。

## 2. 需要解决的问题

模板数据需要同时服务于：

1. 模板列表缩略图。
2. 相机预览上的实时构图引导。
3. 后续可能出现的模板编辑器。
4. 后续可能出现的主体检测和自动对齐。
5. 不同比例的照片模板。

如果模型只保存一组首尾相连的点，直线多边形很容易表达，但圆形、曲线和人物轮廓会出现数据冗余、编辑困难和缩放失真。因此需要区分图形语义，而不是把所有结构都降级成多边形。

## 3. 核心概念

### 3.1 模板画布

模板画布是构图数据的唯一坐标空间。它不等于设备屏幕，也不直接等于相机组件尺寸。

```ts
type AspectRatio = {
  width: number;
  height: number;
};

type TemplateCanvas = {
  aspectRatio: AspectRatio;
  orientation: 'portrait' | 'landscape';
};
```

坐标使用 `0...1` 的归一化值：

- `{ x: 0, y: 0 }` 是模板画布左上角。
- `{ x: 1, y: 1 }` 是模板画布右下角。
- 路径坐标分别按画布宽度和高度映射。

归一化坐标解决的是分辨率差异，不会自动解决宽高比差异。一个为 `3:4` 设计的模板不能直接拉伸成 `9:16`。

### 3.2 引导与蒙版

“引导”和“蒙版”是两种不同的视觉语义：

- 引导用于显示轮廓线、对齐线、定位点等提示。
- 蒙版用于压暗外部、突出内部或产生镂空区域。

二者可以复用相同的几何结构，但不能在数据中混为同一种元素。

### 3.3 几何结构

首版建议支持三类几何：

- 基础矩形，包括可选圆角。
- 圆形或椭圆形。
- 可开放或闭合的自由路径。

点到点连接适合作为自由路径的编辑方式。路径节点可带贝塞尔控制柄，以表达弧线和人物轮廓。

## 4. 建议数据契约

以下类型用于说明边界，字段命名仍可在实现前调整。

```ts
type Point = {
  x: number;
  y: number;
};

type RectShape = {
  type: 'rect';
  x: number;
  y: number;
  width: number;
  height: number;
  cornerRadius?: number;
};

type CircleShape = {
  type: 'circle';
  center: Point;
  radius: number;
};

type EllipseShape = {
  type: 'ellipse';
  center: Point;
  radiusX: number;
  radiusY: number;
};

type PathNode = {
  id: string;
  position: Point;
  controlIn?: Point;
  controlOut?: Point;
};

type PathShape = {
  type: 'path';
  closed: boolean;
  nodes: PathNode[];
};

type Shape = RectShape | CircleShape | EllipseShape | PathShape;
```

元素层建议使用可辨识联合类型：

```ts
type GuideRole =
  | 'subject'
  | 'face'
  | 'focus'
  | 'horizon'
  | 'leading-line'
  | 'alignment'
  | 'safe-area';

type GuideElement = {
  id: string;
  kind: 'guide';
  geometry: Shape;
  role: GuideRole;
};

type MaskEffect =
  | 'dim-outside'
  | 'highlight-inside'
  | 'outline';

type MaskElement = {
  id: string;
  kind: 'mask';
  geometry: Shape;
  effect: MaskEffect;
};

type TemplateElement = GuideElement | MaskElement;
```

模板本身：

```ts
type CompositionTemplate = {
  id: string;
  title: string;
  description: string;
  instruction: string;
  canvas: TemplateCanvas;
  defaultFacing: 'back' | 'front';
  elements: TemplateElement[];
};
```

## 5. 为什么圆形需要单独表达

圆形很可能出现在头像定位、焦点区域、取景孔或安全区域中，并不是异常结构。

如果使用大量直线节点逼近圆形：

- 需要保存很多重复数据。
- 缩放后可能看到棱角。
- 编辑器难以保持正圆。
- 命中检测和动画需要重新推断它是否原本是圆。

`circle.radius` 建议以模板画布短边为基准计算：

```ts
radiusPx = radius * Math.min(viewportWidth, viewportHeight);
```

这样即使画布宽高不同，圆形仍保持正圆。椭圆则分别使用 `radiusX` 和 `radiusY` 映射。

需要进一步确认 `cornerRadius` 是否也采用短边基准。为了保持视觉一致，建议采用与圆形半径相同的规则。

## 6. 自由路径与点到点编辑

点到点连接可以保留，但建议把它定义为编辑交互，而不是完整的数据模型。

路径规则建议如下：

- 没有控制柄的相邻节点使用直线连接。
- 存在控制柄时使用三次贝塞尔曲线连接。
- `closed: false` 的路径可用于地平线、引导线等开放结构。
- `closed: true` 的路径可用于人物轮廓和不规则蒙版。
- 只有闭合路径才能用于需要内部区域的蒙版效果。

首版若不提供模板编辑器，可以先手工定义少量节点，但仍保留上述契约，避免后续迁移纯多边形数据。

需要考虑的路径细节：

- 多个闭合轮廓组成一个蒙版时，是否需要孔洞。
- 孔洞采用 `evenOdd` 还是 `winding` 填充规则。
- 控制柄是保存绝对坐标，还是保存相对节点的偏移量。
- 节点顺序是否统一为顺时针。

建议首版只允许单轮廓闭合路径，不支持孔洞；确有模板需求后再增加复合路径。

## 7. 图片比例与坐标映射

系统中至少存在三个比例：

1. 模板设计画布比例。
2. 相机预览区域比例。
3. 最终照片的输出比例。

必须先确定最终照片实际覆盖的范围，再把该范围映射到模板画布，最后把同一变换用于屏幕蒙层。不能直接按整个设备屏幕缩放模板。

```text
相机原始画面
    ↓ 确定最终照片裁切范围
模板设计画布
    ↓ 等比例缩放和定位
屏幕相机视口 + 蒙层
```

需要明确的变换策略：

- `contain`：完整展示模板画布，可能留黑边或空白。
- `cover`：铺满视口，可能裁掉模板画布边缘。
- 精确裁切：相机预览与照片输出使用相同的裁切矩形。

相机拍摄场景更适合精确裁切。最终验收标准是预览里对齐的关键位置在成片中没有明显漂移。

## 8. 多比例模板策略

不建议把同一套元素直接拉伸到所有比例。`3:4` 人像模板改成 `9:16` 后，人物高度、头顶留白和环境区域通常需要重新设计。

未来可以让一个构图预设包含多个比例变体：

```ts
type CompositionPreset = {
  id: string;
  title: string;
  variants: CompositionTemplateVariant[];
};

type CompositionTemplateVariant = {
  id: string;
  canvas: TemplateCanvas;
  elements: TemplateElement[];
};
```

需要决定模板 ID 的语义：

- 一个 ID 代表一个具体比例的模板；实现简单。
- 一个 ID 代表一个构图概念，再由 variant 表示比例；产品组织更自然。

MVP 只有 `3:4` 时，可以暂时使用一个 ID 对应一个具体模板，但不必现在引入 `variants` 层。

## 9. 数据校验

开发期至少需要校验：

- 模板 ID 和元素 ID 唯一。
- 比例宽高为有限正数。
- 坐标和尺寸为有限数值。
- 所有归一化坐标位于允许范围内。
- 矩形、圆形和椭圆形没有超出模板画布。
- 半径、宽度和高度大于零。
- 开放路径至少有两个节点。
- 闭合路径至少有三个节点。
- 需要内部区域的蒙版不能使用开放路径。
- 模板至少有一个可渲染元素。

对于控制柄，可以允许它们短暂超出 `0...1`，但这会使曲线越出画布。是否禁止，需要结合模板编辑器的裁切行为决定。

## 10. MVP 建议边界

第一阶段建议：

- 只支持竖屏 `3:4`。
- 比例使用 `{ width: 3, height: 4 }` 表达，不使用字符串字面量写死类型。
- 支持 `rect`、`circle`、`ellipse` 和简单 `path`。
- 支持开放路径引导和单轮廓闭合蒙版。
- 不支持复合路径、孔洞和布尔运算。
- 不支持运行时编辑模板。
- 不支持自动把一个模板适配到其他比例。
- 缩略图和相机页复用同一个几何渲染器。

这个边界能够覆盖当前矩形人物框、定位点、三分线，以及后续圆形头像框和简单人物轮廓，同时避免过早实现完整矢量编辑器。

## 11. 待决策清单

- [ ] MVP 是否确实只输出 `3:4` 照片，而不只是显示 `3:4` 预览。
- [ ] 相机预览与实际照片在 iOS、Android 上分别采用什么裁切规则。
- [ ] 蒙版首版需要哪些效果：外部压暗、内部高亮、仅描边。
- [ ] `circle.radius` 和 `cornerRadius` 是否统一以画布短边为基准。
- [ ] 自由路径首版是否需要贝塞尔控制柄。
- [ ] 是否存在带孔洞或多个独立区域的真实模板需求。
- [ ] 未来模板 ID 表示具体比例，还是表示跨比例的构图概念。
- [ ] 多比例模板由设计者分别制作，还是允许系统自动生成初稿。
- [ ] 是否需要保存元素层级和绘制顺序。
- [ ] 是否需要为模板数据添加显式 `schemaVersion`，支持未来迁移。

## 12. 与现有文档的关系

现有 `plans/architecture.md` 和 `plans/mvp.md` 使用 `guides`，并把 `aspectRatio` 定义为字符串字面量 `'3:4'`。

如果本草案确认，应在实现模板类型前同步更新这两份文档：

- `guides` 调整为能够容纳引导与蒙版的 `elements`。
- `'3:4'` 调整为数值比例对象。
- 增加圆形、椭圆形和路径的半径映射规则。
- 补充预览、模板画布和成片之间的统一坐标变换。

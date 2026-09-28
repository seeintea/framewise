# [部分过时] 早期模板数据结构 V1

> 状态：旧 Expo 阶段的数据设计。几何设计原则仍可参考，顶层容器、实体类型、身份规则和文案组织已经被当前实现替代；本文不是当前 schema 的唯一规范。
>
> 核对日期：2026-09-28。当前文件格式与稳定 ID 规则见 [composition/README](../composition/README.md)，Swift 解码边界见 `ios/Framewise/Server/Models/`。实现状态见 [当前状态](./current-status.md)。

## 与当前格式的差异

| 早期设计 | 当前格式 / 实现 |
| --- | --- |
| 一个文档包含 `presets` | 每个模板目录包含独立的 `template.v1.json` 和 `<locale>.v1.json` |
| `CompositionPresetV1` / `CompositionTemplateVariantV1` | Swift 使用 `MaskDefinition`、`MaskVariant` 与组合后的 `MaskContent` |
| 语义字符串作为模板与变体 ID | 模板、变体使用稳定 UUID，语义名称保留为 `key` |
| 标题、说明、instruction 与几何放在一起 | 用户文案放在本地化文件，几何文件保留标注锚点 |
| 全文档 ID 与比例白名单校验 | 当前解码器按独立模板、变体与本地化引用校验；具体约束以代码为准 |
| MVP 只使用 `3:4` | 当前模板包含独立画幅变体，相机能力与映射见 [新相机架构](./ios-camera-architecture-v2.md) |

仍适用的原则包括归一化几何、Element 语义与 Shape 几何分离、不同画幅单独设计、绘制样式与 runtime 数据不进入模板。以下 TypeScript 示例保留原设计，不能直接当作当前 JSON 写入。

## 1. 文档目的

本文曾是 [历史 Expo 架构](./architecture.md) 与 [历史静态蒙版 MVP](./mvp.md) 的模板模型依据。

V1 只描述模板数据，不描述具体 Skia API、相机裁切算法或未来编辑器交互。模板数据需要同时服务于模板缩略图和相机实时构图引导。

## 2. 设计原则

- 用户选择的是构图概念 `CompositionPreset`。
- `CompositionTemplateVariant` 表示一个具体画幅下的独立构图设计。
- `3:4`、`4:3`、`9:16`、`16:9` 和 `1:1` 是五种受支持画幅。
- 横竖画幅不能通过旋转、拉伸或简单裁切互相生成。
- Element 表达构图语义，Shape 只表达几何。
- 所有几何数据使用模板画布归一化坐标，不保存屏幕像素或 Skia 对象。
- MVP 只绘制统一的黄色引导线，不保存颜色、线宽、透明度、填充或蒙版效果。
- V1 使用扁平 elements 数组，不保存图层、父子关系或 `zIndex`。
- 最外层 `schemaVersion` 是未来数据迁移的唯一入口。

## 3. 顶层版本容器

```ts
type CompositionTemplateDocumentV1 = {
  schemaVersion: 1;
  presets: CompositionPresetV1[];
};
```

版本使用整数，不使用产品语义版本。未来出现不兼容的数据结构变化时新增文档版本，并在读取边界完成校验和迁移。

## 4. Preset、Variant 和比例

### 4.1 支持的比例

V1 只允许与当前产品画幅一致的五种标准比例：

```ts
type AspectRatioV1 =
  | { width: 3; height: 4 }
  | { width: 4; height: 3 }
  | { width: 9; height: 16 }
  | { width: 16; height: 9 }
  | { width: 1; height: 1 };
```

对应关系：

```text
标准画幅：3:4 ↔ 4:3
宽画幅：  9:16 ↔ 16:9
方形画幅：1:1
```

不接受 `6:8`、任意小数或其他非白名单比例。MVP 只提供 `3:4` variant；其他比例和横竖屏自动选择在 MVP 之后实现。

### 4.2 Preset 和 Variant

```ts
type CompositionPresetV1 = {
  id: string;
  title: string;
  description: string;
  variants: CompositionTemplateVariantV1[];
};

type CompositionTemplateVariantV1 = {
  id: string;
  aspectRatio: AspectRatioV1;
  instruction: string;
  defaultFacing: 'back' | 'front';
  elements: CompositionElementV1[];
};
```

同一 preset 的不同 variant 由设计者分别制作。`instruction` 属于 variant，因为不同画幅下的主体位置、留白和提示可能不同。

## 5. Element

### 5.1 数据结构

```ts
type CompositionElementTypeV1 = 'subject' | 'horizon' | 'safe-line';

type CompositionElementV1 = {
  id: string;
  type: CompositionElementTypeV1;
  shape: ShapeV1;
};
```

职责划分：

- `element.type` 表达构图语义，供代码选择绘制方式和通用提示。
- `element.shape` 保存完整几何。
- Element 不保存提示文案、颜色、线宽、透明度或填充效果。
- 模板特有的构图说明保存在 variant 的 `instruction` 中。
- 类型对应的通用提示由应用代码集中管理。

### 5.2 类型与 Shape 的约束

| Element type | V1 合法 Shape                    |
| ------------ | -------------------------------- |
| `subject`    | rect、circle、ellipse、闭合 path |
| `horizon`    | 开放 path                        |
| `safe-line`  | 开放或闭合 path                  |

所有几何字段必须位于 `shape` 内。Element type 不定义 `x`、`y` 等专属几何字段。

正确的地平线数据：

```ts
{
  id: 'horizon',
  type: 'horizon',
  shape: {
    type: 'path',
    closed: false,
    nodes: [
      { position: { x: 0, y: 0.62 } },
      { position: { x: 1, y: 0.62 } },
    ],
  },
}
```

## 6. Shape

### 6.1 基础坐标类型

```ts
type Point = {
  x: number;
  y: number;
};

type Bounds = {
  x: number;
  y: number;
  width: number;
  height: number;
};
```

`Point` 和 `Bounds` 均使用模板画布归一化坐标。

### 6.2 矩形

```ts
type RectShapeV1 = {
  type: 'rect';
  bounds: Bounds;
  cornerRadius?: number;
};
```

`cornerRadius` 以模板画布短边为基准。

### 6.3 圆形

```ts
type CircleShapeV1 = {
  type: 'circle';
  center: Point;
  radius: number;
};
```

`radius` 以模板画布短边为基准，使圆形在非方形画布上仍保持正圆。

### 6.4 椭圆形

```ts
type EllipseShapeV1 = {
  type: 'ellipse';
  bounds: Bounds;
};
```

Ellipse 使用包围区域表达位置和占画面比例。Circle 不能由相同归一化宽高的 ellipse 替代，因为非方形画布会使其拉伸。

### 6.5 路径

```ts
type PathNodeV1 = {
  position: Point;
  controlIn?: Point;
  controlOut?: Point;
};

type PathShapeV1 = {
  type: 'path';
  closed: boolean;
  nodes: PathNodeV1[];
};
```

路径规则：

- 没有控制柄的相邻节点使用直线连接。
- A 到 B 的第一个控制点为 `A.controlOut`，缺省时使用 `A.position`。
- A 到 B 的第二个控制点为 `B.controlIn`，缺省时使用 `B.position`。
- 控制柄保存绝对模板坐标，不保存相对节点偏移量。
- `closed: true` 时，最后一个节点连接回第一个节点。
- 开放直线使用两个节点且 `closed: false` 的 path。
- 多边形使用没有控制柄的闭合 path。

### 6.6 Shape 联合类型

```ts
type ShapeV1 = RectShapeV1 | CircleShapeV1 | EllipseShapeV1 | PathShapeV1;
```

V1 不单独增加 line、polygon 或 rounded-rect，它们分别由开放 path、闭合 path 和带 `cornerRadius` 的 rect 表达。

V1 暂不支持：

- 通用 transform 和图形旋转。
- 复合 Shape、多轮廓 Path、孔洞和填充规则。
- 图形布尔运算。
- Path 节点 ID。
- Shape 内的绘制样式。

## 7. 坐标和映射

坐标范围为 `0...1`：

- `{ x: 0, y: 0 }` 是模板画布左上角。
- `{ x: 1, y: 1 }` 是模板画布右下角。

映射规则：

| 字段                    | 映射基准     |
| ----------------------- | ------------ |
| `x`、`width`            | 模板画布宽度 |
| `y`、`height`           | 模板画布高度 |
| `circle.radius`         | 模板画布短边 |
| `rect.cornerRadius`     | 模板画布短边 |
| Path 节点和控制点的 `x` | 模板画布宽度 |
| Path 节点和控制点的 `y` | 模板画布高度 |

缩略图、相机视口和后续检测结果必须复用同一套 Shape 到像素坐标转换函数。

## 8. 多区域和层级

一个 element 只包含一个独立 Shape。多个主体、多个安全线或复杂构图通过多个 elements 组合。

```ts
elements: [
  {
    id: 'left-subject',
    type: 'subject',
    shape: leftSubjectShape,
  },
  {
    id: 'right-subject',
    type: 'subject',
    shape: rightSubjectShape,
  },
];
```

V1 规定：

- `elements` 是扁平数组，不支持嵌套 children。
- 不保存 `zIndex`、`parentId`、`groupId` 或 layer。
- 渲染器按数组顺序绘制；数组顺序只提供确定性，不表示业务层级。
- 双人或多人引导轮廓允许重叠，不表达人物前后遮挡关系。
- 多条黄色线相交或重叠时，由渲染器处理，不增加模板字段。

## 9. MVP 绘制规则

MVP 只使用统一的黄色线条绘制构图引导：

- 开放 path 绘制黄色线条。
- 闭合 path、rect、circle 和 ellipse 只绘制黄色轮廓。
- 不填充图形。
- 不压暗画面或高亮内部区域。
- 不实现蒙版或镂空效果。
- 颜色、线宽和透明度由应用主题统一控制，不写入模板数据。

“九宫格”只描述简洁的相机引导线视觉风格，不表示每个模板必须包含完整九宫格。

## 10. V1 完整示例

```ts
const templateDocument: CompositionTemplateDocumentV1 = {
  schemaVersion: 1,
  presets: [
    {
      id: 'open-landscape',
      title: '开阔风景',
      description: '适合海面、草原和远山等开阔场景',
      variants: [
        {
          id: 'open-landscape-3x4',
          aspectRatio: { width: 3, height: 4 },
          instruction: '将地平线放在画面下部，保留更多天空',
          defaultFacing: 'back',
          elements: [
            {
              id: 'horizon',
              type: 'horizon',
              shape: {
                type: 'path',
                closed: false,
                nodes: [
                  { position: { x: 0, y: 0.62 } },
                  { position: { x: 1, y: 0.62 } },
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

## 11. V1 校验规则

开发期至少校验：

- `schemaVersion` 必须为 `1`。
- preset ID 和 variant ID 在整个文档中分别唯一。
- element ID 在所属 variant 中唯一。
- `aspectRatio` 必须是五种白名单组合之一。
- 所有坐标、尺寸和半径为有限数值。
- `Bounds.width`、`Bounds.height` 和 circle radius 大于零。
- 所有坐标和图形边界位于 `0...1`，边界值允许等于 `0` 或 `1`。
- `cornerRadius` 非负且不能超过矩形实际短边的一半。
- 开放 path 至少包含两个节点。
- 闭合 path 至少包含三个节点。
- Element type 与 Shape 满足第 5.2 节的组合约束。
- 每个 variant 至少包含一个可渲染 element，但不强制包含 subject。

V1 先采用严格画布边界。如果真实模板确实需要让 Shape 延伸到画布外，再通过后续 schemaVersion 明确放宽，而不是静默接受越界数据。

## 12. 相机输出与裁切边界

模板 variant 只声明目标 `aspectRatio`，不保存运行时裁切矩形、屏幕尺寸或平台相机参数。

当前产品倾向是照片裁切采用与 iOS 相册相同的处理方式。具体裁切算法、预览映射、跨平台一致性和真机校准在相机实现阶段确定，不阻塞 V1 模板数据结构。

## 13. MVP 之后

- 根据设备横竖方向在同一构图 preset 的对应 variant 之间切换。
- 缺少对应方向 variant 时提示用户旋转设备或选择其他画幅。
- 支持标准、宽幅和方形画幅选择。
- 在出现真实需求后，通过新的 schemaVersion 扩展复合 Shape、孔洞、图层或绘制表现。

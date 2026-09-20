# [部分归档] iOS 单模板相机链路

> [!IMPORTANT]
> 模板 JSON、`CompositionCatalog`、`CameraTemplateRequest` 与导航解析契约仍在活跃代码中；
> 本文涉及旧 `CameraView` 和旧相机页面渲染的实施记录已于 2026-09-20 归档。
> 旧相机代码保存在
> [`archive/ios-camera-legacy-2026-09-20/`](../archive/ios-camera-legacy-2026-09-20/README.md)，
> 不得据此推断当前相机能力已经实现。

## 目标

打通首页“拍一张”到相机页的最小数据链路，并显示
`classic-rule-of-thirds` 的默认九宫格变体。

## 边界

- `composition/templates/` 中的 JSON 是模板几何数据的唯一来源。
- Guide 只发起由模板 ID 组成的轻量请求，不持有完整模板。
- Navigation 负责用 `CompositionCatalog` 解析请求并处理无效 ID。
- Camera 接收已经解析的模板数据，不依赖 Guide。
- 本次只显示初始模板，不实现模板滑动。

## 为后续多模板保留的契约

`CameraTemplateRequest` 保存有序的 `templateIds` 和
`initialTemplateId`。单模板请求的数组只有一个元素；后续“拍人像”等入口可以直接
提供多个 ID，而无需修改路由类型。

## 实施步骤

1. 让 Swift 模型与现有模板 JSON 的 `key`、`defaultVariantId` 对齐。
2. 将共享模板目录作为只读资源加入 iOS target。
3. 新增 `CompositionCatalog`，统一加载、校验并按 ID 查询模板。
4. 新增 `CameraTemplateRequest`，并增加 Camera 路由。
5. 将拍摄回调沿 App、MainTab、Guide 传到 `GuideHeader`。
6. “拍一张”使用九宫格模板 ID 发起单模板请求。
7. CameraView 改为接收解析后的模板，并渲染其默认变体。
8. 构建验证，并检查无效模板 ID 的失败界面。

## 暂不实现

- 多模板左右滑动与选中状态。
- 相机采集、权限、对焦和拍照能力。
- 模板远程更新、缓存与本地化说明文字。

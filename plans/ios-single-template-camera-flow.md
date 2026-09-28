# iOS 模板到相机的数据链路

> 状态：当前实现说明，核对日期 2026-09-28。旧 `CompositionCatalog`、`CameraTemplateRequest` 和旧 `CameraView` 已被替代。
> 本文只说明模板加载、轻量路由和相机入口；相机能力见 [新相机架构](./ios-camera-architecture-v2.md)，全项目状态见 [当前状态](./current-status.md)。

## 当前已实现链路

```text
composition/templates/<key>/
  ├── template.v1.json
  └── zh-Hans.v1.json
        ↓ Xcode Templates 只读资源引用
MaskDataSource → MaskServer → MaskContent
        ↓
Guide「拍一张」 / SearchView 全部模版列表
        ↓ CameraMaskRequest(maskId, relatedMaskIds)
AppRootView 的 NavigationStack 解析与排序
        ↓
CameraAccess → CameraScreen → CameraMaskOverlay / MaskCanvas
```

- `composition/templates/` 是模板几何及本地化文件的唯一来源，目录与 ID 规则见 [composition/README](../composition/README.md)。
- `MaskDataSource` 从 bundle 加载几何与指定语言文件，`MaskServer` 完成模型组合与重复模板 ID 检查。名称中的 Server 不表示网络服务。
- Guide 和 Search 只发起 `CameraMaskRequest`，不把完整业务模型放入 navigation path。
- `AppRootView` 负责把初始 ID 与相关 ID 合成有序、去重的模板集合；未知相关 ID 会被忽略。初始 ID 无效时传入空集合。
- `CameraAccess` 处理相机、相册写入权限；Live Photo 使用的麦克风权限是可降级的可选权限。
- `CameraScreen` 接收解析后的 `[MaskContent]` 和 `initialMaskId`，使用选中模板的默认变体绘制蒙版，并按其画幅配置拍摄。
- 模板加载失败时，相机页显示轻量提示，基础拍摄仍可进入无模板状态。

## 当前入口

| 入口 | 请求范围 | 当前状态 |
| --- | --- | --- |
| Guide「拍一张」 | `foreground-depth`（前景纵深）模板 UUID `5aa983db-8730-4307-b18f-88ffe4735206` | 已接通单模板相机 |
| SearchView 全部模版列表 | 被点击模板的 UUID | 已接通单模板相机 |
| 设置中的 DEBUG 多模版入口 | UI mock 中的模板集合 | 只验证相机 UI 与切换，不经过正式加载路由或执行真实采集 |
| Guide 四个场景卡片和推荐图片 | 尚未产生模板请求 | 仍是展示内容 |

## 多模板契约

`CameraMaskRequest` 已包含 `maskId` 与 `relatedMaskIds`。相机底部在收到至少两个模板时提供切换选项；因此单模板与多模板共用同一入口。

请求类型和切换 UI 已存在，但正式场景分类、每类模板排序及首页绑定仍待实现，不能把 DEBUG 多模板入口视为产品分类链路已经完成。对应待办集中在 [后续工作](./next-steps.md)。

## 历史边界

早期单模板链路曾使用语义 ID `classic-rule-of-thirds`、`CompositionCatalog` 和 `CameraTemplateRequest`，本文已按当前代码更新。旧相机快照于 2026-09-28 从工作树移除，历史路径与读取规则见 [AGENTS.md](../AGENTS.md)。

旧链路的「未实现权限、拍摄、多模板」描述已失效；当前功能完成程度与待验收事项以 [当前状态](./current-status.md) 为准。

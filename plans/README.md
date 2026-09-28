# 文档索引与状态

> 整理日期：2026-09-28。先看当前实现，再看后续工作和设计；实验与历史文档按其适用范围阅读。

文档中的“当前”以其状态说明为准。**已实现**表示当前代码具备能力；**待验证**表示验收证据不足；**待实现 / 待优化**表示后续工作；**历史 / 已停止**不作为实施指令。旧文档的“完成”仅描述当时版本。

## 当前入口

| 文档 | 用途 |
| --- | --- |
| [当前实现清单](current-status.md) | 已实现功能、源码证据和验收边界 |
| [待实现与待优化](next-steps.md) | 未完成、待验证、待优化及暂不推进事项 |
| [产品 V1](product-v1.md) | 当前 iOS 无 AI 产品目标与优先级 |
| [新相机设计](ios-camera-architecture-v2.md) | 当前相机职责、输出契约与已确认取舍 |
| [模板到相机链路](ios-single-template-camera-flow.md) | 当前 `MaskServer` / `CameraMaskRequest` 导航与数据边界 |
| [平台迁移记录](migration-history.md) | Expo → SwiftUI → 相机重写、可追溯历史源码与暂不迁移行为 |

## 产品、数据与验证参考

| 文档 | 状态与适用范围 |
| --- | --- |
| [页面结构草案](app-structure.md) | 部分实现；首页 / 模板 / 我的等产品设想与当前导航仍有差异，未完成部分见待办 |
| [模板数据结构 V1](template-data-model.md) | 部分过时；旧容器、类型命名和文案组织已被替代，几何语义可参考。当前文件契约以 [composition/README](../composition/README.md)、实际 JSON 和 Swift 解码为准 |
| [蒙版产品验证](mask-validation.md) | 待执行的验证方案；不表示当前真机验收已完成 |
| [2026-09-05 外拍验证](field-validation-2026-09-05.md) | 已完成的有限外拍观察；缺少无蒙版对照，不能外推当前新相机效果；后续 AI 探索已停止 |

## 相机实验与旧入口

实验数据、方案失败与未解决问题集中到[相机实验记录](camera-experiments.md)，按日期与主题查阅。过去实验分支及其临时提交不会作为长期 Git 引用维护；原始本地附件也不保证长期可用。

| 文档 | 状态 |
| --- | --- |
| [相机实验记录](camera-experiments.md) | 独立实验档案；区分已采用、已撤回和仅观察结论 |
| [图片加工优化](ios-photo-processing-optimization.md) | 历史实施起点 / 实验入口；当前水印与处理已演进，不再作为分支实施计划 |
| [首拍性能调查](ios-camera-first-shot-validation.md) | 已结束调查入口；没有经验证的进一步优化，不是持续进行任务 |
| [HEIF 验证](ios-camera-heif-validation-2026-09-28.md) | 样本与边界入口；编码偏好已实现，完整真机验收仍待完成 |
| [Instruments 分析](ios-camera-trace-2026-09-28.md) | 已结束的 Release trace 分析入口；采样条件不足以定位 Debug 等待原因 |

## 过时 / 停止的实施文档

保留原文件位置以便追溯，正文在开头明确状态；不要据此创建旧模块、恢复历史源码或认定已迁移。

| 文档 | 过时范围 | 当前替代入口 |
| --- | --- | --- |
| [Expo MVP](mvp.md) | Expo 静态蒙版阶段目标和完成记录 | 产品 V1、当前实现清单 |
| [Expo 架构](architecture.md) | Expo Router / Camera / MediaLibrary、旧目录与状态流 | 当前实现清单、新相机设计 |
| [Skia 指南](skia-rendering-guide.md) | React Native Skia API 与集成方式 | SwiftUI `Core/Canvas/`，当前模板 JSON |
| [原生相机与本地 AI 探索](native-camera-local-ai-mvp.md) | Expo Native Module / Android / AI 的停止路线 | 产品 V1、待实现与待优化 |
| [旧 iOS 相机第一阶段](ios-camera-module-phase-1.md) | 旧相机 M0～M6 实施和验收 | 新相机设计、当前实现清单 |
| [旧相机成像管线](ios-camera-imaging-pipeline.md) | 旧类型、输出模型与管线重建 | 新相机设计 |
| [旧相机性能](ios-camera-performance.md) | 旧相机埋点、基线与感知延迟改造 | 当前实验记录；旧数据不作为新相机基线 |

## 维护方式

功能变化时同步实现清单与待办；设计变化时更新对应设计文档；实验结束后将条件、数据、结论和采用情况写入实验档案。历史状态不因新实现完成而改成“当前已完成”。工程规则见 [AGENTS.md](../AGENTS.md)。

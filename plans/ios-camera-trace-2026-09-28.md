# [实验记录入口] Release Instruments 分析

> 状态：2026-09-28 的 trace 分析已结束。本文保留旧文件入口。
> 完整录制事实、CPU 采样表、调用栈、二进制 UUID 和局限已集中到
> [相机实验记录：trace 分析](camera-experiments.md#untitledtrace-分析cpu-热点与采集边界)。

用户提供的 Untitled.trace 识别为 iPhone 16 Pro Max / iOS 27.0，二进制 UUID 与 Release
产物一致。数据确认 renderer 返回前执行绘制列表；两组静态加工 CPU 权重接近。
CPU 采样不等于墙钟等待，缺少捕获 UUID/signpost 和完整等待线程，不能解释 Debug 首拍
export 到首个合成请求的延迟，也不能证明问题已经消失。

原 trace 没有修改或入库，导出 XML 与统计文件只是本地临时产物。后续诊断曾调整 signpost
类别到 Points of Interest，代码未纳入正式实现，不承诺可从 Git 恢复。调查没有改图片格式、
画质、context 或并行策略；是否重新启动调查先按实际 Release 延迟判断。

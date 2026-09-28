# Untitled.trace 分析：CPU 热点与采集边界

分析日期：2026-09-28。输入为用户提供的 `Untitled.trace`，原始文件未修改、未纳入仓库。本轮调查已结束；总结果见 [首张拍摄延迟调查记录](ios-camera-first-shot-validation.md)。本文记录证据边界，不代表已找到或修复根因。

## 录制事实

- 模板 Time Profiler，单次运行约 29.270 秒，启动了 Framewise 新进程。
- 系统识别的硬件为 iPhone 16 Pro Max，iOS 27.0（24A437）；设备的自定义名称不作为机型依据。
- **构建为 Release**：trace 中 Framewise 主二进制 UUID 为 `15464400-8904-37CF-B934-F99D10DF25B8`，与本机 `Release-iphoneos/Framewise.app/Framewise` 的 dwarfdump 结果一致；Debug 主二进制 UUID 不同。不是仅凭函数优化形式推断构建配置。
- CPU 采样间隔约 1 ms，导出 time-profile 共 1810 个样本、总计 1810 ms 的采样权重。
- 录制目录显示 `record-waiting-threads=0`、`all-thread-states=NO`，没有完整线程状态／System Trace 数据。采样中偶见 wait/trap 函数不代表已测到其完整等待时间。
- signpost 采集配置针对 `PointsOfInterest`。导出的 signpost 没有 `CameraCapture`、`MovieExportToFirstFrame` 或捕获 UUID，无法对齐每张的快门及保存区间。当前诊断原本只在 Debug 编译；Release 构建和类别过滤是两项独立的采集缺口。

## 可确认的 CPU 热点

由应用方法调用栈可识别约第 11 秒与第 20 秒的两组照片加工。下面按 10–13 秒、19–22 秒两段隔离应用加工采样，**不是通过缺失的 capture UUID 得到的区间**。数字是包含下层调用的 CPU 采样权重，不能当作墙钟耗时，父子行不能相加，也不能涵盖系统服务或 GPU 的全部工作。

| 应用路径 | 第一组 CPU 权重 | 第二组 CPU 权重 |
| --- | ---: | ---: |
| CameraPhotoProcessor.process | 207 ms | 209 ms |
| PhotoAspectRatio.renderedImage | 105 ms | 115 ms |
| 最终 JPEG finalize（CGImageDestinationFinalizeEx） | 56 ms | 57 ms |
| 自定义视频合成请求 startRequest（所有采到的帧） | 98 ms | 100 ms |

静态处理采样在工作线程，并非 Main Thread。第一组 renderer 方法的样本时间约为 11.087–11.245 秒，第二组为 20.373–20.515 秒；这只是首次／末次被采到的时间，不是精确进入／退出时刻。

静态 renderer 的主要调用路径为：

```text
PhotoAspectRatio.renderedImage
  UIGraphicsImageRenderer.imageWithActions
    UIGraphicsImageRendererContext.currentImage
      rip_auto_context_create_image
        rip_auto_context_rasterization_loop
          CGDisplayListDrawInContextDelegate
            CG::DisplayList::executeEntries
              ripc_DrawImage / 图像读取 / 颜色转换
```

这证明本次执行中有绘制列表在生成最终 UIImage 时执行，可以解释为什么之前闭包中的 `image.draw` 返回很快、renderer 返回前还有明显耗时。不能仅由函数名 `img_data_lock` 推断锁竞争。

还观察到 `RGBAf16_mark_inner` 和 vImage 色彩／像素格式转换、内存拷贝。它们属于后续可调查的渲染成本，但两组成本相近，尚不能解释首拍额外等待。不能据此直接改成 SDR 或较低位深，避免无证据地改变照片输出效果。

第一组 context 创建路径包含 `CI::MetalContext::init`、系统 kernel library / binary archive 加载等，`CIContext.init` 的采样权重约 12 ms。这支持首次创建有初始化工作，但并不等于之前数百毫秒的全部延迟。

视频自定义渲染的可见 CPU 权重两组接近。没有证据把以前首拍增加约 600 ms 归因于逐帧水印计算；也没有足够信息排除系统服务、调度或其他启动等待。

## 结论与修正

1. 本份数据确认了静态 renderer 的实际工作发生位置，并显示两次静态加工的 CPU 权重接近。
2. 缺少 capture 标记和等待线程数据，不能精确框选 export 至首个合成请求，更不能把该等待定位为某个锁或编码器初始化。
3. 当前样本为 Release，而之前逐阶段日志来自 Debug，不能直接将两者的首拍差异归因于某个代码改动，也不能宣称问题已消失。
4. 实验分支 `codex/camera-first-shot-performance` 已将 signposter 改为 `.pointsOfInterest`，文本 logger 保留原类别。与本次录制配置匹配；依据 [Apple 的 CPU 分析与 signpost 示例](https://developer.apple.com/documentation/xcode/analyzing-cpu-profiles-with-call-tree-views)。类别 API 自 iOS 12 可用，符合项目最低 iOS 18。该改动的 Simulator 无签名构建通过；诊断代码未随本文进入 main。
5. 若继续复现旧日志的问题，应明确 Profile 使用 Debug，并在拍照前录制、确认 Points of Interest 中出现 `MovieExportToFirstFrame`。如要分析等待原因，还需 Thread State Trace / System Trace。最终是否值得优化，应以 Release 的真实保存延迟独立判断。

本轮未调整图像格式、画质、context 或并行策略。原始 trace 保持不变，导出 XML 和统计文件仅作为本地临时分析产物，不纳入仓库，也不作为长期可用附件。诊断代码保留在实验分支，主分支仅接收整理后的文档。

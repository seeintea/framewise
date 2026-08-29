# 项目架构

## 技术选择

- Expo SDK 57 + React Native 0.86。
- Expo Router 负责页面路由，路由文件只做页面组合。
- 使用 Development Build，不使用 Expo Go。
- iOS 优先；Android 保留工程支持，MVP 阶段暂不实现。
- 不支持 Web。
- 原生工程通过 Expo Prebuild 和 Config Plugin 生成，不直接维护 `ios/`、`android/`。

## 目录边界

```text
src/
├── app/          # Expo Router 路由
├── profiles/     # 人物档案与基准比例
├── references/   # 参考图及其分析结果
├── guidance/     # 拍摄引导状态与提示
└── shared/       # 通用组件、类型和工具
modules/
└── smart-camera/ # Swift 原生相机、图像分析与画面叠加
```

## 职责划分

- React Native：页面流程、人物档案、参考图选择、引导状态展示和结果保存。
- `smart-camera`：相机采集、Vision 分析、动作与比例检测、蒙版叠加和拍照。
- 相机帧、蒙版像素和高频传感器数据保留在原生层，只向 React Native 发送低频、可序列化的引导状态与拍照结果。

## 数据流

```text
人物基准数据 + 参考图分析结果
→ SmartCamera 原生实时分析
→ 单条调整指令
→ 达到容差后拍照
→ 保存结果与满意状态
```

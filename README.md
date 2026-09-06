# Framewise

Framewise 是一款帮助用户完成照片构图的相机应用。

用户可以选择预设的构图模板，并在实时相机画面上通过可视化引导线调整人物、主体和留白的位置。引导层只参与拍摄预览，不会出现在最终照片中。

构图模板使用归一化坐标描述几何，因此同一套数据既可以渲染模板缩略图，也可以映射到不同尺寸的相机视口。模板的语义和几何与具体渲染实现分离，为后续扩展更多画幅和构图类型保留空间。

## 技术栈

- Expo SDK 57、React Native 0.86 与 TypeScript
- Expo Router
- React Native Skia
- ESLint 与 Expo 官方规则
- Prettier 与 OXC parser
- lint-staged 与 simple-git-hooks

## 开发

项目仅使用 npm，要求 Node.js 22.22.1 或更高版本。为避免 pnpm 在本项目 Windows 打包中出现的路径过长问题，不要使用 pnpm、Yarn 或 Bun；只维护 `package-lock.json`。

```bash
npm install
npm start
```

常用命令：

```bash
npm run ios          # 启动 iOS 原生开发构建
npm run android      # 启动 Android 原生开发构建
npm run build:local:ios      # 使用 preview 配置在本机打包 iOS 预览包
npm run build:local:android  # 使用 preview 配置在本机打包 Android 预览包
npm run format       # 格式化项目文件
npm run lint         # 运行 Expo ESLint
npm run typecheck    # 运行 TypeScript 类型检查
npm run check        # 运行格式、lint 和类型检查
npm run check:android # 生成 Android 工程并检查原生相机的 Kotlin 编译与 Android Lint
```

提交代码时，pre-commit hook 会通过 lint-staged 自动格式化并检查暂存文件。

`check:android` 会排除 `react-native-worklets` 当前会导致 Android Lint 分析器崩溃的依赖任务，但仍会完整执行 `framewise-camera` 自身的 Kotlin 编译和 Lint 报告。该检查比 `npm run check` 慢，不放入 pre-commit。

## 设计文档

- [应用架构](./plans/architecture.md)
- [模板数据结构](./plans/template-data-model.md)
- [Skia 渲染指南](./plans/skia-rendering-guide.md)

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

项目使用 pnpm，要求 Node.js 22.22.1 或更高版本。

```bash
pnpm install
pnpm start
```

常用命令：

```bash
pnpm ios          # 启动 iOS 原生开发构建
pnpm android      # 启动 Android 原生开发构建
pnpm format       # 格式化项目文件
pnpm lint         # 运行 Expo ESLint
pnpm typecheck    # 运行 TypeScript 类型检查
pnpm check        # 运行格式、lint 和类型检查
```

提交代码时，pre-commit hook 会通过 lint-staged 自动格式化并检查暂存文件。

## 设计文档

- [应用架构](./plans/architecture.md)
- [模板数据结构](./plans/template-data-model.md)
- [Skia 渲染指南](./plans/skia-rendering-guide.md)

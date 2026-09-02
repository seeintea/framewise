# Framewise 工程指南

Framewise 正在持续迭代。保持改动小而可逆，并以当前实际存在的代码为准。不要把计划中的模块或功能视为已经实现。

## 事实依据

- 做出假设前，先检查当前代码、`package.json` 和 Expo 配置。
- `plans/` 下的文件描述产品和架构方向，只作为上下文，不代表相关功能已经实现。
- Expo 已经发生变化。编写或修改 Expo 代码前，必须阅读准确的 SDK 57 文档：<https://docs.expo.dev/versions/v57.0.0/>，并使用对应版本的 API 页面。

## 运行环境与依赖

- 使用 Node.js 22.22.1 或更高版本以及 pnpm。不要引入 npm、Yarn、Bun 或额外的锁文件。
- 保持 Expo SDK 57、React Native 0.86 和 React 19.2 与 `package.json` 一致。除非用户明确要求，否则不要升级核心运行时。
- 使用 `pnpm expo install` 安装 Expo 和 React Native 包，让 Expo 选择兼容版本。
- 优先使用 Expo 支持的 API 和 config plugin，不要直接修改生成的原生项目。
- 生成的 `ios/` 和 `android/` 目录不纳入版本控制，不要依赖其中的手动修改。
- 只有当平台、Expo、React Native 或简单的本地实现无法合理提供所需能力时，才新增依赖。

## TypeScript 与模块

- 应用代码使用 TypeScript，并保持 strict mode 开启。
- 以 React 组件为主要职责的文件使用 PascalCase，例如 `CameraViewport.tsx`；其他源码文件和目录使用 kebab-case。Expo Router 的 `_layout.tsx`、`index.tsx`、路由语义文件，以及聚合导出的 `index.ts` / `index.tsx` 和生态固定配置文件保持其约定名称。
- 在模块边界保留有用的类型。避免使用 `any`、不安全的类型断言和重复的领域类型。
- 从 `src/` 导入模块时，如果 `@/` 别名能让归属更清晰，则优先使用它。
- 工具配置使用 ESM 和明确的 `.mjs` 扩展名。没有具体需要时，不要把整个 package 切换为 ESM。
- 遵守 Rules of Hooks，并保持代码与已启用的 React Compiler 兼容。

## 实现风格

- 为当前需求实现最简单且正确的方案，不要为假设中的未来需求进行设计。
- 优先直接、易读的代码，不要增加额外层级、通用抽象、factory、wrapper，或只有一个使用场景的配置。
- 对于已经被 TypeScript 类型、本地数据所有权或框架文档契约排除的状态，不要增加防御性分支。
- 只在真正不可信的边界校验数据，例如路由参数、持久化数据、设备 API 和网络响应。不要在可信的内部代码中重复相同校验。
- 当现代 JavaScript 和 TypeScript 语法能让代码更简短或清晰时，应灵活使用 Expo 57 和 Hermes 支持的 optional chaining、nullish coalescing、解构、数组方法以及 `async`/`await` 等能力。
- 优先使用语言和平台能力，不要引入兼容性 helper、自定义工具函数或冗长的遗留写法。
- 让意外的编程错误在开发阶段保持可见。不要静默捕获错误，也不要添加会隐藏缺陷的 fallback 行为。

## 项目边界

- `src/app/` 只负责 Expo Router 路由、参数处理和 screen 组合。
- 产品特有的行为放在 `src/features/<feature>/` 下。
- 真正跨 feature 的 UI、类型、工具和配置放在 `src/shared/` 下。
- `shared` 不得依赖 feature 或 route 模块，feature 模块不得依赖 route 模块。
- 引入全局状态库前，优先使用组件本地状态和 React context。
- 保持可序列化的构图模板数据独立于 Skia 运行时对象和屏幕像素值。

## 代码质量

- ESLint 与 `eslint-config-expo` 是 lint 规则的唯一依据。
- Prettier 与 OXC parser 是格式化的唯一依据，不要手动调整成与其输出冲突的格式。
- 不要关闭 lint 或类型错误；如确有必要，必须在例外位置说明具体原因。
- 不要在一次聚焦的改动中混入无关重构或全仓格式化。
- 完成代码或配置改动前，运行：

  ```bash
  pnpm check
  ```

- pre-commit hook 会运行 lint-staged。不要为了隐藏检查失败而绕过它。

## Git 提交

- 只有用户明确要求时才创建 commit。
- 一个 commit 可以包含多项共同完成的改动，不需要为了保持单一目的而强行拆分。
- commit 的标题和 body 统一使用英文。
- 使用简洁的 Conventional Commit 标题，格式为 `<type>: <主要结果>`。根据主要目的选择 type，通常使用 `feat` 或 `chore`；只有在 `fix`、`refactor` 或 `docs` 等类型更准确时才使用它们。
- 标题只描述这个 commit 中最主要的工作，不要试图罗列所有改动。
- 标题后空一行，再添加简短的 body。使用几个简单的 bullet 补充实际完成的内容，包括次要工作和配套完善。
- body 中的 bullet 应客观、简洁。不要记录按时间排列的实现过程，不要逐文件复述 diff，也不要加入穷尽式的底层细节。
- 只有当验证信息能提供有用上下文时，才在 body 中提及。

示例：

```text
chore: establish code quality tooling

- configure Expo ESLint and Prettier with the OXC parser
- run lint and formatting on staged files before commits
- add shared format, lint, typecheck, and check commands
```

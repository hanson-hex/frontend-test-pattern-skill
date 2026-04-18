---
name: frontend-test-pattern
description: 前端测试技能，为 React + Vite 项目自动分析源码并生成高质量测试。支持 Vitest + @testing-library/react，覆盖纯函数、组件、Hook、Zustand store、API mock，以及可选的 Playwright E2E。当用户需要为前端代码生成测试、配置 Vitest、补充测试覆盖、或询问 React 组件/Hook 如何测试时，必须使用此技能。
version: 0.1.0
---

# Frontend 测试生成器

智能分析 React/Vite 前端源码，生成高质量测试代码。

## When to Activate

- 为 React 组件/Hook/工具函数生成测试时
- 配置 Vitest 测试环境时
- 已有测试但覆盖不足时
- 询问「怎么测这个组件/函数」时

## 工作流程

### Step 1: 检测项目结构

读取以下文件，自动识别项目特征：

```
1. package.json      → 判断是否已有 vitest/jest，读取现有 scripts
2. vite.config.ts    → 获取路径别名（@/* 等），是否已有 test 配置
3. tsconfig.app.json → 确认 paths 别名
4. 目标文件          → 判断类型（纯函数 / 组件 / Hook / Store）
```

识别目标文件类型：

| 特征 | 类型 |
|------|------|
| 无 JSX，只有函数导出 | 纯函数 → `pure_function_test.md` |
| 返回 JSX 的函数组件 | 组件 → `component_test.md` |
| 以 `use` 开头的函数 | Hook → `hook_test.md` |
| 使用 `create()` from zustand | Store → `store_test.md` |
| 调用 fetch / axios / API 模块 | 需搭配 `api_mock.md` |

### Step 2: 配置测试环境（仅首次）

若 `package.json` 中无 `vitest` 依赖，执行环境配置：

参考 `patterns/vitest_setup.md`，完成：
1. 安装依赖
2. 修改 `vite.config.ts` 添加 test 配置
3. 在 `package.json` 添加 `"test"` script
4. 创建 `src/test/setup.ts`（全局 setup）

### Step 3: 选择测试模式

| 文件特征 | 模式文件 |
|---------|---------|
| 纯函数/工具函数（无 JSX） | `patterns/pure_function_test.md` |
| React 函数组件（< 200 行） | `patterns/component_test.md` |
| 自定义 Hook（use*） | `patterns/hook_test.md` |
| Zustand store | `patterns/store_test.md` |
| 含 API 调用 | `patterns/api_mock.md` |
| **800+ 行重型页面，依赖第三方 UI 运行时** | **`patterns/page_test.md`** |
| 完整用户流程（可选） | `patterns/e2e_playwright.md` |

### Step 4: 生成测试代码

按 AAA 模式（Arrange-Act-Assert）生成：

```typescript
// 1. Arrange：准备数据和 mock
vi.mock('@/api/modules/provider')
const mockData = { ... }

// 2. Act：执行被测逻辑
render(<MyComponent />)
await userEvent.click(screen.getByRole('button'))

// 3. Assert：验证结果
expect(screen.getByText('expected')).toBeInTheDocument()
```

测试覆盖清单：
- 正常路径（happy path）
- 空值/undefined 输入
- 错误/异常状态
- loading 状态（异步组件）
- 边界值

### Step 5: 验证与修复

生成后检查常见问题：

| 问题 | 解决方案 |
|------|---------|
| 路径别名不识别（`@/`） | 确认 vite.config.ts 中 test.alias 配置 |
| Less/CSS Module 报错 | 添加 `moduleNameMapper` 或 css mock |
| 外部库（如 antd）副作用报错 | 在 setup.ts 中 mock |
| `window` / `document` 未定义 | 确认 `environment: 'jsdom'` |
| 异步断言未等待 | 使用 `waitFor` / `findBy*` |

详见 `patterns/test_debugging.md`

---

## 模式参考

| 模式文件 | 适用场景 |
|---------|---------|
| `patterns/vitest_setup.md` | 初始化配置 |
| `patterns/pure_function_test.md` | 工具函数测试（最高 ROI） |
| `patterns/component_test.md` | React 组件渲染与交互 |
| `patterns/hook_test.md` | 自定义 Hook 测试 |
| `patterns/api_mock.md` | API/fetch mock |
| `patterns/store_test.md` | Zustand store 测试 |
| `patterns/page_test.md` | 复杂页面测试（openclaw factory 模式，800+ 行依赖外部运行时） |
| `patterns/e2e_playwright.md` | Playwright E2E（可选） |
| `patterns/test_debugging.md` | 调试与常见问题 |

## Fixtures

`fixtures/common_setup.ts` 提供通用渲染封装：

| 工具 | 用途 |
|------|------|
| `renderWithProviders` | 带 Router + Theme + i18n 的完整渲染 |
| `createMockStore` | 创建隔离的 Zustand store 实例 |

## 参考资源

- Vitest 官方文档：https://vitest.dev/
- Testing Library：https://testing-library.com/docs/react-testing-library/intro/
- Playwright：https://playwright.dev/

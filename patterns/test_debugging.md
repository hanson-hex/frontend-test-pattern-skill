# 测试调试与常见问题

---

## Worktree 与源分支的函数差异

**场景**：在 worktree（基于 `main`）里写测试，但某些函数只存在于开发分支（如 `test/channel`），stash pop 后测试报 `is not a function`。

**原因**：worktree 切出时基于 `main`，stash 里的测试引用了尚未合并到 `main` 的函数。

**解决**：
- 检查目标函数在当前 worktree 分支是否真实导出：`grep "export function extractXxx" src/pages/Chat/utils.ts`
- 若不存在，暂时移除该函数的测试，待分支合并后补充

**预防**：创建 worktree 时，从包含目标代码的分支切出，而非从 main：
```bash
git worktree add .claude/worktrees/feat-test -b feat/vitest-setup test/channel
```

---

## 旧测试用 node:test 与 Vitest 冲突

**症状**：`Cannot bundle built-in module "node:test"`

**场景**：项目中存量测试用了 `import { describe, it } from "node:test"`，在 Vitest 环境下报错。

**解决**：在 `vite.config.ts` 的 test 配置中 exclude 掉这些文件，等后续迁移：

```typescript
test: {
  exclude: [
    "**/node_modules/**",
    "**/dist/**",
    "**/testConnectionMessage.test.ts",  // 旧 node:test 格式，待迁移
  ],
}
```

迁移时只需将 `import { describe, it } from "node:test"` 改为 Vitest 的 globals（配置 `globals: true` 后无需 import）。

---

## 路径别名不识别

**症状**：`Cannot find module '@/api/...'`

**原因**：vitest.config.ts 没有继承 vite.config.ts 的 alias。

**解决**：

```typescript
// vite.config.ts
import path from 'path'

export default defineConfig({
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  test: {
    // Vitest 通常自动继承，如不生效，显式添加：
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
```

---

## Less / CSS Module 报错

**症状**：`Failed to transform ... SyntaxError: Unexpected token`

**解决 A**：在 vite.config.ts 中配置 `css: true`（默认已开启，若关闭了需打开）。

**解决 B**：在 setup.ts 中全局 mock：

```typescript
// src/test/setup.ts
vi.mock('*.module.less', () => ({}))
vi.mock('*.less', () => ({}))
```

**解决 C**：使用 `identity-obj-proxy`（Jest 社区方案，Vitest 也可用）：

```bash
npm i -D identity-obj-proxy
```

```typescript
// vite.config.ts
test: {
  css: false,
  moduleNameMapper: {
    '\\.less$': 'identity-obj-proxy',
  },
}
```

---

## window / document 未定义

**症状**：`ReferenceError: window is not defined`

**原因**：environment 未设置为 jsdom。

**解决**：

```typescript
// vite.config.ts
test: {
  environment: 'jsdom',
}
```

或在测试文件顶部添加注释（单文件生效）：

```typescript
// @vitest-environment jsdom
```

---

## matchMedia 报错

**症状**：`TypeError: window.matchMedia is not a function`（antd 常见）

**解决**：在 setup.ts 中 mock：

```typescript
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})
```

---

## ResizeObserver 未定义

**症状**：`ReferenceError: ResizeObserver is not defined`（antd 虚拟列表常见）

**解决**：

```typescript
// src/test/setup.ts
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}))
```

---

## 异步测试超时

**症状**：`Error: Timeout - Async function did not complete within 5000ms`

**解决 A**：增加超时时间：

```typescript
it('慢速操作', async () => {
  // ...
}, 10_000)  // 10 秒超时
```

**解决 B**：确认使用了正确的异步查询方式：

```typescript
// ❌ 可能超时：getBy* 是同步的，元素不存在立即报错
screen.getByText('加载中')

// ✅ 正确：findBy* 会轮询等待
await screen.findByText('加载完成')

// ✅ 或用 waitFor
await waitFor(() => {
  expect(screen.getByText('加载完成')).toBeInTheDocument()
})
```

---

## act 警告

**症状**：`Warning: An update to X inside a test was not wrapped in act(...)`

**解决**：将触发状态更新的操作包裹在 `act`：

```typescript
import { act } from '@testing-library/react'

act(() => {
  store.setState({ value: 'new' })
})
// 或异步版本
await act(async () => {
  await someAsyncAction()
})
```

> `userEvent` 的操作已内置 `act`，无需手动包裹。

---

## vi.mock 不生效

**症状**：mock 了模块，但测试中仍调用真实实现。

**可能原因 1**：mock factory 中用了外部变量（hoist 问题）：

```typescript
// ❌ 错误
const mockFn = vi.fn()
vi.mock('@/api', () => ({ api: { call: mockFn } }))  // mockFn 在 hoist 前未定义

// ✅ 正确：factory 内直接用 vi.fn()
vi.mock('@/api', () => ({ api: { call: vi.fn() } }))
```

**可能原因 2**：模块路径不完全一致（相对路径 vs 别名）：

```typescript
// 源码中用了相对路径
import { chatApi } from '../../api/modules/chat'

// mock 要用相同路径或别名
vi.mock('@/api/modules/chat', ...)  // ← 可能不匹配
// 改为：
vi.mock('../../api/modules/chat', ...)
```

---

## 外部库副作用报错

**症状**：导入 `@agentscope-ai/chat` 等外部库时报错。

**解决**：在 setup.ts 或测试文件顶部 mock 整个包：

```typescript
vi.mock('@agentscope-ai/chat', () => ({
  AgentScopeRuntimeWebUI: vi.fn(() => null),
  useChatAnywhere: vi.fn(() => ({ createSession: vi.fn() })),
}))
```

---

## 调试技巧

**打印 DOM 结构**：

```typescript
import { prettyDOM } from '@testing-library/react'
console.log(prettyDOM(document.body))
// 或
screen.debug()
```

**查看所有可用查询**：

```typescript
screen.logTestingPlaygroundURL()  // 输出 Testing Playground 链接
```

**单独运行一个测试**：

```bash
npx vitest run src/pages/Chat/__tests__/utils.test.ts
```

**监听特定文件**：

```bash
npx vitest src/pages/Chat
```

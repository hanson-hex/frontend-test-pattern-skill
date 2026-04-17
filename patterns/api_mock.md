# API Mock 模式

前端测试隔离外部 API 调用的两种方案：
- **vi.mock**：轻量，适合单元/组件测试
- **msw**：重量级，适合集成测试和复杂场景

---

## 方案一：vi.mock（推荐首选）

### 基础用法

```typescript
import { vi, describe, it, expect, beforeEach } from 'vitest'

// mock 整个模块（放在文件顶部，Vitest 会自动 hoist）
vi.mock('@/api/modules/provider', () => ({
  providerApi: {
    listProviders: vi.fn(),
    getActiveModels: vi.fn(),
    setActiveLlm: vi.fn(),
  },
}))

// 引入时已是 mock 版本
import { providerApi } from '@/api/modules/provider'
```

### 配置返回值

```typescript
describe('ModelSelector', () => {
  beforeEach(() => {
    vi.mocked(providerApi.listProviders).mockResolvedValue([
      { id: 'openai', name: 'OpenAI', models: ['gpt-4', 'gpt-3.5-turbo'] },
      { id: 'anthropic', name: 'Anthropic', models: ['claude-3-opus'] },
    ])
  })

  afterEach(() => {
    vi.clearAllMocks()  // 清理 mock 调用记录
  })

  it('加载 provider 列表', async () => {
    renderWithProviders(<ModelSelector />)
    expect(await screen.findByText('OpenAI')).toBeInTheDocument()
    expect(providerApi.listProviders).toHaveBeenCalledOnce()
  })
})
```

### 模拟错误

```typescript
it('请求失败时显示错误提示', async () => {
  vi.mocked(providerApi.listProviders).mockRejectedValue(
    new Error('Network error'),
  )

  renderWithProviders(<ModelSelector />)
  expect(await screen.findByText(/加载失败/i)).toBeInTheDocument()
})
```

### 模拟 loading 挂起

```typescript
it('显示 loading 状态', () => {
  vi.mocked(providerApi.listProviders).mockImplementation(
    () => new Promise(() => {}),  // 永不 resolve
  )

  renderWithProviders(<ModelSelector />)
  expect(screen.getByRole('progressbar')).toBeInTheDocument()
})
```

### 验证调用参数

```typescript
it('切换模型时传入正确参数', async () => {
  vi.mocked(providerApi.setActiveLlm).mockResolvedValue(undefined)
  // ...
  expect(providerApi.setActiveLlm).toHaveBeenCalledWith('openai', 'gpt-4')
})
```

---

## 方案二：msw（Mock Service Worker）

适合需要测试 HTTP 请求层本身，或多个测试共享同一套 mock server 的情况。

### 安装

```bash
npm i -D msw
```

### 配置 handlers

```typescript
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/providers', () => {
    return HttpResponse.json([
      { id: 'openai', name: 'OpenAI' },
    ])
  }),

  http.post('/api/llm/set', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ success: true, model: body })
  }),

  // 模拟错误
  http.get('/api/providers/error', () => {
    return HttpResponse.json({ message: 'Server Error' }, { status: 500 })
  }),
]
```

### 配置 server

```typescript
// src/test/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

### 在 setup.ts 中全局启用

```typescript
// src/test/setup.ts
import { server } from './mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

### 测试中覆盖 handler

```typescript
it('处理 500 错误', async () => {
  server.use(
    http.get('/api/providers', () =>
      HttpResponse.json({ message: 'error' }, { status: 500 }),
    ),
  )

  renderWithProviders(<ModelSelector />)
  expect(await screen.findByText(/加载失败/)).toBeInTheDocument()
})
```

---

## 选择方案

| 场景 | 推荐 |
|------|------|
| 组件/Hook 单元测试 | `vi.mock` |
| 测试 fetch/axios 层本身 | msw |
| 多组件共享同一套接口 mock | msw |
| 需要测试 loading/error/success 三态 | `vi.mock`（更简单） |
| CI 速度优先 | `vi.mock`（无网络开销） |

---

## 常见陷阱

**mock 未 hoist**

vi.mock 会自动 hoist（提升）到文件顶部，但 `vi.fn()` 的初始化引用必须在 mock factory 内：

```typescript
// ✅ 正确：factory 内创建
vi.mock('@/api/modules/chat', () => ({
  chatApi: { filePreviewUrl: vi.fn() },
}))

// ❌ 错误：外部变量在 hoist 前不可用
const mockFn = vi.fn()
vi.mock('@/api/modules/chat', () => ({
  chatApi: { filePreviewUrl: mockFn },  // 报错：mockFn is not defined
}))
```

**清理 mock 状态**

每个测试后清理，防止相互干扰：

```typescript
afterEach(() => {
  vi.clearAllMocks()   // 清理调用记录，保留 mock 实现
  // vi.resetAllMocks() // 清理调用记录 + 重置实现
  // vi.restoreAllMocks() // 还原 spy（用于 vi.spyOn）
})
```

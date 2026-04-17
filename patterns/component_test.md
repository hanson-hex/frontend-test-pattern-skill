# React 组件测试模式

使用 `@testing-library/react` 测试组件的渲染输出与用户交互。

核心原则：**测试用户能看到的，而不是实现细节。**

---

## 基础结构

```typescript
import { describe, it, expect, vi } from 'vitest'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders } from '@/test/common_setup'
import { MyComponent } from '../MyComponent'

describe('MyComponent', () => {
  it('渲染默认状态', () => {
    renderWithProviders(<MyComponent />)
    expect(screen.getByRole('button', { name: '提交' })).toBeInTheDocument()
  })

  it('点击按钮触发回调', async () => {
    const user = userEvent.setup()
    const onSubmit = vi.fn()

    renderWithProviders(<MyComponent onSubmit={onSubmit} />)
    await user.click(screen.getByRole('button', { name: '提交' }))

    expect(onSubmit).toHaveBeenCalledOnce()
  })
})
```

---

## renderWithProviders

组件通常依赖 Router、Theme、i18n。用封装好的 `renderWithProviders` 代替裸 `render`：

```typescript
// src/test/common_setup.tsx
import { render, type RenderOptions } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { ReactNode } from 'react'

function AllProviders({ children }: { children: ReactNode }) {
  return (
    <MemoryRouter>
      {/* 若有 ThemeProvider/i18n Provider，在此包裹 */}
      {children}
    </MemoryRouter>
  )
}

export function renderWithProviders(
  ui: React.ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>,
) {
  return render(ui, { wrapper: AllProviders, ...options })
}
```

---

## screen 查询优先级

按可访问性从高到低选择查询方式：

```
1. getByRole('button', { name: '...' })     ← 最优先，语义化
2. getByLabelText('用户名')                  ← 表单控件
3. getByPlaceholderText('请输入...')         ← 次选
4. getByText('确认删除')                     ← 文本内容
5. getByTestId('submit-btn')               ← 最后手段，需在组件加 data-testid
```

---

## userEvent vs fireEvent

优先用 `userEvent`，它模拟真实用户行为（触发 focus、blur、键盘事件等）：

```typescript
const user = userEvent.setup()

// 点击
await user.click(screen.getByRole('button'))

// 输入文字
await user.type(screen.getByRole('textbox'), 'hello')

// 清空再输入
await user.clear(screen.getByRole('textbox'))
await user.type(screen.getByRole('textbox'), 'new value')

// 键盘快捷键
await user.keyboard('{Enter}')
await user.keyboard('{ArrowDown}')
```

`fireEvent` 只用于不支持 userEvent 的场景（如自定义合成事件）：

```typescript
import { fireEvent } from '@testing-library/react'
fireEvent.change(input, { target: { value: 'test' } })
```

---

## 异步组件测试

含异步操作的组件（数据加载、请求）需等待状态变化：

```typescript
import { waitFor, screen } from '@testing-library/react'
import { vi } from 'vitest'

// mock API
vi.mock('@/api/modules/provider', () => ({
  providerApi: {
    listProviders: vi.fn().mockResolvedValue([
      { id: '1', name: 'OpenAI' },
    ]),
  },
}))

it('加载完成后显示 provider 列表', async () => {
  renderWithProviders(<ModelSelector />)

  // 等待异步内容出现
  expect(await screen.findByText('OpenAI')).toBeInTheDocument()
})

it('加载中显示 loading 状态', async () => {
  // 让请求挂起
  vi.mocked(providerApi.listProviders).mockImplementation(
    () => new Promise(() => {}),
  )

  renderWithProviders(<ModelSelector />)
  expect(screen.getByRole('progressbar')).toBeInTheDocument()
})
```

---

## 实战示例：ChatActionGroup

```typescript
// ChatActionGroup/index.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders } from '@/test/common_setup'
import { ChatActionGroup } from '../ChatActionGroup'

// mock 外部 hook
vi.mock('@agentscope-ai/chat', () => ({
  useChatAnywhere: vi.fn(() => ({
    createSession: vi.fn(),
  })),
}))

describe('ChatActionGroup', () => {
  const user = userEvent.setup()

  it('渲染新建对话按钮', () => {
    renderWithProviders(<ChatActionGroup />)
    expect(screen.getByRole('button', { name: /新建/i })).toBeInTheDocument()
  })

  it('点击搜索按钮触发搜索回调', async () => {
    const onSearch = vi.fn()
    renderWithProviders(<ChatActionGroup onSearch={onSearch} />)

    await user.click(screen.getByRole('button', { name: /搜索/i }))
    expect(onSearch).toHaveBeenCalledOnce()
  })
})
```

---

## 测试覆盖清单

为每个组件覆盖：

| 测试类型 | 示例 |
|---------|------|
| 默认渲染 | 关键元素是否存在 |
| props 变化 | 不同 props 渲染不同内容 |
| 用户交互 | 点击、输入、键盘 |
| 异步状态 | loading → 数据 → 错误 |
| 条件渲染 | 根据状态显示/隐藏 |
| 回调调用 | onXxx 是否被调用，参数是否正确 |

---

## Icon 库的 Proxy Mock（零配置）

当项目使用大量图标组件（如 `@ant-design/icons`、`lucide-react`、`@agentscope-ai/icons`），逐一 mock 很繁琐。用 `Proxy` 动态生成：

```typescript
// src/test/setup.ts 或测试文件顶部
vi.mock('@ant-design/icons', () =>
  new Proxy(
    {},
    {
      get: (_, iconName: string) =>
        () => <span data-testid={`icon-${iconName}`} aria-label={iconName.toLowerCase().replace('outlined', '')} />,
    },
  ),
)
```

这样任何 `<SunOutlined />` 都会渲染为 `<span data-testid="icon-SunOutlined" aria-label="sun" />`，无需手动列举每个图标。

---

## 常见问题

**antd 组件渲染问题**

antd 部分组件（Modal、Tooltip）使用 Portal，渲染在 body 上。用 `screen.getByText` 仍可找到，无需特殊处理。

**测试 Select/Dropdown**

antd Select 比较特殊：

```typescript
// 打开下拉
await user.click(screen.getByRole('combobox'))
// 选择选项
await user.click(await screen.findByText('选项一'))
expect(screen.getByRole('combobox')).toHaveTextContent('选项一')
```

**snapshot 测试**

谨慎使用 snapshot，容易产生噪音。仅用于静态展示组件：

```typescript
it('匹配快照', () => {
  const { container } = renderWithProviders(<Badge count={5} />)
  expect(container).toMatchSnapshot()
})
```

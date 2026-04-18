# 复杂页面测试模式（Factory + Capture 模式）

适用于 800+ 行的重型页面组件，依赖第三方 UI 运行时、大量 hooks、多个 API 调用。

---

## 核心策略

### 1. 把第三方 UI 库整体 mock，只测页面自身逻辑

不要测第三方库的内部行为，mock 掉整个外部 UI 组件，捕获页面传给它的 props：

```typescript
let capturedProps: any = null

vi.mock('some-ui-library', () => ({
  HeavyUIComponent: vi.fn((props: any) => {
    capturedProps = props           // 捕获页面传入的所有 props/callbacks
    return (
      <div data-testid="ui-root">
        {props.config?.header}      // 渲染页面注入的子组件，让它们出现在 DOM 里
      </div>
    )
  }),
  useSomeHook: vi.fn(() => ({ setValue: vi.fn(), getValue: vi.fn() })),
}))
```

### 2. 直接调用 captured callbacks 测业务逻辑

这是本模式的精髓：**不通过 UI 模拟触发，直接调用页面传给外部组件的回调函数**，绕开第三方 UI。

```typescript
it('API 返回错误时显示错误弹窗', async () => {
  mockFetchData.mockRejectedValue(new Error('network'))
  renderWithProviders(<MyPage />)
  await screen.findByTestId('ui-root')

  // 直接调用页面注入的 fetch 回调
  const response = await capturedProps.api.fetch({ input: [] })
  expect(response.status).toBe(400)
  expect(await screen.findByTestId('error-modal')).toBeInTheDocument()
})

it('文件超限时调用 onError', async () => {
  renderWithProviders(<MyPage />)
  await screen.findByTestId('ui-root')

  const bigFile = new File([new ArrayBuffer(11 * 1024 * 1024)], 'big.bin')
  const onError = vi.fn()
  await capturedProps.upload.customRequest({ file: bigFile, onError })
  expect(onError).toHaveBeenCalledOnce()
})
```

### 3. Factory 函数构造完整默认状态

用 factory 构建默认状态，每个 test 只 override 关心的部分：

```typescript
// 默认 mock 数据（合理的"一切正常"状态）
const defaultState = {
  activeModel: { provider_id: 'openai', model: 'gpt-4' },
  providers: [{ id: 'openai', models: [{ id: 'gpt-4', name: 'GPT-4' }] }],
}

beforeEach(() => {
  capturedProps = null
  mockGetActiveModel.mockResolvedValue(defaultState.activeModel)
  mockListProviders.mockResolvedValue(defaultState.providers)
})

// 每个 test 只改一项
it('未配置时显示配置引导', async () => {
  mockGetActiveModel.mockResolvedValue(null)  // ← 只改这一行
  // ...
})
```

### 4. 测行为，不测渲染结果

| ✅ 值得测（行为）| ❌ 不值得测（实现细节）|
|---|---|
| 条件 X 满足时 API 被调用 | 渲染了多少个 div |
| 事件触发后状态变化 | 某个 CSS class 是否存在 |
| 错误发生时错误提示出现 | 子组件的内部渲染 |
| 回调被调用且参数正确 | 具体的 HTML 结构 |

---

## 完整模板

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { screen, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders } from '@/test/common_setup'
import MyPage from '../index'

// ---------------------------------------------------------------------------
// Step 1: 捕获外部 UI 组件的 props
// ---------------------------------------------------------------------------
let capturedProps: any = null

const { mockFetchData, mockSubmit } = vi.hoisted(() => ({
  mockFetchData: vi.fn(),
  mockSubmit: vi.fn(),
}))

vi.mock('some-heavy-ui-lib', () => ({
  HeavyUIComponent: vi.fn((props: any) => {
    capturedProps = props
    return <div data-testid="ui-root">{props.config?.header}</div>
  }),
  useLibHook: vi.fn(() => ({ setLoading: vi.fn() })),
}))

// ---------------------------------------------------------------------------
// Step 2: mock 所有 API 和依赖
// ---------------------------------------------------------------------------
vi.mock('@/api/modules/data', () => ({
  dataApi: { fetch: mockFetchData, submit: mockSubmit },
}))

// mock UI 框架 Modal（避免 CSS 动画导致 DOM 残留）
vi.mock('antd', async (importOriginal) => {
  const actual = await importOriginal<typeof import('antd')>()
  return {
    ...actual,
    Modal: ({ open, children }: any) =>
      open ? <div data-testid="modal">{children}</div> : null,
  }
})

// mock 子组件，让页面测试聚焦在页面逻辑
vi.mock('../components/SubComponent', () => ({
  default: () => <div data-testid="sub-component" />,
}))

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (k: string) => k }),
}))

// ---------------------------------------------------------------------------
// Step 3: factory + tests
// ---------------------------------------------------------------------------
describe('MyPage', () => {
  beforeEach(() => {
    capturedProps = null
    mockFetchData.mockResolvedValue({ data: [] })
    mockSubmit.mockResolvedValue({ ok: true })
  })

  afterEach(() => vi.clearAllMocks())

  it('renders without crash', async () => {
    renderWithProviders(<MyPage />)
    expect(await screen.findByTestId('ui-root')).toBeInTheDocument()
  })

  it('挂载时调用 fetchData', async () => {
    renderWithProviders(<MyPage />)
    await screen.findByTestId('ui-root')
    await waitFor(() => expect(mockFetchData).toHaveBeenCalled())
  })

  it('数据加载失败时显示错误 modal', async () => {
    mockFetchData.mockRejectedValue(new Error('network'))
    renderWithProviders(<MyPage />)
    await screen.findByTestId('ui-root')

    const response = await capturedProps.api.fetch({ input: [] })
    expect(response.status).toBe(400)
    expect(await screen.findByTestId('modal')).toBeInTheDocument()
  })

  it('某个全局事件触发后重新 fetch', async () => {
    renderWithProviders(<MyPage />)
    await screen.findByTestId('ui-root')
    await waitFor(() => expect(mockFetchData).toHaveBeenCalled())
    const callsBefore = mockFetchData.mock.calls.length

    act(() => { window.dispatchEvent(new CustomEvent('data-updated')) })

    await waitFor(() =>
      expect(mockFetchData.mock.calls.length).toBeGreaterThan(callsBefore),
    )
  })
})
```

---

## 大量依赖的 mock 组织方式

用 `vi.hoisted()` 统一声明，避免 hoist 导致的初始化顺序问题：

```typescript
const {
  mockFetchData,
  mockSubmit,
  mockNavigate,
  mockSelectedItem,
} = vi.hoisted(() => ({
  mockFetchData: vi.fn(),
  mockSubmit: vi.fn(),
  mockNavigate: vi.fn(),
  mockSelectedItem: vi.fn(() => 'default'),
}))
```

子组件全部简化为 `data-testid` div：
```typescript
vi.mock('../SubA', () => ({ default: () => <div data-testid="sub-a" /> }))
vi.mock('../SubB', () => ({ default: () => <div data-testid="sub-b" /> }))
```

---

## 何时用本模式 vs component_test

| 场景 | 推荐模式 |
|---|---|
| 纯展示组件（< 200 行，无复杂 hook） | `component_test.md` |
| 有 API 调用的中型组件 | `component_test.md` + `api_mock.md` |
| 依赖第三方 UI 运行时的重型页面（800+ 行） | **本文件** |
| 跨页面完整用户流程 | `e2e_playwright.md` |

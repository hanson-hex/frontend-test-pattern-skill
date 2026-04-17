# 自定义 Hook 测试模式

使用 `renderHook`（@testing-library/react 内置）测试自定义 Hook 的状态和行为。

---

## 基础结构

```typescript
import { describe, it, expect, vi } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useMyHook } from '../useMyHook'

describe('useMyHook', () => {
  it('初始状态正确', () => {
    const { result } = renderHook(() => useMyHook())
    expect(result.current.value).toBe(0)
  })

  it('调用 increment 后值加一', () => {
    const { result } = renderHook(() => useMyHook())

    act(() => {
      result.current.increment()
    })

    expect(result.current.value).toBe(1)
  })
})
```

> **规则**：所有会引起状态更新的操作必须包裹在 `act(...)` 中，否则 React 会警告。

---

## 带参数的 Hook

```typescript
it('接受初始值', () => {
  const { result } = renderHook(() => useCounter(10))
  expect(result.current.value).toBe(10)
})
```

---

## 异步 Hook

```typescript
import { waitFor } from '@testing-library/react'

it('异步加载数据', async () => {
  vi.mock('@/api/modules/provider', () => ({
    providerApi: {
      listModels: vi.fn().mockResolvedValue(['gpt-4', 'claude-3']),
    },
  }))

  const { result } = renderHook(() => useModelList())

  // 初始为 loading
  expect(result.current.loading).toBe(true)

  // 等待加载完成
  await waitFor(() => {
    expect(result.current.loading).toBe(false)
  })

  expect(result.current.models).toEqual(['gpt-4', 'claude-3'])
})
```

---

## 实战示例：useIMEComposition

`useIMEComposition` 追踪 IME 输入法组合状态（中文输入法的候选词阶段）：

```typescript
import { renderHook, act } from '@testing-library/react'
import { useIMEComposition } from '../useIMEComposition'

describe('useIMEComposition', () => {
  it('初始状态 isComposing 为 false', () => {
    const { result } = renderHook(() => useIMEComposition())
    expect(result.current.isComposing).toBe(false)
  })

  it('compositionstart 时 isComposing 变为 true', () => {
    const { result } = renderHook(() => useIMEComposition())

    act(() => {
      result.current.handlers.onCompositionStart()
    })

    expect(result.current.isComposing).toBe(true)
  })

  it('compositionend 时 isComposing 变回 false', () => {
    const { result } = renderHook(() => useIMEComposition())

    act(() => {
      result.current.handlers.onCompositionStart()
      result.current.handlers.onCompositionEnd()
    })

    expect(result.current.isComposing).toBe(false)
  })
})
```

---

## 实战示例：useMessageHistoryNavigation

```typescript
describe('useMessageHistoryNavigation', () => {
  const messages = ['第一条', '第二条', '第三条']

  it('初始索引为 -1（未选中）', () => {
    const { result } = renderHook(() =>
      useMessageHistoryNavigation(messages),
    )
    expect(result.current.currentIndex).toBe(-1)
  })

  it('ArrowUp 向前翻', () => {
    const { result } = renderHook(() =>
      useMessageHistoryNavigation(messages),
    )

    act(() => {
      result.current.navigateUp()
    })

    expect(result.current.currentMessage).toBe('第三条')
  })

  it('到达顶部后不再继续', () => {
    const { result } = renderHook(() =>
      useMessageHistoryNavigation(messages),
    )

    act(() => {
      result.current.navigateUp()
      result.current.navigateUp()
      result.current.navigateUp()
      result.current.navigateUp() // 超出范围
    })

    expect(result.current.currentIndex).toBe(2) // 最大索引
  })
})
```

---

## 带 Providers 的 Hook

Hook 依赖 Context 时，通过 `wrapper` 提供：

```typescript
import { renderHook } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

function wrapper({ children }: { children: ReactNode }) {
  return <MemoryRouter>{children}</MemoryRouter>
}

it('从路由读取参数', () => {
  const { result } = renderHook(() => useRouteParams(), { wrapper })
  // ...
})
```

---

## rerender 测试 props 变化

```typescript
it('props 更新时重新计算', () => {
  const { result, rerender } = renderHook(
    ({ value }) => useFormattedValue(value),
    { initialProps: { value: 100 } },
  )

  expect(result.current).toBe('100')

  rerender({ value: 2000 })
  expect(result.current).toBe('2,000')
})
```

---

## 清理副作用

Hook 有 `useEffect` 时，确认 unmount 后正确清理：

```typescript
it('unmount 时清理定时器', () => {
  const clearIntervalSpy = vi.spyOn(global, 'clearInterval')
  const { unmount } = renderHook(() => usePolling())

  unmount()
  expect(clearIntervalSpy).toHaveBeenCalled()
})
```

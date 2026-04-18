# Custom Hook Testing

Test custom hooks using `renderHook` (built into `@testing-library/react`).

---

## Basic Structure

```typescript
import { describe, it, expect, vi } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useMyHook } from '../useMyHook'

describe('useMyHook', () => {
  it('has correct initial state', () => {
    const { result } = renderHook(() => useMyHook())
    expect(result.current.value).toBe(0)
  })

  it('increments value by 1 when increment is called', () => {
    const { result } = renderHook(() => useMyHook())

    act(() => {
      result.current.increment()
    })

    expect(result.current.value).toBe(1)
  })
})
```

> **Rule**: All operations that trigger state updates must be wrapped in `act(...)`, otherwise React will warn.

---

## Hook with Parameters

```typescript
it('accepts an initial value', () => {
  const { result } = renderHook(() => useCounter(10))
  expect(result.current.value).toBe(10)
})
```

---

## Async Hook

```typescript
import { waitFor } from '@testing-library/react'

it('loads data asynchronously', async () => {
  vi.mock('@/api/modules/data', () => ({
    dataApi: {
      list: vi.fn().mockResolvedValue(['item-1', 'item-2']),
    },
  }))

  const { result } = renderHook(() => useDataList())

  expect(result.current.loading).toBe(true)

  await waitFor(() => {
    expect(result.current.loading).toBe(false)
  })

  expect(result.current.items).toEqual(['item-1', 'item-2'])
})
```

---

## Hook with Context (Providers)

When a hook depends on Context, provide it via the `wrapper` option:

```typescript
import { renderHook } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

function wrapper({ children }: { children: ReactNode }) {
  return <MemoryRouter>{children}</MemoryRouter>
}

it('reads params from the route', () => {
  const { result } = renderHook(() => useRouteParams(), { wrapper })
  // ...
})
```

---

## Testing Props Changes with rerender

```typescript
it('recalculates when props change', () => {
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

## Cleanup / Side Effects

Verify cleanup runs correctly on unmount:

```typescript
it('clears timer on unmount', () => {
  const clearIntervalSpy = vi.spyOn(global, 'clearInterval')
  const { unmount } = renderHook(() => usePolling())

  unmount()
  expect(clearIntervalSpy).toHaveBeenCalled()
})
```

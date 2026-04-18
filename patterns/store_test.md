# Zustand Store Testing

Test store state transitions directly without rendering any component.

---

## Basic Structure

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { act } from '@testing-library/react'
import { useMyStore } from '@/stores/myStore'

describe('myStore', () => {
  beforeEach(() => {
    useMyStore.setState({ selectedItem: null, items: [] })
  })

  it('has correct initial state', () => {
    expect(useMyStore.getState().selectedItem).toBeNull()
  })

  it('setSelectedItem updates selectedItem', () => {
    act(() => {
      useMyStore.getState().setSelectedItem({ id: '1', name: 'Test' })
    })
    expect(useMyStore.getState().selectedItem?.id).toBe('1')
  })
})
```

---

## Isolated Tests (recommended)

Use `setState` to reset to initial values before each test to prevent state leaking between tests:

```typescript
beforeEach(() => {
  useMyStore.setState({
    selectedItem: null,
    items: [],
  })
})
```

If the store exports a factory function (non-singleton):

```typescript
import { createMyStore } from '@/stores/myStore'

describe('myStore (isolated)', () => {
  let store: ReturnType<typeof createMyStore>

  beforeEach(() => {
    store = createMyStore()
  })

  it('initial items is empty array', () => {
    expect(store.getState().items).toEqual([])
  })
})
```

---

## Store + Component Integration

```typescript
import { renderWithProviders } from '@/test/common_setup'
import { useMyStore } from '@/stores/myStore'

it('component renders item name from store', () => {
  useMyStore.setState({ selectedItem: { id: '1', name: 'My Item' } })

  renderWithProviders(<ItemHeader />)
  expect(screen.getByText('My Item')).toBeInTheDocument()
})
```

---

## Async Actions

```typescript
it('fetchItems loads data into the store', async () => {
  vi.mock('@/api/modules/items', () => ({
    itemsApi: {
      list: vi.fn().mockResolvedValue([{ id: '1', name: 'Item A' }]),
    },
  }))

  await act(async () => {
    await useMyStore.getState().fetchItems()
  })

  expect(useMyStore.getState().items).toHaveLength(1)
  expect(useMyStore.getState().items[0].name).toBe('Item A')
})
```

---

## Coverage Checklist

| Test type | Description |
|---|---|
| Initial state | Verify store initial values |
| Sync actions | State changes immediately after call |
| Async actions | loading / data / error three states |
| Reset / clear | reset or clear actions |
| Derived state (selectors) | Computed values are correct |

# React Component Testing

Test component render output and user interactions using `@testing-library/react`.

Core principle: **test what the user sees, not implementation details.**

---

## Basic Structure

```typescript
import { describe, it, expect, vi } from 'vitest'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithProviders } from '@/test/common_setup'
import { MyComponent } from '../MyComponent'

describe('MyComponent', () => {
  it('renders default state', () => {
    renderWithProviders(<MyComponent />)
    expect(screen.getByRole('button', { name: 'Submit' })).toBeInTheDocument()
  })

  it('triggers callback on button click', async () => {
    const user = userEvent.setup()
    const onSubmit = vi.fn()

    renderWithProviders(<MyComponent onSubmit={onSubmit} />)
    await user.click(screen.getByRole('button', { name: 'Submit' }))

    expect(onSubmit).toHaveBeenCalledOnce()
  })
})
```

---

## renderWithProviders

Components typically depend on Router, Theme, or i18n. Use `renderWithProviders` instead of bare `render`:

```typescript
// src/test/common_setup.tsx
import { render, type RenderOptions } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { ReactNode } from 'react'

function AllProviders({ children }: { children: ReactNode }) {
  return (
    <MemoryRouter>
      {/* add ThemeProvider / i18n Provider here as needed */}
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

## Query Priority

Choose queries from highest to lowest accessibility priority:

```
1. getByRole('button', { name: '...' })   ← best, semantic
2. getByLabelText('Username')              ← form controls
3. getByPlaceholderText('Enter...')        ← fallback
4. getByText('Confirm Delete')             ← text content
5. getByTestId('submit-btn')              ← last resort, add data-testid to component
```

---

## userEvent vs fireEvent

Prefer `userEvent` — it simulates real user behavior (triggers focus, blur, keyboard events):

```typescript
const user = userEvent.setup()

await user.click(screen.getByRole('button'))
await user.type(screen.getByRole('textbox'), 'hello')
await user.clear(screen.getByRole('textbox'))
await user.keyboard('{Enter}')
await user.keyboard('{ArrowDown}')
```

Use `fireEvent` only for cases `userEvent` cannot handle (e.g. custom synthetic events):

```typescript
import { fireEvent } from '@testing-library/react'
fireEvent.change(input, { target: { value: 'test' } })

// CSS hidden elements (pointer-events: none) require fireEvent
fireEvent.click(screen.getByTestId('hidden-btn').closest('button')!)
```

---

## Async Components

Components with data loading need to wait for state changes:

```typescript
vi.mock('@/api/modules/data', () => ({
  dataApi: {
    list: vi.fn().mockResolvedValue([{ id: '1', name: 'Item A' }]),
  },
}))

it('shows list after loading', async () => {
  renderWithProviders(<DataList />)
  expect(await screen.findByText('Item A')).toBeInTheDocument()
})

it('shows loading state', () => {
  vi.mocked(dataApi.list).mockImplementation(() => new Promise(() => {}))
  renderWithProviders(<DataList />)
  expect(screen.getByRole('progressbar')).toBeInTheDocument()
})
```

---

## Coverage Checklist

| Test type | Example |
|---|---|
| Default render | Key elements are present |
| Props variations | Different props produce different output |
| User interactions | Click, type, keyboard |
| Async states | loading → data → error |
| Conditional render | Show/hide based on state |
| Callback invocation | onXxx called with correct args |

---

## Icon Library Proxy Mock (zero-config)

When a project uses many icon components, mocking them one by one is tedious. Use `Proxy` to generate mocks dynamically:

```typescript
// src/test/setup.ts or top of test file
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

Any `<SunOutlined />` renders as `<span data-testid="icon-SunOutlined" aria-label="sun" />` without listing each icon explicitly.

---

## antd Modal CSS Animation Issue

antd Modal keeps content in DOM during CSS exit animation. jsdom never completes the animation, so `queryByText` still finds the button. Fix by mocking Modal to conditionally render:

```typescript
vi.mock('antd', async (importOriginal) => {
  const actual = await importOriginal<typeof import('antd')>()
  return {
    ...actual,
    Modal: ({ open, children }: any) =>
      open ? <div data-testid="modal">{children}</div> : null,
  }
})
```

## antd Dropdown: Multiple Elements Found

When a Dropdown is open, the trigger button and dropdown panel both contain the same text:

```typescript
// Option A: use getAllByText + index
const items = screen.getAllByText('GPT-4')
await user.click(items[items.length - 1])  // click item inside dropdown

// Option B: narrow scope with within
import { within } from '@testing-library/react'
const panel = screen.getByRole('menu')
await user.click(within(panel).getByText('GPT-4'))
```

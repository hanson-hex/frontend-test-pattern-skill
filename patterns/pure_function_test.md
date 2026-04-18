# Pure Function Testing

For utility functions with no JSX and no side effects (`utils.ts`, `helpers.ts`, etc.).
This is the **highest ROI** test type: zero mocks, fast execution, clear assertions.

---

## Basic Structure

```typescript
import { describe, it, expect } from 'vitest'
import { myFunction } from '../utils'

describe('myFunction', () => {
  it('returns expected result for valid input', () => {
    // Arrange
    const input = { ... }

    // Act
    const result = myFunction(input)

    // Assert
    expect(result).toBe('expected')
  })

  it('returns default value for empty input', () => {
    expect(myFunction({})).toBe('')
  })
})
```

---

## Parameterized Tests (test.each)

Use `test.each` instead of repeating `it` blocks when testing the same function with multiple inputs:

```typescript
describe('toDisplayUrl', () => {
  test.each([
    // [description, input, expected]
    ['returns http URL as-is', 'http://example.com/img.png', 'http://example.com/img.png'],
    ['returns https URL as-is', 'https://cdn.com/file', 'https://cdn.com/file'],
    ['returns empty string for empty input', '', ''],
    ['returns empty string for undefined', undefined, ''],
    ['prepends prefix for relative path', '/uploads/img.png', expect.stringContaining('/uploads/img.png')],
  ])('%s', (_, input, expected) => {
    expect(toDisplayUrl(input)).toEqual(expected)
  })
})
```

---

## Edge Case Checklist

For each function, add tests for these boundary cases:

| Boundary | Test description |
|---|---|
| Empty string | `'empty string input'` |
| undefined / null | `'undefined input'` |
| Empty object/array | `'empty object input'` |
| Very long string | `'very long string input'` |
| Special characters | `'input with special characters'` |
| Deeply nested structure | `'deeply nested input'` |

---

## Functions with External Dependencies

When a utility imports an API module, mock it:

```typescript
// utils.ts
import { myApi } from '@/api/modules/data'
export function formatUrl(url: string): string {
  return myApi.getPreviewUrl(url)
}
```

Mock in the test:

```typescript
vi.mock('@/api/modules/data', () => ({
  myApi: {
    getPreviewUrl: vi.fn((path: string) => `http://mock-host${path}`),
  },
}))

describe('formatUrl', () => {
  it('prepends mock host for relative paths', () => {
    expect(formatUrl('/img.png')).toBe('http://mock-host/img.png')
  })

  it('returns http URLs unchanged', () => {
    expect(formatUrl('http://cdn.com/img.png')).toBe('http://cdn.com/img.png')
  })
})
```

---

## Vite `define` Globals

Vite's `define` config injects global constants. Set them via `globalThis` in tests:

```typescript
// vite.config.ts has: define: { VITE_API_BASE_URL: ... }
const setViteBase = (v: string) => { (globalThis as any).VITE_API_BASE_URL = v }

beforeEach(() => setViteBase(''))  // reset before each test
```

---

## Tips

- Pure function tests do **not** need `renderWithProviders` — call the function directly
- If a function uses `window` / `document`, jsdom provides them automatically
- Prefer `test.each` to reduce repetitive code
- Make assertions specific — avoid asserting only `toBeTruthy()`

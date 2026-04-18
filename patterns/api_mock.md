# API Mocking

Two approaches for isolating external API calls:
- **vi.mock**: lightweight, best for unit/component tests
- **msw**: heavier, best for integration tests and complex scenarios

---

## Testing the fetch wrapper layer

When unit testing a `request` / `fetch` wrapper itself, mock the global `fetch`:

```typescript
function mockFetch(status: number, body?: unknown, contentType = 'application/json') {
  global.fetch = vi.fn().mockResolvedValue({
    ok: status >= 200 && status < 300,
    status,
    statusText: 'OK',
    headers: { get: () => contentType },
    json: () => Promise.resolve(body),
    text: () => Promise.resolve(typeof body === 'string' ? body : JSON.stringify(body)),
  } as unknown as Response)
}

it('POST request adds Content-Type automatically', async () => {
  mockFetch(200, {})
  await request('/api', { method: 'POST', body: '{}' })
  const headers: Headers = (fetch as any).mock.calls[0][1].headers
  expect(headers.get('Content-Type')).toBe('application/json')
})
```

Also mock `config` and `authHeaders` so URL and token are predictable:

```typescript
vi.mock('../config', () => ({
  getApiUrl: (path: string) => `/api${path}`,
  getApiToken: vi.fn(() => ''),
  clearAuthToken: vi.fn(),
}))
```

---

## Option A: vi.mock (recommended)

### Basic usage

```typescript
// mock the whole module (placed at top; Vitest auto-hoists it)
vi.mock('@/api/modules/provider', () => ({
  providerApi: {
    listProviders: vi.fn(),
    getActiveModels: vi.fn(),
    setActiveLlm: vi.fn(),
  },
}))

import { providerApi } from '@/api/modules/provider'
```

### Setting return values

```typescript
describe('DataList', () => {
  beforeEach(() => {
    vi.mocked(providerApi.listProviders).mockResolvedValue([
      { id: 'openai', name: 'OpenAI' },
    ])
  })

  afterEach(() => vi.clearAllMocks())

  it('displays provider list after loading', async () => {
    renderWithProviders(<DataList />)
    expect(await screen.findByText('OpenAI')).toBeInTheDocument()
    expect(providerApi.listProviders).toHaveBeenCalledOnce()
  })
})
```

### Simulating errors

```typescript
it('shows error message on request failure', async () => {
  vi.mocked(providerApi.listProviders).mockRejectedValue(new Error('Network error'))
  renderWithProviders(<DataList />)
  expect(await screen.findByText(/failed to load/i)).toBeInTheDocument()
})
```

### Simulating a pending request (loading state)

```typescript
it('shows loading state', () => {
  vi.mocked(providerApi.listProviders).mockImplementation(
    () => new Promise(() => {}),  // never resolves
  )
  renderWithProviders(<DataList />)
  expect(screen.getByRole('progressbar')).toBeInTheDocument()
})
```

### Verifying call arguments

```typescript
it('passes correct arguments when switching model', async () => {
  vi.mocked(providerApi.setActiveLlm).mockResolvedValue(undefined)
  // ...
  expect(providerApi.setActiveLlm).toHaveBeenCalledWith('openai', 'gpt-4')
})
```

---

## Option B: msw (Mock Service Worker)

Best when testing the HTTP layer itself, or when multiple tests share the same mock server.

### Install

```bash
npm i -D msw
```

### Configure handlers

```typescript
// src/test/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/providers', () => {
    return HttpResponse.json([{ id: 'openai', name: 'OpenAI' }])
  }),

  http.post('/api/llm/set', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ success: true, model: body })
  }),
]
```

### Server setup

```typescript
// src/test/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

### Enable globally in setup.ts

```typescript
import { server } from './mocks/server'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

### Override handler per test

```typescript
it('handles 500 error', async () => {
  server.use(
    http.get('/api/providers', () =>
      HttpResponse.json({ message: 'error' }, { status: 500 }),
    ),
  )
  renderWithProviders(<DataList />)
  expect(await screen.findByText(/failed to load/)).toBeInTheDocument()
})
```

---

## Choosing an approach

| Scenario | Recommended |
|---|---|
| Component / hook unit tests | `vi.mock` |
| Testing the fetch/axios layer itself | msw |
| Multiple components sharing one mock server | msw |
| Testing loading / error / success states | `vi.mock` (simpler) |
| CI speed is a priority | `vi.mock` (no network overhead) |

---

## Common Pitfall: mock not working

`vi.mock` is auto-hoisted but `vi.fn()` references from outside the factory are not initialized yet. Use `vi.hoisted()`:

```typescript
// ✅ correct: use vi.hoisted for variables referenced in mock factory
const { mockFetch } = vi.hoisted(() => ({ mockFetch: vi.fn() }))
vi.mock('@/api/modules/data', () => ({ dataApi: { fetch: mockFetch } }))

// ❌ wrong: external variable not yet initialized when factory runs
const mockFetch = vi.fn()
vi.mock('@/api/modules/data', () => ({ dataApi: { fetch: mockFetch } }))  // ReferenceError
```

**Clean up after each test:**

```typescript
afterEach(() => {
  vi.clearAllMocks()   // clear call records, keep mock implementation
  // vi.resetAllMocks() // also resets implementation
  // vi.restoreAllMocks() // restores spies (vi.spyOn)
})
```

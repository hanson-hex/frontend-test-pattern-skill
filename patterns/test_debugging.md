# Debugging and Common Issues

---

## Variables in vi.mock factory cause ReferenceError

**Symptom**: `Cannot access 'mockXxx' before initialization`

**Cause**: `vi.mock` is hoisted to the top of the file, but `const mockXxx = vi.fn()` is not yet initialized at that point.

**Fix**: Declare variables with `vi.hoisted()`:

```typescript
// ✅ correct: vi.hoisted ensures variables are initialized before hoisting
const { mockFetch, mockSave } = vi.hoisted(() => ({
  mockFetch: vi.fn(),
  mockSave: vi.fn().mockResolvedValue(undefined),
}))

vi.mock('@/api/modules/data', () => ({
  dataApi: { fetch: mockFetch, save: mockSave },
}))
```

```typescript
// ❌ wrong: const is initialized after vi.mock hoisting
const mockFetch = vi.fn()
vi.mock('@/api/modules/data', () => ({
  dataApi: { fetch: mockFetch },  // ReferenceError
}))
```

---

## fake timers cause findBy* / waitFor to time out

**Symptom**: `vi.useFakeTimers()` causes `await screen.findByText(...)` to time out at 5000ms.

**Cause**: `findBy*` uses `waitFor` internally, which relies on real `setTimeout` for polling. Fake timers take over those timers and they never advance automatically.

**Fix**: Split basic render tests and timer-dependent tests into separate `describe` blocks:

```typescript
// Basic render tests — no fake timers, findBy* works normally
describe('Component - rendering', () => {
  it('displays data', async () => {
    mockApi.mockResolvedValue(data)
    render(<Component />)
    expect(await screen.findByText('content')).toBeInTheDocument()
  })
})

// Timer behavior tests — fake timers, advance manually
describe('Component - polling', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('deduplicates polling', async () => {
    render(<Component />)
    await act(async () => {
      vi.advanceTimersByTime(2500)
      await Promise.resolve()
    })
    // assertions...
  })
})
```

---

## ESM-only package (no main field) fails to resolve

**Symptom**: `Failed to resolve entry for package "@xxx/yyy". The package may have incorrect main/module/exports specified in its package.json.`

**Cause**: Package only has a `module` field with no `main`. Vitest's Node resolver cannot find the entry point.

**Fix**: Add `alias` pointing directly to the file, combined with `deps.inline`:

```typescript
// vite.config.ts
test: {
  deps: {
    inline: [/^@your-org\//],  // let Vite (not Node) resolve these packages
  },
  alias: {
    "@your-org/pkg": path.resolve(
      __dirname,
      "node_modules/@your-org/pkg/lib/index.js",
    ),
  },
}
```

Find the entry file: `cat node_modules/@pkg/name/package.json | grep -E '"main"|"module"'`

---

## vi.mock path is relative to the test file, not the component

**Symptom**: Mock is set up but component still renders the real version (no `data-testid` in DOM, but real content is there).

**Cause**: `vi.mock('./SomeComponent')` is resolved relative to the **test file**, not the component being tested.

**Example**:
```
components/Button/index.tsx           → imports '../Modal'
components/Button/__tests__/X.test.tsx → vi.mock needs '../../Modal'
```

**Debug**: Manually trace the relative path from the test file's directory to the target module.

---

## ResizeObserver mock must use a constructor function

**Symptom**: `TypeError: () => ({...}) is not a constructor` when testing components that use virtual lists or resize-aware layouts.

**Cause**: The library calls `new ResizeObserver(cb)` internally. Arrow functions cannot be used as constructors.

**Fix**: Use a regular function in `setup.ts`:

```typescript
// ❌ arrow function cannot be called with new
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(), unobserve: vi.fn(), disconnect: vi.fn(),
}))

// ✅ regular function can be called with new
global.ResizeObserver = vi.fn().mockImplementation(function () {
  return { observe: vi.fn(), unobserve: vi.fn(), disconnect: vi.fn() }
})
```

---

## antd Modal CSS animation leaves content in DOM

**Symptom**: After clicking a button that closes a Modal, `queryByText` still finds the button text even with `waitFor` timeout of 3000ms.

**Cause**: antd Modal keeps content in the DOM during the CSS exit animation. jsdom never completes animations, so content never disappears.

**Fix**: Mock Modal to conditionally render:

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

---

## vi.mock path mismatch (alias vs relative)

**Symptom**: Mock is set up but the real implementation is still called.

**Cause**: The mock path doesn't match how the module is imported in the source file.

```typescript
// source file uses relative path
import { myApi } from '../../api/modules/data'

// mock must use the same path
vi.mock('@/api/modules/data', ...)   // ← may not match
// change to:
vi.mock('../../api/modules/data', ...)
```

---

## node:test conflicts with Vitest

**Symptom**: `Cannot bundle built-in module "node:test"`

**Scenario**: Existing tests use `import { describe, it } from "node:test"`.

**Fix**: Exclude those files in `vite.config.ts` until migrated:

```typescript
test: {
  exclude: [
    "**/node_modules/**",
    "**/dist/**",
    "**/legacyTest.test.ts",  // old node:test format, pending migration
  ],
}
```

To migrate: remove `import { describe, it } from "node:test"` — with `globals: true` these are available automatically.

---

## Path alias not recognized

**Symptom**: `Cannot find module '@/api/...'`

**Fix**:

```typescript
// vite.config.ts
import path from 'path'

export default defineConfig({
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  test: {
    // Vitest usually inherits this; add explicitly if needed:
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
```

---

## Async test timeout

**Symptom**: `Error: Timeout - Async function did not complete within 5000ms`

**Fix A**: Increase timeout:

```typescript
it('slow operation', async () => {
  // ...
}, 10_000)
```

**Fix B**: Use async query methods:

```typescript
// ❌ may throw immediately: getBy* is synchronous
screen.getByText('Loading...')

// ✅ correct: findBy* polls until element appears
await screen.findByText('Done')

// ✅ or use waitFor
await waitFor(() => {
  expect(screen.getByText('Done')).toBeInTheDocument()
})
```

---

## Debugging Tips

**Print DOM structure**:

```typescript
screen.debug()
// or
import { prettyDOM } from '@testing-library/react'
console.log(prettyDOM(document.body))
```

**See all available queries**:

```typescript
screen.logTestingPlaygroundURL()
```

**Run a single test file**:

```bash
npx vitest run src/components/MyComponent/__tests__/MyComponent.test.tsx
```

**Watch a specific directory**:

```bash
npx vitest src/components/MyComponent
```

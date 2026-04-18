---
name: frontend-test-pattern
description: Frontend testing skill for React + Vite projects. Analyzes source code and generates high-quality tests using Vitest + @testing-library/react, covering pure functions, components, hooks, Zustand stores, API mocks, and optional Playwright E2E. Use this skill whenever the user needs to generate frontend tests, set up Vitest, improve test coverage, or asks how to test a React component or hook.
version: 0.1.0
---

# Frontend Test Generator

Analyze React/Vite source code and generate high-quality tests.

## When to Activate

- Generating tests for React components, hooks, or utility functions
- Setting up Vitest in a project
- Improving test coverage for existing code
- Answering "how do I test this component/function?"

## Workflow

### Step 1: Detect Project Structure

Read the following files to identify project characteristics:

```
1. package.json      → check for existing vitest/jest, read scripts
2. vite.config.ts    → get path aliases (@/* etc.), existing test config
3. tsconfig.app.json → confirm path aliases
4. target file       → classify type (pure function / component / hook / store)
```

File type classification:

| Characteristic | Type |
|---|---|
| No JSX, only function exports | Pure function → `pure_function_test.md` |
| Function component returning JSX | Component → `component_test.md` |
| Function starting with `use` | Hook → `hook_test.md` |
| Uses `create()` from zustand | Store → `store_test.md` |
| Calls fetch / axios / API modules | Combine with `api_mock.md` |
| 800+ lines, depends on third-party UI runtime | Heavy page → `page_test.md` |

### Step 2: Configure Test Environment (first time only)

If `vitest` is not in `package.json`, follow `patterns/vitest_setup.md` to:
1. Install dependencies
2. Add `test` block to `vite.config.ts`
3. Add `"test"` script to `package.json`
4. Create `src/test/setup.ts` (global setup)

### Step 3: Select Test Pattern

| File characteristic | Pattern file |
|---|---|
| Pure function / utility (no JSX) | `patterns/pure_function_test.md` |
| React component (< 200 lines) | `patterns/component_test.md` |
| Custom hook (use*) | `patterns/hook_test.md` |
| Zustand store | `patterns/store_test.md` |
| Contains API calls | `patterns/api_mock.md` |
| **800+ line heavy page, third-party UI runtime** | **`patterns/page_test.md`** |
| Full user flow (optional) | `patterns/e2e_playwright.md` |

### Step 4: Generate Tests

Follow the AAA pattern (Arrange-Act-Assert):

```typescript
// 1. Arrange: prepare data and mocks
vi.mock('@/api/modules/provider')
const mockData = { ... }

// 2. Act: execute the code under test
render(<MyComponent />)
await userEvent.click(screen.getByRole('button'))

// 3. Assert: verify the result
expect(screen.getByText('expected')).toBeInTheDocument()
```

Coverage checklist:
- Happy path
- Empty / undefined inputs
- Error / exception states
- Loading state (async components)
- Edge cases

### Step 5: Verify and Fix

Check common issues after generating:

| Problem | Solution |
|---|---|
| Path alias not resolved (`@/`) | Check `test.alias` in vite.config.ts |
| Less/CSS Module error | Add `moduleNameMapper` or CSS mock |
| Third-party library side effects | Mock in setup.ts |
| `window` / `document` undefined | Ensure `environment: 'jsdom'` |
| Async assertion not awaited | Use `waitFor` / `findBy*` |

See `patterns/test_debugging.md` for details.

---

## Pattern Reference

| Pattern file | Use case |
|---|---|
| `patterns/vitest_setup.md` | Initial setup |
| `patterns/pure_function_test.md` | Utility function tests (highest ROI) |
| `patterns/component_test.md` | React component rendering and interaction |
| `patterns/hook_test.md` | Custom hook tests |
| `patterns/api_mock.md` | API/fetch mocking |
| `patterns/store_test.md` | Zustand store tests |
| `patterns/page_test.md` | Heavy page tests (Factory + Capture pattern) |
| `patterns/e2e_playwright.md` | Playwright E2E (optional) |
| `patterns/test_debugging.md` | Debugging and common issues |

## Fixtures

`fixtures/common_setup.ts` provides shared render utilities:

| Utility | Purpose |
|---|---|
| `renderWithProviders` | Full render with Router + Theme + i18n |
| `createMockStore` | Create isolated Zustand store instance |

## References

- Vitest docs: https://vitest.dev/
- Testing Library: https://testing-library.com/docs/react-testing-library/intro/
- Playwright: https://playwright.dev/

# frontend-test-pattern

A skill for generating high-quality tests in React + Vite projects using Vitest + @testing-library/react.

## Coverage

| Test type | Framework | Pattern file |
|---|---|---|
| Pure functions / utilities | Vitest | `patterns/pure_function_test.md` |
| React components | Vitest + @testing-library/react | `patterns/component_test.md` |
| Custom hooks | Vitest + renderHook | `patterns/hook_test.md` |
| Zustand stores | Vitest | `patterns/store_test.md` |
| API mocking | vi.mock / msw | `patterns/api_mock.md` |
| Heavy page components | Factory + Capture pattern | `patterns/page_test.md` |
| E2E (optional) | Playwright | `patterns/e2e_playwright.md` |

## Install

```bash
bash install.sh
```

## Usage

In Claude Code, this skill activates automatically when you need to write tests for a React/Vite project.

You can also say: "Write tests for utils.ts" or "Set up Vitest for this project".

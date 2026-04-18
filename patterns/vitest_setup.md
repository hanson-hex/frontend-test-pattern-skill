# Vitest Setup

## Install Dependencies

```bash
npm i -D vitest @testing-library/react @testing-library/user-event @testing-library/jest-dom jsdom
```

For E2E:
```bash
npm i -D @playwright/test
npx playwright install
```

---

## vite.config.ts

Add a `test` block to your existing config. **Key: reuse the existing `resolve.alias` — no need to duplicate path aliases.**

```typescript
// vite.config.ts
/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    globals: true,              // no need to import describe/it/expect
    environment: 'jsdom',       // simulate browser environment
    setupFiles: ['./src/test/setup.ts'],
    css: true,                  // process CSS/Less (no errors, no rendering)
  },
})
```

> Note: Vitest automatically inherits `resolve.alias` from `vite.config.ts`. Only add `test.alias` if resolution fails.

---

## package.json scripts

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage"
  }
}
```

---

## src/test/setup.ts (global setup)

```typescript
import '@testing-library/jest-dom'
import { vi } from 'vitest'

// matchMedia (required by many UI libraries)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// ResizeObserver (required by virtual list components)
// Must use a regular function — arrow functions cannot be used as constructors
global.ResizeObserver = vi.fn().mockImplementation(function () {
  return {
    observe: vi.fn(),
    unobserve: vi.fn(),
    disconnect: vi.fn(),
  }
})
```

---

## CSS Modules / Less

Vitest `css: true` handles CSS imports by default. If you hit Less variable compilation errors, add to `vite.config.ts`:

```typescript
test: {
  css: {
    modules: {
      classNameStrategy: 'non-scoped',
    },
  },
}
```

Or mock directly in setup.ts:

```typescript
vi.mock('*.module.less', () => ({}))
vi.mock('*.less', () => ({}))
```

---

## ESM-only packages (no `main` field)

Some packages only have a `module` field. Vitest's Node resolver cannot find the entry point. Fix with `alias` + `deps.inline`:

```typescript
test: {
  deps: {
    inline: [/^@your-org\//],
  },
  alias: {
    "@your-org/pkg": path.resolve(
      __dirname,
      "node_modules/@your-org/pkg/lib/index.js",
    ),
  },
}
```

Find the entry: `cat node_modules/@pkg/name/package.json | grep -E '"main"|"module"'`

---

## Directory convention

```
src/
├── test/
│   ├── setup.ts              # global setup
│   └── common_setup.tsx      # renderWithProviders helper
├── pages/Feature/
│   ├── utils.ts
│   └── __tests__/
│       └── utils.test.ts
└── components/
    └── MyComponent/
        ├── index.tsx
        └── index.test.tsx    # co-located or in __tests__/
```

---

## Run

```bash
npm test              # watch mode
npm run test:run      # single run (CI)
npm run test:coverage # coverage report
```

Coverage config (optional):

```typescript
// inside vite.config.ts test block
coverage: {
  provider: 'v8',
  reporter: ['text', 'html', 'lcov'],
  include: ['src/**/*.{ts,tsx}'],
  exclude: ['src/test/**', 'src/**/*.d.ts'],
},
```

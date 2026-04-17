# Vitest 环境配置

## 安装依赖

```bash
npm i -D vitest @testing-library/react @testing-library/user-event @testing-library/jest-dom jsdom
```

如需测试 Hook：
```bash
npm i -D @testing-library/react  # renderHook 已内置
```

如需 E2E：
```bash
npm i -D @playwright/test
npx playwright install
```

---

## vite.config.ts 修改

在已有配置中添加 `test` 块。**关键：复用已有的 `resolve.alias`，无需重复配置路径别名。**

```typescript
// vite.config.ts
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
  // 新增 test 配置
  test: {
    globals: true,              // 无需 import describe/it/expect
    environment: 'jsdom',       // 模拟浏览器环境
    setupFiles: ['./src/test/setup.ts'],
    css: true,                  // 处理 CSS/Less（不报错但不渲染）
    alias: {
      // 若 vite resolve.alias 未自动继承，在此补充
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

> 注意：Vitest 会自动继承 `vite.config.ts` 的 `resolve.alias`，通常不需要在 `test.alias` 中重复。先不配，跑失败再加。

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

## src/test/setup.ts（全局 setup）

```typescript
import '@testing-library/jest-dom'

// Mock Less/CSS Modules（防止 import 报错）
// Vite 默认 css: true 时通常不需要，但若有问题可在此 mock

// Mock 不兼容 jsdom 的浏览器 API
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

// Mock ResizeObserver（antd 组件依赖）
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}))
```

---

## CSS Modules / Less 处理

Vitest `css: true` 会处理 CSS 导入，通常不需要额外配置。

若遇到 Less 变量编译报错（antd token 等），在 `vite.config.ts` 中：

```typescript
test: {
  css: {
    modules: {
      classNameStrategy: 'non-scoped',  // 简化 class 名，便于测试断言
    },
  },
}
```

若仍报错，直接在 setup.ts 中 mock：

```typescript
vi.mock('*.module.less', () => ({}))
vi.mock('*.less', () => ({}))
```

---

## 目录约定

```
src/
├── test/
│   └── setup.ts              # 全局 setup
├── pages/Chat/
│   ├── utils.ts
│   └── __tests__/
│       └── utils.test.ts     # 测试文件放在 __tests__ 子目录
└── components/
    └── MyComponent/
        ├── index.tsx
        └── index.test.tsx    # 或与组件同目录
```

两种放置方式均可，推荐同目录（`index.test.tsx`）或 `__tests__/` 子目录。

---

## 运行验证

```bash
npm test              # 监听模式
npm run test:run      # 单次运行（CI 用）
npm run test:coverage # 覆盖率报告
```

覆盖率配置（可选）：

```typescript
// vite.config.ts test 块内
coverage: {
  provider: 'v8',
  reporter: ['text', 'html'],
  include: ['src/**/*.{ts,tsx}'],
  exclude: ['src/test/**', 'src/**/*.d.ts'],
},
```

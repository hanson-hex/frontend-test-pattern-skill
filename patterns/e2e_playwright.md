# Playwright E2E 测试（可选）

E2E 测试覆盖真实用户流程，需要完整的前后端服务。
**仅在以下情况使用**：核心用户流程无法通过组件测试覆盖，或需要验证跨页面交互。

---

## 安装

```bash
npm i -D @playwright/test
npx playwright install  # 安装浏览器
```

---

## playwright.config.ts

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  // 启动 dev server
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

## 目录结构

```
e2e/
├── chat.spec.ts          # Chat 页面流程
├── login.spec.ts         # 登录流程
└── fixtures/
    └── auth.ts           # 登录 fixture
```

---

## 基础结构

```typescript
// e2e/chat.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Chat 页面', () => {
  test.beforeEach(async ({ page }) => {
    // 若需要登录，先完成登录
    await page.goto('/login')
    await page.fill('[name=username]', 'test@example.com')
    await page.fill('[name=password]', 'password')
    await page.click('button[type=submit]')
    await page.waitForURL('/chat')
  })

  test('发送消息并收到回复', async ({ page }) => {
    await page.goto('/chat')

    // 输入消息
    const input = page.getByRole('textbox', { name: /输入消息/i })
    await input.fill('你好')
    await input.press('Enter')

    // 等待回复出现
    await expect(page.locator('.message-assistant').last()).toBeVisible({
      timeout: 15_000,
    })
  })

  test('新建对话清空历史', async ({ page }) => {
    await page.goto('/chat')
    await page.getByRole('button', { name: /新建/i }).click()

    // 验证消息列表为空
    await expect(page.locator('.message-list')).toBeEmpty()
  })
})
```

---

## mock API（推荐用于 CI）

不依赖真实后端，用 Playwright 的 `route` mock 接口：

```typescript
test('mock 后端响应测试 UI 流程', async ({ page }) => {
  // mock 流式响应
  await page.route('/api/chat/stream', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'text/event-stream',
      body: ' {"content": "Mock 回复"}\n\n [DONE]\n\n',
    })
  })

  await page.goto('/chat')
  await page.getByRole('textbox').fill('测试消息')
  await page.keyboard.press('Enter')

  await expect(page.getByText('Mock 回复')).toBeVisible()
})
```

---

## 登录 Fixture（复用）

```typescript
// e2e/fixtures/auth.ts
import { test as base, expect } from '@playwright/test'

export const test = base.extend({
  authedPage: async ({ page }, use) => {
    await page.goto('/login')
    await page.fill('[name=username]', process.env.TEST_USER!)
    await page.fill('[name=password]', process.env.TEST_PASS!)
    await page.click('button[type=submit]')
    await page.waitForURL('/chat')
    await use(page)
  },
})

// 使用时
import { test } from './fixtures/auth'
test('需要登录的测试', async ({ authedPage }) => {
  // authedPage 已经完成登录
})
```

---

## package.json scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:headed": "playwright test --headed"
  }
}
```

---

## 何时不用 E2E

- **纯 UI 逻辑**：用组件测试（更快、更稳定）
- **API 数据处理**：用 api_mock.md 的 vi.mock
- **表单验证**：用组件测试
- **只有 E2E 才能覆盖的**：跨页面跳转、真实 SSE 流式响应、文件上传完整流程

# Playwright E2E Tests (optional)

E2E tests cover real user flows and require a running frontend + backend. Use only when core flows cannot be covered by component tests.

---

## Install

```bash
npm i -D @playwright/test
npx playwright install
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
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
})
```

---

## Directory Structure

```
e2e/
├── auth.spec.ts
├── dashboard.spec.ts
└── fixtures/
    └── auth.ts
```

---

## Basic Structure

```typescript
import { test, expect } from '@playwright/test'

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login')
    await page.fill('[name=username]', 'user@example.com')
    await page.fill('[name=password]', 'password')
    await page.click('button[type=submit]')
    await page.waitForURL('/dashboard')
  })

  test('displays welcome message after login', async ({ page }) => {
    await expect(page.getByText('Welcome')).toBeVisible()
  })

  test('navigates to settings', async ({ page }) => {
    await page.getByRole('link', { name: 'Settings' }).click()
    await expect(page).toHaveURL('/settings')
  })
})
```

---

## Mock API with route (recommended for CI)

Avoid real backend by intercepting requests:

```typescript
test('handles API error gracefully', async ({ page }) => {
  await page.route('/api/data', async (route) => {
    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'Server Error' }),
    })
  })

  await page.goto('/dashboard')
  await expect(page.getByText(/error loading/i)).toBeVisible()
})
```

---

## Auth Fixture (reusable login)

```typescript
// e2e/fixtures/auth.ts
import { test as base } from '@playwright/test'

export const test = base.extend({
  authedPage: async ({ page }, use) => {
    await page.goto('/login')
    await page.fill('[name=username]', process.env.TEST_USER!)
    await page.fill('[name=password]', process.env.TEST_PASS!)
    await page.click('button[type=submit]')
    await page.waitForURL('/dashboard')
    await use(page)
  },
})

// usage
import { test } from './fixtures/auth'
test('authenticated flow', async ({ authedPage }) => {
  // authedPage is already logged in
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

## When NOT to use E2E

- **Pure UI logic**: use component tests (faster, more stable)
- **API data processing**: use `vi.mock` in unit tests
- **Form validation**: use component tests
- **Reserve E2E for**: cross-page navigation, real streaming responses, full file upload flows

# 纯函数测试模式

适用于无 JSX、无副作用的工具函数（utils.ts、helpers.ts 等）。
这是**最高 ROI** 的测试类型：零 mock、运行快、断言清晰。

---

## 基础结构

```typescript
import { describe, it, expect } from 'vitest'
import { myFunction } from '../utils'

describe('myFunction', () => {
  it('正常输入返回预期结果', () => {
    // Arrange
    const input = { ... }

    // Act
    const result = myFunction(input)

    // Assert
    expect(result).toBe('expected')
  })

  it('空值输入返回默认值', () => {
    expect(myFunction({})).toBe('')
  })
})
```

---

## 参数化测试（test.each）

当同一函数需要多组输入/输出验证时，用 `test.each` 代替重复 `it` 块：

```typescript
describe('toDisplayUrl', () => {
  test.each([
    // [描述, 输入, 期望输出]
    ['http URL 原样返回', 'http://example.com/img.png', 'http://example.com/img.png'],
    ['https URL 原样返回', 'https://cdn.com/file', 'https://cdn.com/file'],
    ['空字符串返回空', '', ''],
    ['undefined 返回空', undefined, ''],
    ['相对路径补全前缀', '/uploads/img.png', expect.stringContaining('/uploads/img.png')],
  ])('%s', (_, input, expected) => {
    expect(toDisplayUrl(input)).toEqual(expected)
  })
})
```

---

## 边界值测试清单

为每个函数补充以下边界测试：

| 边界类型 | 测试用例命名 |
|---------|------------|
| 空字符串 | `'空字符串输入'` |
| undefined / null | `'undefined 输入'` |
| 空对象/数组 | `'空对象输入'` |
| 极长字符串 | `'超长字符串输入'` |
| 特殊字符 | `'含特殊字符'` |
| 嵌套结构 | `'深层嵌套结构'` |

---

## 实战示例：Chat/utils.ts

### extractCopyableText

```typescript
import { describe, it, expect } from 'vitest'
import { extractCopyableText } from '../utils'
import type { CopyableResponse } from '../utils'

describe('extractCopyableText', () => {
  it('提取 assistant 角色的文本内容', () => {
    const response: CopyableResponse = {
      output: [
        { role: 'user', content: '你好' },
        { role: 'assistant', content: '你好，有什么可以帮你？' },
      ],
    }
    expect(extractCopyableText(response)).toBe('你好，有什么可以帮你？')
  })

  it('提取结构化 content 数组中的 text', () => {
    const response: CopyableResponse = {
      output: [
        {
          role: 'assistant',
          content: [
            { type: 'text', text: '第一段' },
            { type: 'text', text: '第二段' },
          ],
        },
      ],
    }
    expect(extractCopyableText(response)).toBe('第一段\n\n第二段')
  })

  it('无 assistant 消息时回退到 JSON 序列化', () => {
    const response: CopyableResponse = {
      output: [{ role: 'user', content: '仅用户消息' }],
    }
    const result = extractCopyableText(response)
    expect(result).toContain('仅用户消息')
  })

  it('output 为空时返回序列化结果', () => {
    const response: CopyableResponse = { output: [] }
    expect(extractCopyableText(response)).toBe(JSON.stringify(response))
  })

  it('output 为 undefined 时不报错', () => {
    expect(() => extractCopyableText({})).not.toThrow()
  })
})
```

### toStoredName

```typescript
describe('toStoredName', () => {
  test.each([
    [
      '提取 /files/preview/ 后的路径',
      'http://host/files/preview//uploads/img.png',
      '//uploads/img.png',
    ],
    [
      '去掉查询参数',
      'http://host/files/preview/img.png?token=abc',
      '/img.png',
    ],
    [
      '去掉 hash',
      'http://host/files/preview/img.png#section',
      '/img.png',
    ],
    [
      '无 marker 时原样返回',
      '/local/path/file.txt',
      '/local/path/file.txt',
    ],
    [
      'URL 编码路径正确解码',
      'http://host/files/preview/%E4%B8%AD%E6%96%87.txt',
      '/中文.txt',
    ],
  ])('%s', (_, input, expected) => {
    expect(toStoredName(input)).toBe(expected)
  })
})
```

### buildModelError

```typescript
describe('buildModelError', () => {
  it('返回 400 状态码', async () => {
    const response = buildModelError()
    expect(response.status).toBe(400)
  })

  it('响应体包含 error 字段', async () => {
    const response = buildModelError()
    const body = await response.json()
    expect(body).toHaveProperty('error')
    expect(body).toHaveProperty('message')
  })

  it('Content-Type 为 application/json', () => {
    const response = buildModelError()
    expect(response.headers.get('Content-Type')).toBe('application/json')
  })
})
```

---

## Vite 全局变量（define）的测试处理

Vite 的 `define` 配置注入的全局常量（如 `VITE_API_BASE_URL`、`TOKEN`）在测试中需要通过 `globalThis` 设置：

```typescript
// vite.config.ts 中有 define: { VITE_API_BASE_URL: ... }
// 测试中这样设置：
const setViteBase = (v: string) => { (globalThis as any).VITE_API_BASE_URL = v }

beforeEach(() => setViteBase(''))  // 每个测试前重置
```

---

## 依赖外部模块的函数

当工具函数导入了 API 模块（如 `chatApi.filePreviewUrl`），需要 mock：

```typescript
// utils.ts 中
import { chatApi } from '@/api/modules/chat'
export function toDisplayUrl(url: string | undefined): string {
  // ...
  return chatApi.filePreviewUrl(url)
}
```

测试中 mock 该模块：

```typescript
import { vi, describe, it, expect, beforeEach } from 'vitest'
import { toDisplayUrl } from '../utils'

vi.mock('@/api/modules/chat', () => ({
  chatApi: {
    filePreviewUrl: vi.fn((path: string) => `http://mock-host${path}`),
  },
}))

describe('toDisplayUrl', () => {
  it('相对路径加上 mock host', () => {
    expect(toDisplayUrl('/img.png')).toBe('http://mock-host/img.png')
  })

  it('已是 http URL 原样返回', () => {
    expect(toDisplayUrl('http://cdn.com/img.png')).toBe('http://cdn.com/img.png')
  })
})
```

---

## 注意事项

- 纯函数测试**不需要** `renderWithProviders`，直接调用函数即可
- 若函数使用了 `window` / `document` API，jsdom 已自动提供
- 优先用 `test.each` 减少重复代码
- 断言尽量具体，避免只断言 `toBeTruthy()`

# frontend-test-pattern

React + Vite 前端测试技能，与 [python-test-pattern](../python-test-pattern) 同系列。

## 覆盖范围

| 测试类型 | 框架 | 模式文件 |
|---------|------|---------|
| 纯函数/工具函数 | Vitest | `patterns/pure_function_test.md` |
| React 组件 | Vitest + @testing-library/react | `patterns/component_test.md` |
| 自定义 Hook | Vitest + renderHook | `patterns/hook_test.md` |
| Zustand Store | Vitest | `patterns/store_test.md` |
| API Mock | vi.mock / msw | `patterns/api_mock.md` |
| E2E（可选） | Playwright | `patterns/e2e_playwright.md` |

## 安装

```bash
bash install.sh
```

## 使用

在 Claude Code 中，当需要为 React 项目生成测试时，skill 会自动激活。

也可以直接说：「帮我为 Chat/utils.ts 生成测试」

## 试点项目

CoPaw 前端（`/Users/hex/work/CoPaw/console`）Chat 页面

首批测试参考：`examples/chat_utils_example.md`

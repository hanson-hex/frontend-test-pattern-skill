# Zustand Store 测试模式

直接测试 store 的状态变更逻辑，不需要渲染组件。

---

## 基础结构

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { act } from '@testing-library/react'

// 直接导入 store hook
import { useAgentStore } from '@/stores/agentStore'

describe('agentStore', () => {
  beforeEach(() => {
    // 每个测试前重置 store 状态
    useAgentStore.setState(useAgentStore.getInitialState?.() ?? {})
  })

  it('初始状态正确', () => {
    const state = useAgentStore.getState()
    expect(state.currentAgent).toBeNull()
  })

  it('setCurrentAgent 更新当前 agent', () => {
    act(() => {
      useAgentStore.getState().setCurrentAgent({ id: '1', name: 'TestAgent' })
    })
    expect(useAgentStore.getState().currentAgent?.id).toBe('1')
  })
})
```

---

## 隔离测试（推荐）

为避免测试间状态污染，建议使用工厂函数创建独立 store 实例：

```typescript
// 若 store 支持 create 导出（非单例）
import { createAgentStore } from '@/stores/agentStore'

describe('agentStore（隔离）', () => {
  let store: ReturnType<typeof createAgentStore>

  beforeEach(() => {
    store = createAgentStore()
  })

  it('初始 agents 为空数组', () => {
    expect(store.getState().agents).toEqual([])
  })
})
```

若 store 是单例（`export const useXxxStore = create(...)`），用 `setState` 重置：

```typescript
beforeEach(() => {
  // 重置为初始状态
  useAgentStore.setState({
    currentAgent: null,
    agents: [],
  })
})
```

---

## 在组件中测试 store 集成

```typescript
import { renderWithProviders } from '@/test/common_setup'
import { useAgentStore } from '@/stores/agentStore'

it('组件渲染 store 中的 agent 名称', () => {
  // 预设 store 状态
  useAgentStore.setState({
    currentAgent: { id: '1', name: 'My Agent' },
  })

  renderWithProviders(<AgentHeader />)
  expect(screen.getByText('My Agent')).toBeInTheDocument()
})
```

---

## 异步 action 测试

```typescript
it('fetchAgents 加载数据到 store', async () => {
  vi.mock('@/api/modules/agent', () => ({
    agentApi: {
      list: vi.fn().mockResolvedValue([
        { id: '1', name: 'Agent A' },
      ]),
    },
  }))

  await act(async () => {
    await useAgentStore.getState().fetchAgents()
  })

  expect(useAgentStore.getState().agents).toHaveLength(1)
  expect(useAgentStore.getState().agents[0].name).toBe('Agent A')
})
```

---

## 测试覆盖清单

| 测试类型 | 说明 |
|---------|------|
| 初始状态 | 验证 store 初始值正确 |
| 同步 action | 调用后状态立即变化 |
| 异步 action | loading/data/error 三态 |
| 状态重置 | reset/clear action |
| 派生状态（selector） | computed 值计算正确 |

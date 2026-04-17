/**
 * 通用测试渲染封装
 * 为组件测试提供 Router、Theme、i18n 等 Provider 包裹
 *
 * 使用方式：
 *   import { renderWithProviders } from '@/test/common_setup'
 *   renderWithProviders(<MyComponent />)
 */

import { render, type RenderOptions } from '@testing-library/react'
import { MemoryRouter, type MemoryRouterProps } from 'react-router-dom'
import { type ReactNode } from 'react'

// -----------------------------------------------------------------------
// Provider 封装
// -----------------------------------------------------------------------

interface ProvidersProps {
  children: ReactNode
  routerProps?: MemoryRouterProps
}

/**
 * 包含所有必要 Provider 的 wrapper。
 * 按需添加项目特定的 Provider（ThemeProvider、ConfigProvider 等）。
 */
function AllProviders({ children, routerProps }: ProvidersProps) {
  return (
    <MemoryRouter {...routerProps}>
      {/*
       * 若项目有 ThemeProvider，在此添加：
       * <ThemeProvider theme="light">
       *   {children}
       * </ThemeProvider>
       *
       * 若项目有 i18n Provider，在此添加：
       * <I18nextProvider i18n={i18nInstance}>
       *   {children}
       * </I18nextProvider>
       */}
      {children}
    </MemoryRouter>
  )
}

// -----------------------------------------------------------------------
// renderWithProviders
// -----------------------------------------------------------------------

interface RenderWithProvidersOptions extends Omit<RenderOptions, 'wrapper'> {
  /** MemoryRouter 初始路由，默认 '/' */
  initialEntries?: string[]
}

/**
 * 带完整 Provider 的 render 封装。
 * 替代裸 render()，适用于所有组件测试。
 */
export function renderWithProviders(
  ui: React.ReactElement,
  { initialEntries = ['/'], ...renderOptions }: RenderWithProvidersOptions = {},
) {
  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <AllProviders routerProps={{ initialEntries }}>
        {children}
      </AllProviders>
    )
  }

  return render(ui, { wrapper: Wrapper, ...renderOptions })
}

// -----------------------------------------------------------------------
// createMockStore（Zustand）
// -----------------------------------------------------------------------

/**
 * 创建隔离的 Zustand store 实例（避免测试间状态污染）。
 *
 * 使用方式（需要 store 导出 createXxxStore 工厂函数）：
 *   const store = createMockStore(createAgentStore, { agents: [] })
 *   store.setState({ currentAgent: mockAgent })
 */
export function createMockStore<T extends object>(
  createFn: () => { getState: () => T; setState: (partial: Partial<T>) => void },
  initialState?: Partial<T>,
) {
  const store = createFn()
  if (initialState) {
    store.setState(initialState)
  }
  return store
}

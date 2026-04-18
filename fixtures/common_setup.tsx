/**
 * Shared test render utilities
 * Wraps components with Router, Theme, i18n and other providers for testing.
 *
 * Usage:
 *   import { renderWithProviders } from '@/test/common_setup'
 *   renderWithProviders(<MyComponent />)
 */

import { render, type RenderOptions } from '@testing-library/react'
import { MemoryRouter, type MemoryRouterProps } from 'react-router-dom'
import { type ReactNode } from 'react'

// -----------------------------------------------------------------------
// Provider wrapper
// -----------------------------------------------------------------------

interface ProvidersProps {
  children: ReactNode
  routerProps?: MemoryRouterProps
}

/**
 * Wrapper with all required providers.
 * Add project-specific providers here (ThemeProvider, i18n, etc.).
 */
function AllProviders({ children, routerProps }: ProvidersProps) {
  return (
    <MemoryRouter {...routerProps}>
      {/*
       * Add ThemeProvider if needed:
       * <ThemeProvider theme="light">
       *   {children}
       * </ThemeProvider>
       *
       * Add i18n Provider if needed:
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
  /** Initial routes for MemoryRouter, defaults to ['/'] */
  initialEntries?: string[]
}

/**
 * Render with all providers.
 * Use instead of bare render() for all component tests.
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
// createMockStore (Zustand)
// -----------------------------------------------------------------------

/**
 * Create an isolated Zustand store instance to prevent state leaking between tests.
 *
 * Usage (requires store to export a factory function):
 *   const store = createMockStore(createMyStore, { items: [] })
 *   store.setState({ selectedItem: mockItem })
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

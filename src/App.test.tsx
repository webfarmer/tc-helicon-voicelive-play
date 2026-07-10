import '@testing-library/jest-dom/vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, expect, test } from 'vitest'
import App from './App'

beforeEach(() => {
  const store = new Map<string, string>()

  Object.defineProperty(window, 'localStorage', {
    configurable: true,
    value: {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => store.set(key, value),
      removeItem: (key: string) => store.delete(key),
      clear: () => store.clear(),
    },
  })
})

afterEach(() => {
  window.localStorage.clear()
  cleanup()
})

test('renders the VoiceLive Play librarian with real pack data', () => {
  render(<App />)

  expect(
    screen.getByRole('heading', { name: 'VoiceLive Play Workbench' }),
  ).toBeInTheDocument()
  expect(screen.getAllByText('Modern Rock Pack').length).toBeGreaterThan(0)
  expect(screen.getByText('Device writes locked')).toBeInTheDocument()
  expect(screen.getByText('500-slot workspace')).toBeInTheDocument()
})

test('stages a selected pack preset into the active workspace slot', () => {
  render(<App />)

  fireEvent.click(screen.getAllByRole('button', { name: 'SOUND & COLOR' })[0])

  expect(screen.getByLabelText('Selected preset name')).toHaveTextContent(
    'SOUND & COLOR',
  )
  expect(screen.getByLabelText('Selected preset source')).toHaveTextContent(
    'Modern Rock Pack',
  )
})

test('persists staged workspace changes locally', () => {
  const { unmount } = render(<App />)

  fireEvent.click(screen.getAllByRole('button', { name: 'SOUND & COLOR' })[0])
  unmount()
  render(<App />)

  expect(screen.getByLabelText('Selected preset name')).toHaveTextContent(
    'SOUND & COLOR',
  )
})

test('resets staged workspace changes back to the factory workspace', () => {
  render(<App />)

  fireEvent.click(screen.getAllByRole('button', { name: 'SOUND & COLOR' })[0])
  fireEvent.click(screen.getByRole('button', { name: 'Reset workspace' }))

  expect(screen.getByLabelText('Selected preset name')).toHaveTextContent(
    'PAUL PRESENT',
  )
  expect(screen.getByLabelText('Selected preset source')).toHaveTextContent(
    'Device workspace',
  )
})

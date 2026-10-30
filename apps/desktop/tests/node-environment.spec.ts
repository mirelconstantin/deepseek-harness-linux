import { delimiter } from 'node:path'
import { expect, it } from 'vitest'
import { desktopNodeEnvironment, resolveHostExecutable } from '../src/node-environment.ts'

it('keeps private Desktop launchers out of the Host environment inherited by PTC', () => {
  const environment = { PATH: '/user/bin', HOME: '/user' }
  expect(desktopNodeEnvironment('/desktop/electron', undefined, environment)).toEqual({
    ...environment, ELECTRON_RUN_AS_NODE: '1',
  })
  expect(environment).toEqual({ PATH: '/user/bin', HOME: '/user' })
})

it('provides private launchers only to package installation processes', () => {
  expect(desktopNodeEnvironment('/desktop/electron', '/desktop/bin', { PATH: '/user/bin' })).toEqual({
    ELECTRON_RUN_AS_NODE: '1',
    DSH_DESKTOP_NODE_EXECUTABLE: '/desktop/electron',
    PATH: `/desktop/bin${delimiter}/user/bin`,
  })
})

it('keeps Electron on platforms whose GLib symbols do not reach sharp', () => {
  expect(resolveHostExecutable('darwin', '/runtime/node', '/desktop/electron', () => true)).toBe('/desktop/electron')
  expect(resolveHostExecutable('win32', '/runtime/node', '/desktop/electron', () => true)).toBe('/desktop/electron')
})

it('runs the Host on the bundled Node.js on Linux', () => {
  expect(resolveHostExecutable('linux', '/runtime/node', '/desktop/electron', () => true)).toBe('/runtime/node')
})

it('falls back to Electron when the bundled Node.js is unusable', () => {
  expect(resolveHostExecutable('linux', '/runtime/node', '/desktop/electron', () => false)).toBe('/desktop/electron')
})

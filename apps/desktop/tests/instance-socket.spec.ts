import fs from 'node:fs'
import net from 'node:net'
import os from 'node:os'
import path from 'node:path'
import { describe, expect, it, vi } from 'vitest'
import {
  INSTANCE_SOCKET_NAME,
  resolveInstanceSocketPath,
  startInstanceSocket,
} from '../src/instance-socket.ts'

describe('desktop instance socket', () => {
  it('resolves socket path from XDG_RUNTIME_DIR or tmpdir', () => {
    const xdg = resolveInstanceSocketPath({ XDG_RUNTIME_DIR: '/run/user/1000' })
    expect(xdg).toBe(path.join('/run/user/1000', INSTANCE_SOCKET_NAME))

    const fallback = resolveInstanceSocketPath({})
    expect(fallback).toContain(os.tmpdir())
    expect(fallback).toContain('deepseek-harness-')
  })

  it('handles client focus ping and triggers onFocus callback', async () => {
    const testSocketPath = path.join(os.tmpdir(), `test-dsh-socket-${String(Date.now())}.sock`)
    const onFocus = vi.fn()

    const dispose = startInstanceSocket({
      socketPath: testSocketPath,
      onFocus,
    })

    // Allow server to bind
    await new Promise(resolve => setTimeout(resolve, 50))
    expect(fs.existsSync(testSocketPath)).toBe(true)

    // Connect client and send focus
    const response = await new Promise<string>((resolve, reject) => {
      const client = net.connect(testSocketPath)
      let received = ''
      client.setEncoding('utf8')
      client.on('connect', () => {
        client.write('focus\n')
      })
      client.on('data', (chunk) => {
        received += String(chunk)
      })
      client.on('end', () => {
        resolve(received)
      })
      client.on('error', reject)
    })

    expect(response).toBe('ok\n')
    expect(onFocus).toHaveBeenCalledOnce()

    dispose()
    expect(fs.existsSync(testSocketPath)).toBe(false)
  })

  it('unlinks stale socket file on startup', async () => {
    const testSocketPath = path.join(os.tmpdir(), `test-dsh-stale-${String(Date.now())}.sock`)
    fs.writeFileSync(testSocketPath, 'stale')
    expect(fs.existsSync(testSocketPath)).toBe(true)

    const dispose = startInstanceSocket({
      socketPath: testSocketPath,
      onFocus: vi.fn(),
    })

    await new Promise(resolve => setTimeout(resolve, 50))
    expect(fs.existsSync(testSocketPath)).toBe(true)

    dispose()
    expect(fs.existsSync(testSocketPath)).toBe(false)
  })
})

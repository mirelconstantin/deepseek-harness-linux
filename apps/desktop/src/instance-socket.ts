/**
 * Fast IPC wake-up socket for Desktop instances on POSIX platforms.
 * Allows external launchers (like taskbar shortcuts, CLI, or application menus)
 * to instantly focus an existing background or tray instance in <10ms without
 * launching a separate runtime or Electron process.
 */

import net from 'node:net'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

/** Default filename for the instance wake-up socket. */
export const INSTANCE_SOCKET_NAME = 'deepseek-harness.sock'

/**
 * Resolve the user-private socket path for the current desktop session.
 * @param env - Current process environment variables.
 * @returns Fully qualified filesystem path to the domain socket.
 */
export function resolveInstanceSocketPath(env: NodeJS.ProcessEnv = process.env): string {
  const runtimeDir = env.XDG_RUNTIME_DIR
  if (runtimeDir !== undefined && runtimeDir !== '') {
    return path.join(runtimeDir, INSTANCE_SOCKET_NAME)
  }
  const uid = typeof process.getuid === 'function' ? process.getuid() : 'default'
  return path.join(os.tmpdir(), `deepseek-harness-${String(uid)}.sock`)
}

/** Configuration options for the desktop instance IPC socket. */
export interface InstanceSocketOptions {
  /** Socket path to bind; defaults to standard XDG_RUNTIME_DIR or temp path. */
  readonly socketPath?: string
  /** Callback triggered when a wake-up / focus request is received from a client. */
  readonly onFocus: () => void
}

/**
 * Start listening on a UNIX domain socket for wake-up pings.
 * @param options - Socket configuration and focus callback.
 * @returns Disposer function to close the server and unlink the socket file.
 */
export function startInstanceSocket(options: InstanceSocketOptions): () => void {
  const socketPath = options.socketPath ?? resolveInstanceSocketPath()

  // Clean up any stale or orphaned socket from an abnormal previous exit
  try {
    if (fs.existsSync(socketPath)) {
      fs.unlinkSync(socketPath)
    }
  } catch {
    // Ignore unlink failures if file is missing or in use
  }

  const server = net.createServer((client) => {
    client.setEncoding('utf8')
    let buffer = ''
    client.on('data', (chunk) => {
      buffer += String(chunk)
      if (buffer.includes('\n') || buffer.length > 64) {
        const command = buffer.trim().toLowerCase()
        if (command === 'focus' || command === 'show' || command === '' || command === 'open') {
          try {
            options.onFocus()
          } catch (error) {
            console.error('desktop instance socket: error focusing primary window', error)
          }
        }
        client.write('ok\n')
        client.end()
      }
    })
    client.on('error', () => {
      // Non-fatal if client disconnects abruptly
    })
  })

  server.on('error', (error) => {
    console.warn('desktop instance socket server error:', error)
  })

  try {
    server.listen(socketPath)
  } catch (error) {
    console.warn('desktop instance socket: unable to listen on socket', error)
  }

  return () => {
    try {
      server.close()
    } catch {
      // Server may already be closed
    }
    try {
      if (fs.existsSync(socketPath)) {
        fs.unlinkSync(socketPath)
      }
    } catch {
      // Ignore cleanup error on shutdown
    }
  }
}

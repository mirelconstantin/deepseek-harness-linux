/** Node.js startup environment and executable selection for the Desktop Host. */

import { execFileSync } from 'node:child_process'
import { delimiter } from 'node:path'
import { satisfies } from 'semver'

/** Node.js versions the Host runs on; mirrors the workspace `engines.node` range. */
const HOST_NODE_RANGE = '^22.19.0 || >=24.0.0'

function runsHostNode(candidate: string): boolean {
  try {
    const reported = execFileSync(candidate, ['--version'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 5_000,
    })
    return satisfies(reported.trim().replace(/^v/u, ''), HOST_NODE_RANGE)
  } catch (_notHostNode) {
    // A candidate that cannot report its version is not a Host runtime.
    return false
  }
}

/**
 * Choose the executable that runs the Host.
 *
 * Electron on Linux exports the system GLib symbols into the process, so sharp's bundled
 * libvips (attachment image work) passes its own GObject instances to Electron's GLib:
 * `G_IS_OBJECT` criticals accumulate and a SIGTRAP eventually ends the Host (electron#46323).
 * The standalone Node.js the application already carries for LibreOffice Kit keeps GLib out of
 * the process, so Linux runs the Host there; Electron's Node mode is unaffected on macOS and
 * Windows.
 * @param platform - Shell platform.
 * @param node - Bundled standalone Node.js executable; absent or unusable falls back to Electron.
 * @param electron - Electron executable running the application.
 * @param probe - Version probe for the bundled runtime.
 * @returns Executable that runs the Host.
 */
export function resolveHostExecutable(
  platform: NodeJS.Platform,
  node: string,
  electron: string,
  probe: (candidate: string) => boolean = runsHostNode,
): string {
  if (platform !== 'linux') return electron
  return probe(node) ? node : electron
}

/**
 * Select Electron's Node mode and the shell launcher used by package scripts.
 * @param executable - Executable running the Host; a Node.js runtime ignores the mode variable.
 * @param bin - Directory containing the node shell launcher.
 * @param environment - Caller environment preserved for plugin execution.
 * @returns Environment for a Node-mode child process.
 */
export function desktopNodeEnvironment(executable: string, bin: string | undefined, environment: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  return {
    ...environment,
    ELECTRON_RUN_AS_NODE: '1',
    ...(bin === undefined ? {} : { DSH_DESKTOP_NODE_EXECUTABLE: executable, PATH: `${bin}${delimiter}${environment.PATH ?? ''}` }),
  }
}

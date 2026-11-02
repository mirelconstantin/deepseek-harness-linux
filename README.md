# DeepSeek Harness for Linux (`deepseek-harness-linux`)

> Native desktop workbench and runtime for DeepSeek agents, adapted for Linux (Wayland & X11).

DeepSeek officially provides pre-packaged desktop installers for Windows (`.exe`) and macOS (`.dmg`), but has yet to publish standalone Linux desktop builds. This project bridges that gap by tailoring **DeepSeek Harness** (`dsh`) directly for all compatible Linux desktop environments (GNOME, KDE Plasma, XFCE, Ubuntu, Debian, Fedora, Arch, Zorin OS, and all compatible systems).

| Aspect | Specification |
|---|---|
| **Upstream Base** | [`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness) (`v0.2.1-rc.2`) |
| **Platform** | Linux `x86_64` / `arm64` (Wayland & X11) |
| **Desktop Shell** | Electron 44.x, Chromium 132+, native Wayland CSD, dynamic dark/light theme |
| **Sandboxing** | Linux Landlock LSM (`landlock-run`) + POSIX `flock` native bindings |
| **Agent Kernel** | Composable plugin micro-framework powered by [Cordis](https://github.com/cordiverse/cordis) |
| **Language & Toolchain** | TypeScript (strict), Node.js (>=22.19 / >=24), pnpm 11+ |
| **License** | [MIT](LICENSE) |

---

## Why This Port?

DeepSeek Harness is an open-source agent workbench capable of running multi-turn coding tasks, autonomous browser/computer interactions, background automation, and reasoning workflows.

While the underlying engine is cross-platform, running the desktop client on Linux out of the box suffered from several desktop integration issues:
1. **Dock / Taskbar Association:** Wayland `xdg_toplevel` surfaces defaulted to generic application IDs, causing GNOME and dock managers to display a generic fallback gear icon instead of the official DeepSeek whale mark.
2. **Cluttered In-Window Menus:** Electron inserted an unnecessary Win95-style `Application / Edit` menu row inside the window beneath the system title bar, conflicting with modern GNOME CSD guidelines.
3. **Missing Linux Build Targets:** Packaging scripts originally restricted build targets to `win-x64` and `mac-arm64`/`mac-x64`, blocking local desktop packaging and runtime initialization on Linux hosts.
4. **GLib & Sharp Conflicts:** Electron on Linux exports system GLib symbols into the host process, colliding with `sharp`'s bundled `libvips` image processor and triggering SIGTRAP crashes (Electron issue #46323). Resolved by hosting the backend runtime under standalone Node.js.
5. **Desktop Launcher Absence:** No system `.desktop` file, scalable icons, or system tray handlers existed for Linux desktop environments.

This distribution eliminates these discrepancies to deliver a clean, distraction-free desktop experience.

---

## Features

- **Native Linux Window Integration:** The top header renders cleanly without redundant menu bars, perfectly matching modern Linux desktop styling (GNOME, KDE Plasma, Wayland & X11).
- **System Tray Presence & Instant Restore:** When closed, DeepSeek Harness minimizes to the Linux system tray (`StatusNotifierItem` / AppIndicator). Your running agent tasks stay active in the background, and reopening the window is instantaneous.
- **Sub-10ms Fast Activation:** Clicking the application launcher or tray icon signals the running instance through a local Unix domain socket (`/tmp/deepseek-harness-$UID.sock`), bringing it to the front without restarting the engine.
- **Crash-Resistant Runtime:** Runs the backend Desktop Host on a decoupled Node.js process, preventing GLib symbol collisions with image libraries.
- **Wayland Dock Recognition:** Window metadata (`app_id`) correctly points to `deepseek-harness.desktop`, keeping the official high-resolution icon in your dock, panel, and Alt+Tab switcher.
- **Flatpak & Native Packaging:** Standalone Flatpak installer bundle (`.flatpak`) and desktop integration scripts for seamless installation across all compatible Linux distributions.
- **Uncompromised Landlock Confinement:** Local subprocesses and agent tools run confined inside Linux Landlock sandboxes.
- **Full Model & Feature Suite:** DeepSeek-V3, DeepSeek-V4-Flash, and DeepSeek-R1 support with real-time streaming, tools execution, and profile management.
- **Desktop Launcher & CLI:** Start the GUI with a single click from your system application menu or launch via the `deepseek-harness` command line.

---

## How It Works

```
┌────────────────────────────────────────────────────────┐
│                   Desktop Shell (Electron)             │
│   • Wayland app_id: deepseek-harness.desktop           │
│   • Clean borderless frame (autoHideMenuBar: true)     │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│               apps/desktop-host (RPC Engine)           │
│   • Profile loader & session persistence               │
│   • Node-API flock locks (native/system)               │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│               Cordis Plugin Ecosystem (`dsh`)          │
│   • Agent loop, skills, and tools                      │
│   • Landlock LSM subprocess sandbox (`landlock-run`)   │
│   • DeepSeek API Gateway & Web Frontend UI             │
└────────────────────────────────────────────────────────┘
```

---

## Quick Start & Installation

> [!IMPORTANT]
> **Do not use `npm install`.** This repository is a high-performance `pnpm` monorepo workspace. Running `npm install` will fail because `npm` cannot resolve `workspace:*` packages. Use `./setup.sh` or `pnpm install`.

### 1. Automated One-Command Setup (Recommended)

On any compatible Linux machine (Ubuntu, Debian, Fedora, Arch, Zorin OS, openSUSE, etc.):

```bash
git clone https://github.com/mirelconstantin/deepseek-harness-linux.git
cd deepseek-harness-linux
./setup.sh
```

`./setup.sh` takes care of everything automatically:
- Checks Node.js (installs Node 24 LTS via NodeSource if missing or outdated)
- Installs `pnpm` if not already installed
- Installs workspace dependencies cleanly via `pnpm install`
- Builds all project artifacts (`pnpm run build`)
- Installs desktop launcher entries, multi-size icons, and the `deepseek-harness` command to `~/.local/bin`

Once complete, open **DeepSeek Harness** from your system Application Menu or run `deepseek-harness` from any terminal.

### 2. Manual Step-by-Step Installation

```bash
# 1. Clone repository
git clone https://github.com/mirelconstantin/deepseek-harness-linux.git
cd deepseek-harness-linux

# 2. Install pnpm (if not already installed)
npm install -g pnpm

# 3. Install workspace dependencies
pnpm install

# 4. Build artifacts
pnpm run build

# 5. Install Desktop Launcher & Icons to system
./scripts/install-desktop.sh

# 6. Launch Desktop application
deepseek-harness
```

### 3. Flatpak Package (Single-File Easy Install)

To build a standalone `.flatpak` bundle for any compatible Linux distribution:

```bash
# Install flatpak-builder if needed
sudo apt install -y flatpak flatpak-builder

# Build bundle
./flatpak/build-flatpak.sh

# Install bundle
flatpak install --user flatpak/com.deepseek.harness.flatpak
```

Or double-click `com.deepseek.harness.flatpak` in your file manager to install via the Software Store.

### 4. Alternative: Run as Local Web UI
If you prefer running inside your default web browser rather than Electron:
```bash
pnpm dsh web
```
The server will start at `http://127.0.0.1:3080`.

---

## Project Structure

```
apps/
  ├── desktop/         # Electron desktop shell & Linux launcher integration
  ├── desktop-host/    # Desktop backend RPC host
  ├── cli/             # 'dsh' profile & plugin CLI entry point
  └── web/             # Frontend web client & UI cards
packages/
  ├── core/            # Agent loops, session formats, and tools
  ├── llm/             # DeepSeek model provider and streaming adapters
  ├── sandbox/         # Process confinement and isolation policy
  └── client/          # Shared React UI components and layouts
native/
  └── system/          # Landlock launcher and glibc/musl Node-API binaries
```

---

## License

MIT. See [LICENSE](LICENSE). Portions Copyright (c) 2026 DeepSeek AI and contributors. Linux adaptations built by Pazalo.

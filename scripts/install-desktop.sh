#!/usr/bin/env bash
set -euo pipefail

# DeepSeek Harness Desktop Installer for Linux (Wayland & X11 - all compatible systems)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"

echo "=== Installing DeepSeek Harness Desktop on Linux ==="

# 1. Create target directories
mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_BASE/512x512/apps" "$ICON_BASE/scalable/apps"

# 2. Install high-resolution application icons for all standard theme sizes
echo "[1/4] Installing application icons..."
cp "$REPO_ROOT/apps/desktop/resources/icon.png" "$ICON_BASE/512x512/deepseek-harness.png"
if [ -f "$REPO_ROOT/apps/desktop/resources/icon.svg" ]; then
  cp "$REPO_ROOT/apps/desktop/resources/icon.svg" "$ICON_BASE/scalable/apps/deepseek-harness.svg"
fi

if python3 -c "import PIL" 2>/dev/null; then
  export REPO_ROOT
  python3 - << 'PYEOF'
import os
from PIL import Image

repo_root = os.environ.get("REPO_ROOT") or "."
icon_path = os.path.join(repo_root, "apps", "desktop", "resources", "icon.png")
icon = Image.open(icon_path)
sizes = [16, 22, 24, 32, 48, 64, 96, 128, 256, 512]
home = os.path.expanduser("~")

for size in sizes:
    target_dir = os.path.join(home, ".local", "share", "icons", "hicolor", f"{size}x{size}", "apps")
    os.makedirs(target_dir, exist_ok=True)
    icon.resize((size, size), Image.Resampling.LANCZOS).save(os.path.join(target_dir, "deepseek-harness.png"))
PYEOF
fi

# 3. Install CLI launcher script in ~/.local/bin
echo "[2/4] Installing launcher in $BIN_DIR/deepseek-harness..."
cat << 'EOF' > "$BIN_DIR/deepseek-harness"
#!/usr/bin/env bash
set -e

# Fast wake-up via IPC socket if instance is already running (<10ms)
SOCKET_PATH="${XDG_RUNTIME_DIR:-/tmp}/deepseek-harness.sock"
if [ ! -S "$SOCKET_PATH" ]; then
  SOCKET_PATH="/tmp/deepseek-harness-$(id -u).sock"
fi

if [ -S "$SOCKET_PATH" ]; then
  if command -v nc >/dev/null 2>&1; then
    if echo "focus" | nc -U -w 1 "$SOCKET_PATH" 2>/dev/null; then
      exit 0
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 -c "import socket; s = socket.socket(socket.AF_UNIX); s.settimeout(0.5); s.connect('$SOCKET_PATH'); s.sendall(b'focus\n'); s.close()" 2>/dev/null; then
      exit 0
    fi
  elif command -v node >/dev/null 2>&1; then
    if node -e "const net = require('node:net'); const c = net.connect('$SOCKET_PATH', () => { c.write('focus\n'); c.end(); process.exit(0); }); c.on('error', () => process.exit(1));" 2>/dev/null; then
      exit 0
    fi
  fi
fi

# Detect Node.js from NVM or standard PATH
if [ -d "$HOME/.nvm/versions/node" ]; then
  LATEST_NODE="$(ls -vd "$HOME/.nvm/versions/node/"* 2>/dev/null | tail -n 1)"
  if [ -n "$LATEST_NODE" ] && [ -d "$LATEST_NODE/bin" ]; then
    export PATH="$LATEST_NODE/bin:$HOME/.local/bin:$PATH"
  fi
fi
if [ -d "$HOME/.local/share/pnpm" ]; then
  export PATH="$HOME/.local/share/pnpm:$PATH"
fi

REPO_DIR="__REPO_ROOT__"
cd "$REPO_DIR"

# Optimized direct Electron launch (bypasses pnpm, tsx, and 9.3s primary-runtime test overhead)
ELECTRON_BIN="$REPO_DIR/node_modules/.pnpm/electron@44.7.0_supports-color@9.4.0/node_modules/electron/dist/electron"
if [ ! -x "$ELECTRON_BIN" ]; then
  ELECTRON_BIN="$(node -e 'try { console.log(require("electron")) } catch(e){}' 2>/dev/null || true)"
fi
DEV_PROJECT="$REPO_DIR/apps/desktop/.desktop-build/development/project"
PRIMARY_RUNTIME="$REPO_DIR/apps/desktop/.desktop-build/targets/linux-x64/runtime/primary-runtime"

if [ -x "$ELECTRON_BIN" ] && [ -d "$DEV_PROJECT" ] && [ -d "$PRIMARY_RUNTIME" ]; then
  export DSH_HOME="$REPO_DIR/apps/desktop/.desktop-build/development/home"
  export DSH_DESKTOP_PRIMARY_RUNTIME_DIR="$PRIMARY_RUNTIME"
  export DSH_DESKTOP_DEV_APP="1"
  export CHROME_DESKTOP="deepseek-harness.desktop"
  export ELECTRON_ENABLE_LOGGING="0"
  export DSH_DESKTOP_OPEN_DEVTOOLS="0"

  exec "$ELECTRON_BIN" \
    --user-data-dir="$REPO_DIR/apps/desktop/.desktop-build/development/electron-user-data" \
    --class=deepseek-harness \
    --name=deepseek-harness \
    "$REPO_DIR/apps/desktop" "$@"
fi

# Fallback to dev runner if development artifacts are not yet prepared
exec pnpm run start:desktop "$@"
EOF
sed -i "s|__REPO_ROOT__|$REPO_ROOT|g" "$BIN_DIR/deepseek-harness"
chmod +x "$BIN_DIR/deepseek-harness"

# 4. Install desktop entry in ~/.local/share/applications
echo "[3/4] Installing desktop entry in $APP_DIR/deepseek-harness.desktop..."
cat <<EOF > "$APP_DIR/deepseek-harness.desktop"
[Desktop Entry]
Version=1.0
Name=DeepSeek Harness
GenericName=AI Agent Workbench
Comment=Everything is a Plugin - DeepSeek Agent Harness Desktop Application
Exec=$BIN_DIR/deepseek-harness %U
Icon=deepseek-harness
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
StartupWMClass=deepseek-harness
MimeType=x-scheme-handler/dsh;
Keywords=ai;deepseek;agent;harness;llm;chat;
EOF
chmod +x "$APP_DIR/deepseek-harness.desktop"

# 5. Register protocol handler and update databases
echo "[4/4] Updating desktop databases..."
if command -v xdg-mime &>/dev/null; then
  xdg-mime default deepseek-harness.desktop x-scheme-handler/dsh || true
fi
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APP_DIR" || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo ""
echo "=== Installation Complete! ==="
echo "DeepSeek Harness is installed and ready."
echo "You can launch it from your Applications menu or run 'deepseek-harness' in terminal."

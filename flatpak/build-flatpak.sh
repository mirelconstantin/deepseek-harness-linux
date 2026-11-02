#!/usr/bin/env bash
set -euo pipefail

# DeepSeek Harness Flatpak Builder for Linux (Ubuntu, Debian, Fedora, Arch, Zorin OS, and compatible systems)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIST="$SCRIPT_DIR/app-dist"
BUILD_DIR="$SCRIPT_DIR/.flatpak-build"
REPO_DIR="$SCRIPT_DIR/.flatpak-repo"
BUNDLE_OUTPUT="$SCRIPT_DIR/com.deepseek.harness.flatpak"

echo "=== DeepSeek Harness Flatpak Builder ==="

# 1. Check Node.js and pnpm
if ! command -v node &>/dev/null; then
  echo "Error: Node.js is not installed."
  echo "Please install Node.js 22 or 24."
  echo "  curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -"
  echo "  sudo apt install -y nodejs"
  exit 1
fi

if ! command -v pnpm &>/dev/null; then
  echo "Notice: 'pnpm' not found. Installing pnpm..."
  if command -v corepack &>/dev/null; then
    corepack enable || true
    corepack prepare pnpm@11.28.5 --activate || true
  fi
  if ! command -v pnpm &>/dev/null && command -v npm &>/dev/null; then
    npm install -g pnpm || sudo npm install -g pnpm || true
  fi
  if ! command -v pnpm &>/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=11.28.5 sh -
    export PATH="$HOME/.local/share/pnpm:$PATH"
  fi
fi

# 2. Check flatpak & flatpak-builder
if ! command -v flatpak &>/dev/null; then
  echo "Error: 'flatpak' is not installed."
  echo "On Zorin OS / Ubuntu, install with: sudo apt install -y flatpak"
  exit 1
fi

if ! command -v flatpak-builder &>/dev/null; then
  echo "Warning: 'flatpak-builder' is not installed."
  if command -v sudo &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y flatpak-builder || true
  fi
  if ! command -v flatpak-builder &>/dev/null; then
    echo "Please install flatpak-builder manually and re-run: sudo apt install -y flatpak-builder"
    exit 1
  fi
fi

# 3. Ensure Flathub remote and runtime dependencies
echo "[1/4] Ensuring Freedesktop 24.08 runtime is installed..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
flatpak install --user -y flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08 || true

# 4. Prepare application payload
echo "[2/4] Preparing application binaries..."
mkdir -p "$APP_DIST"
rm -rf "$APP_DIST"/*

cd "$REPO_ROOT"
if [ ! -d "node_modules" ]; then
  pnpm install
fi

# Check if packaged desktop directory exists, otherwise prepare it
PACKAGED_DIR="$REPO_ROOT/apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts/linux-unpacked"
if [ ! -d "$PACKAGED_DIR" ]; then
  PACKAGED_DIR="$REPO_ROOT/apps/desktop/.desktop-build/artifacts/linux-unpacked"
fi

if [ ! -d "$PACKAGED_DIR" ]; then
  echo "Building unpacked desktop directory..."
  pnpm --filter @deepseek-ai/dsh-desktop run package:linux:x64:dir
  if [ ! -d "$PACKAGED_DIR" ]; then
    PACKAGED_DIR="$(find "$REPO_ROOT/apps/desktop/.desktop-build" -type d -name "linux-unpacked" 2>/dev/null | head -n 1 || true)"
  fi
fi

if [ -z "$PACKAGED_DIR" ] || [ ! -d "$PACKAGED_DIR" ]; then
  echo "Error: Could not locate packaged desktop directory."
  exit 1
fi

# Copy packaged app contents into app-dist
cp -r "$PACKAGED_DIR"/* "$APP_DIST/"
cp "$SCRIPT_DIR/com.deepseek.harness.desktop" "$APP_DIST/"
cp "$SCRIPT_DIR/com.deepseek.harness.metainfo.xml" "$APP_DIST/"
cp "$REPO_ROOT/apps/desktop/resources/icon.png" "$APP_DIST/icon.png"
cp "$REPO_ROOT/apps/desktop/resources/icon.svg" "$APP_DIST/icon.svg"
cp "$REPO_ROOT/apps/desktop/resources/tray.png" "$APP_DIST/tray.png"

# 5. Build Flatpak
echo "[3/4] Building Flatpak with flatpak-builder..."
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR" "$REPO_DIR"
flatpak-builder --user --force-clean --repo="$REPO_DIR" "$BUILD_DIR" com.deepseek.harness.yaml

# 6. Export single-file .flatpak bundle
echo "[4/4] Creating single-file bundle: $BUNDLE_OUTPUT..."
flatpak build-bundle "$REPO_DIR" "$BUNDLE_OUTPUT" com.deepseek.harness

echo ""
echo "=== Flatpak Build Succeeded! ==="
echo "Bundle created at: $BUNDLE_OUTPUT"
echo ""
echo "To install on this system or any compatible Linux machine, run:"
echo "  flatpak install --user $BUNDLE_OUTPUT"
echo "Or double-click the file in your file manager to install via Software Store."

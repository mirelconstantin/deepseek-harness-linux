#!/usr/bin/env bash
set -euo pipefail

# DeepSeek Harness Linux - Automated Setup & Installer
# Supported on Zorin OS, Ubuntu, Debian, Fedora, Arch, etc.

echo "========================================================"
echo "    DeepSeek Harness for Linux - One-Click Setup"
echo "========================================================"
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# 1. Check Node.js
echo "[1/4] Checking Node.js environment..."
NODE_OK=0
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node -v | sed 's/^v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  NODE_MINOR=$(echo "$NODE_VER" | cut -d. -f2)
  if [ "$NODE_MAJOR" -gt 22 ] || ([ "$NODE_MAJOR" -eq 22 ] && [ "$NODE_MINOR" -ge 19 ]); then
    NODE_OK=1
    echo "  ✓ Node.js v$NODE_VER detected"
  fi
fi

if [ "$NODE_OK" -eq 0 ]; then
  CURRENT_NODE=$(node -v 2>/dev/null || echo "not installed")
  echo "  Warning: Node.js >= 22.19 or 24 is required (current: $CURRENT_NODE)."
  echo "  Attempting to install Node.js 24 LTS..."
  if command -v curl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs
  else
    echo "  Error: Please install Node.js 24 from https://nodejs.org/ and re-run ./setup.sh"
    exit 1
  fi
fi

# 2. Check and configure pnpm
echo "[2/4] Checking pnpm package manager..."
if ! command -v pnpm >/dev/null 2>&1; then
  echo "  pnpm not found. Installing pnpm..."
  if command -v corepack >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
    corepack prepare pnpm@11.28.5 --activate >/dev/null 2>&1 || true
  fi
  if ! command -v pnpm >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    npm install -g pnpm >/dev/null 2>&1 || sudo npm install -g pnpm >/dev/null 2>&1 || true
  fi
  if ! command -v pnpm >/dev/null 2>&1; then
    curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=11.28.5 sh -
    export PATH="$HOME/.local/share/pnpm:$PATH"
  fi
fi

if command -v pnpm >/dev/null 2>&1; then
  echo "  ✓ pnpm $(pnpm -v) ready"
else
  echo "  Error: Failed to install pnpm. Please run: npm install -g pnpm"
  exit 1
fi

# 3. Install dependencies & build packages
echo "[3/4] Installing workspace dependencies and building packages..."
echo "  Running pnpm install (do not use npm install on this pnpm monorepo)..."
pnpm install
echo "  Building project artifacts..."
pnpm run build

# 4. Install Desktop Launcher & System Integration
echo "[4/4] Installing desktop entry, icons, and launcher..."
chmod +x ./scripts/install-desktop.sh
./scripts/install-desktop.sh

echo ""
echo "========================================================"
echo "    ✓ DeepSeek Harness installed successfully!"
echo "========================================================"
echo "You can now launch it:"
echo "  • From your system Application Menu (search 'DeepSeek Harness')"
echo "  • By running 'deepseek-harness' in any terminal"
echo "  • Or run 'pnpm run start:desktop' inside this directory"
echo "========================================================"

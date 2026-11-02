# DeepSeek Harness Flatpak for Linux

This directory contains the complete Flatpak manifest, desktop integration assets, and build automation to package and install DeepSeek Harness as a self-contained Flatpak application for all compatible Linux distributions.

## Prerequisites

On Ubuntu / Debian / Zorin OS / Mint, ensure `flatpak` and `flatpak-builder` are installed:

```bash
sudo apt update
sudo apt install -y flatpak flatpak-builder
```

## Quick Build & Installation

Run the automated build script:

```bash
./flatpak/build-flatpak.sh
```

This will:
1. Ensure the Freedesktop 24.08 runtime and Electron BaseApp are downloaded.
2. Package the Linux Electron application into `flatpak/app-dist`.
3. Build the Flatpak package via `flatpak-builder`.
4. Generate a standalone `com.deepseek.harness.flatpak` single-file installer bundle.

## Installing the Flatpak Bundle

Once built, you can install it on any compatible Linux system with:

```bash
flatpak install --user com.deepseek.harness.flatpak
```

Or simply double-click `com.deepseek.harness.flatpak` in your file manager to open and install via your system Software store.

## Running the Flatpak Application

Once installed, launch it directly from your application launcher or from the terminal:

```bash
flatpak run com.deepseek.harness
```

## Permissions & Host Access

The manifest specifies:
- Full host filesystem access (`--filesystem=host`) so DeepSeek agents can read/write your project workspaces and repositories.
- System tray integration (`--talk-name=org.kde.StatusNotifierWatcher` / `--own-name=org.kde.StatusNotifierItem-*-*`) so the app stays active in the background tray when closed.
- X11 and Wayland graphics sockets with hardware acceleration (`--device=dri`).

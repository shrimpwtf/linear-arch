# linear-bin

Unofficial Arch Linux package for [Linear](https://linear.app) — extracts the Windows installer and runs it via system Electron. Registers the `linear://` URL scheme so coding tools (Cursor, Claude Code, etc.) can open issues directly in the desktop app.

## Installation

```bash
yay -S linear-bin
```

Or, on non-Arch distros, run the standalone installer:

```bash
./install.sh
```

## Auto-updates

A GitHub Actions workflow runs daily, checks `releases.linear.app/latest.yml` for new releases, and automatically updates the PKGBUILD and pushes to AUR. No manual maintenance required.

The package's in-app updater is stubbed on Linux (Linear doesn't host a `latest-linux.yml`), so AUR is the sole source of truth for updates.

## Deep links

Cursor, Claude Code, and other coding tools use `linear://` URLs to open specific issues. Once installed, those links open Linear directly instead of the browser.

## Notes

- Requires `electron` from the Arch repos
- This is an unofficial port — not affiliated with Linear Orbit, Inc.
- The app is extracted from the Windows NSIS installer and patched to disable the in-app updater on Linux
- ARM64 build is also bundled inside the Windows installer (`app-arm64.7z`); only `x86_64` is built by default — see PKGBUILD if you want to extend

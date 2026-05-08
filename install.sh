#!/bin/bash
# Linear Linux Installer (unofficial)
# Extracts the Windows installer and runs the app via system electron.
# Use this on non-Arch distros or when you don't want a system package.

set -e

LINEAR_VERSION="1.30.0"
LINEAR_URL="https://releases.linear.app/Linear%20Setup%20${LINEAR_VERSION}.exe"
INSTALL_DIR="$HOME/.local/share/linear"
BIN_DIR="$HOME/.local/bin"

echo "=== Linear Linux Installer (unofficial) ==="
echo ""

for cmd in 7z electron; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed."
        case $cmd in
            7z)
                echo "  Arch:    sudo pacman -S p7zip"
                echo "  Debian:  sudo apt install p7zip-full"
                echo "  Fedora:  sudo dnf install p7zip"
                ;;
            electron)
                echo "  Arch:    sudo pacman -S electron"
                echo "  Debian:  see https://github.com/electron/electron/releases"
                ;;
        esac
        exit 1
    fi
done

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

echo "[1/4] Downloading Linear ${LINEAR_VERSION}..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
curl -L -o "Linear-Setup.exe" "$LINEAR_URL"

echo "[2/4] Extracting NSIS installer..."
7z x -y "Linear-Setup.exe" -oextracted > /dev/null

# Linear's NSIS installer ships both x64 and arm64 archives; pick by host arch.
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
    x86_64) APP_ARCHIVE='extracted/$PLUGINSDIR/app-64.7z' ;;
    aarch64|arm64) APP_ARCHIVE='extracted/$PLUGINSDIR/app-arm64.7z' ;;
    *)
        echo "Error: unsupported architecture '$HOST_ARCH' (need x86_64 or aarch64)"
        rm -rf "$TEMP_DIR"
        exit 1
        ;;
esac

7z x -y "$APP_ARCHIVE" -oapp > /dev/null

echo "[3/4] Installing app payload..."
ASAR_PATH=$(find app -name 'app.asar' -type f | head -1)
if [ -z "$ASAR_PATH" ]; then
    echo "Error: Could not find app.asar in extracted files"
    rm -rf "$TEMP_DIR"
    exit 1
fi

RESOURCES_DIR=$(dirname "$ASAR_PATH")
cp "$RESOURCES_DIR/app.asar" "$INSTALL_DIR/"
[ -d "$RESOURCES_DIR/app.asar.unpacked" ] && cp -r "$RESOURCES_DIR/app.asar.unpacked" "$INSTALL_DIR/"

if [ -f "$(dirname "$0")/patch-main.py" ]; then
    echo "  Applying Linux integration patch..."
    (cd "$INSTALL_DIR" && python3 "$(dirname "$0")/patch-main.py") || true
fi

if command -v wrestool &> /dev/null && command -v icotool &> /dev/null; then
    EXE_FILE=$(find app -name 'Linear.exe' -type f | head -1)
    if [ -n "$EXE_FILE" ]; then
        wrestool -x -t 14 "$EXE_FILE" -o linear.ico 2>/dev/null || true
        if [ -f "linear.ico" ]; then
            icotool -x linear.ico 2>/dev/null || true
            ICON_256=$(ls linear_*256x256*.png 2>/dev/null | head -1)
            [ -n "$ICON_256" ] && cp "$ICON_256" "$INSTALL_DIR/linear.png"
        fi
    fi
fi

echo "[4/4] Creating launcher and desktop entry..."
cat > "$BIN_DIR/linear" << 'EOF'
#!/bin/sh
exec electron --class=Linear --name=Linear "$HOME/.local/share/linear/app.asar" "$@"
EOF
chmod +x "$BIN_DIR/linear"

# Desktop entry. linear:// MimeType registers the deep-link handler for
# Cursor / Claude Code / etc. to open issues directly in the desktop app.
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/linear.desktop" << EOF
[Desktop Entry]
Name=Linear
GenericName=Issue Tracking
Comment=Linear desktop client
Exec=$BIN_DIR/linear %u
Icon=$INSTALL_DIR/linear.png
Type=Application
Terminal=false
Categories=Office;ProjectManagement;Development;
MimeType=x-scheme-handler/linear;
StartupWMClass=Linear
EOF

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

rm -rf "$TEMP_DIR"

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Run with: linear"
echo "  (make sure $BIN_DIR is in your PATH)"
echo ""
echo "Or run directly: electron $INSTALL_DIR/app.asar"
echo ""
echo "linear:// deep links from Cursor / Claude Code / etc. will open this app."

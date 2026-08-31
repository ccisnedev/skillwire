#!/usr/bin/env bash
# install.sh — Install the skillwire CLI from GitHub Releases (Linux)
#
#   curl -fsSL https://skillwire.ccisne.dev/install.sh | bash
#
# This file is served from the site and exists nowhere else in the repository.
# A second copy under code/cli/ would be the copy that drifts, and the drifted
# one is always the one people actually run.

set -euo pipefail

REPO="ccisnedev/skillwire"
ASSET="skillwire-linux-x64.tar.gz"
INSTALL_DIR="$HOME/.skillwire"
BIN_DIR="$INSTALL_DIR/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Installing the skillwire CLI..."

# 1. Find the latest release
API_URL="https://api.github.com/repos/$REPO/releases/latest"
RELEASE=$(curl -fsSL -H "User-Agent: skillwire-installer" "$API_URL")
TAG=$(echo "$RELEASE" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
DL_URL=$(echo "$RELEASE" | grep "browser_download_url" | grep "$ASSET" | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

if [[ -z "$DL_URL" ]]; then
    echo "Error: asset '$ASSET' not found in release $TAG" >&2
    exit 1
fi

echo "Downloading $TAG..."
curl -fsSL -o "$TMP_DIR/$ASSET" "$DL_URL"

# 2. Extract.
#    The archive holds bin/ and assets/, and that shape is load-bearing: the CLI
#    resolves its skills as <dir of the exe>/../assets, so moving either one
#    breaks `skill deploy` with no error until it is run.
echo "Extracting to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
tar xzf "$TMP_DIR/$ASSET" -C "$INSTALL_DIR"

# 3. Executable bit, and the `sw` alias
chmod +x "$BIN_DIR/skillwire"
ln -sf "$BIN_DIR/skillwire" "$BIN_DIR/sw"

# 4. PATH
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$profile" ]] && ! grep -q '.skillwire/bin' "$profile"; then
        {
            echo ''
            echo '# skillwire CLI'
            echo 'export PATH="$HOME/.skillwire/bin:$PATH"'
        } >> "$profile"
        echo "Added a PATH entry to $profile"
        break
    fi
done

echo ""
echo "skillwire $TAG installed. Reload your shell, then:"
echo "  skillwire skill list --host claude --scope global --all"

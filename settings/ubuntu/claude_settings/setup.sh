#!/bin/bash

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# GitHub repository settings
GITHUB_USER="JO-Gaehwan"
REPO_NAME="shell"
BRANCH="main"
SETTINGS_PATH="settings/ubuntu/claude_settings"

# Local paths
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
NPM_GLOBAL="$HOME/.npm-global"

# Install Node.js if needed
install_nodejs() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
        
        if [ "$NODE_MAJOR" -ge 18 ]; then
            echo "✓ Node.js v$NODE_VERSION is installed"
            return 0
        fi
    fi
    
    echo "Installing Node.js 20.x LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
}

# Configure npm for user-level packages
configure_npm() {
    mkdir -p "$NPM_GLOBAL"
    npm config set prefix "$NPM_GLOBAL"
    
    if [[ ":$PATH:" != *":$NPM_GLOBAL/bin:"* ]]; then
        echo "export PATH=\"$NPM_GLOBAL/bin:\$PATH\"" >> ~/.bashrc
        export PATH="$NPM_GLOBAL/bin:$PATH"
    fi
}

# Install Claude Code
install_claude_code() {
    if [ -f "$NPM_GLOBAL/bin/claude" ] || command -v claude &> /dev/null; then
        echo "✓ Claude Code is already installed"
        return 0
    fi
    
    configure_npm
    npm install -g @anthropic-ai/claude-code
}

# Download settings
download_settings() {
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    curl -sL "https://github.com/$GITHUB_USER/$REPO_NAME/archive/$BRANCH.tar.gz" | tar -xz
    
    EXTRACTED_DIR="$REPO_NAME-$BRANCH/$SETTINGS_PATH"
    
    if [ -d "$EXTRACTED_DIR/commands" ]; then
        mkdir -p "$CLAUDE_DIR"
        rm -rf "$COMMANDS_DIR"  # 백업 없이 덮어쓰기
        cp -r "$EXTRACTED_DIR/commands" "$COMMANDS_DIR"
        chmod -R 755 "$COMMANDS_DIR"
    fi
    
    cd ~ && rm -rf "$TEMP_DIR"
}

# Main
echo "====================================="
echo "   Claude Code Setup Tool"
echo "====================================="

install_nodejs
configure_npm
install_claude_code
download_settings

echo "✨ Setup complete!"
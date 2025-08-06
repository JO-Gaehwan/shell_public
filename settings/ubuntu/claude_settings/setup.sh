#!/bin/bash

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# GitHub repository settings
GITHUB_USER="JO-Gaehwan"
REPO_NAME="shell_public"
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
    log_info "Downloading settings from GitHub..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 방법 1: refs/heads 포함한 전체 경로 사용
    ARCHIVE_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/$BRANCH.tar.gz"
    
    log_info "Fetching from: $ARCHIVE_URL"
    
    # -f 옵션 추가로 실패시 에러 반환
    if curl -fL "$ARCHIVE_URL" -o archive.tar.gz; then
        # 다운로드 성공 확인
        if [ -f archive.tar.gz ] && [ -s archive.tar.gz ]; then
            # 파일 타입 확인
            FILE_TYPE=$(file archive.tar.gz)
            log_info "Downloaded file type: $FILE_TYPE"
            
            # tar.gz 압축 해제
            if tar -xzf archive.tar.gz 2>/dev/null; then
                # 압축 해제된 디렉토리 찾기
                EXTRACTED_DIR=$(ls -d */ 2>/dev/null | head -n1)
                log_info "Extracted directory: $EXTRACTED_DIR"
                
                # commands 디렉토리 경로 확인
                COMMANDS_PATH="${EXTRACTED_DIR}${SETTINGS_PATH}/commands"
                
                if [ -d "$COMMANDS_PATH" ]; then
                    mkdir -p "$CLAUDE_DIR"
                    rm -rf "$COMMANDS_DIR"
                    cp -r "$COMMANDS_PATH" "$COMMANDS_DIR"
                    chmod -R 755 "$COMMANDS_DIR"
                    
                    COMMAND_COUNT=$(find "$COMMANDS_DIR" -type f | wc -l)
                    log_success "Imported $COMMAND_COUNT command files"
                else
                    log_error "Commands directory not found at: $COMMANDS_PATH"
                    log_info "Available directories:"
                    ls -la "${EXTRACTED_DIR}${SETTINGS_PATH}/" 2>/dev/null || echo "Path not found"
                fi
            else
                log_error "Failed to extract archive"
            fi
        else
            log_error "Downloaded file is empty or invalid"
        fi
    else
        log_error "Failed to download from GitHub"
        log_info "Please check if repository exists and is public"
    fi
    
    cd ~
    rm -rf "$TEMP_DIR"
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
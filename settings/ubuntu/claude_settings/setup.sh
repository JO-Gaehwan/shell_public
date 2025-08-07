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

# Install Node.js if needed
install_nodejs() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2)
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
        
        if [ "$NODE_MAJOR" -ge 18 ]; then
            log_success "Node.js v$NODE_VERSION is installed"
            return 0
        else
            log_error "Node.js v$NODE_VERSION is too old. Please update to v18+"
            exit 1
        fi
    else
        log_info "Installing Node.js 20.x LTS..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        log_success "Node.js installed successfully"
    fi
}

# Install Claude Code
install_claude_code() {
    if command -v claude &> /dev/null; then
        log_success "Claude Code is already installed"
        return 0
    fi
    
    log_info "Installing Claude Code..."
    
    # Install globally without any npm configuration
    if npm install -g @anthropic-ai/claude-code; then
        log_success "Claude Code installed successfully"
    else
        log_error "Failed to install Claude Code"
        echo ""
        echo "If you see permission errors, you have two options:"
        echo "1. Use nvm to manage Node.js (recommended)"
        echo "2. Run: sudo npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
}

# Download settings
download_settings() {
    log_info "Downloading settings from GitHub..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # GitHub archive URL with refs/heads
    ARCHIVE_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/$BRANCH.tar.gz"
    
    log_info "Fetching from: $GITHUB_USER/$REPO_NAME"
    
    if curl -fL "$ARCHIVE_URL" -o archive.tar.gz 2>/dev/null; then
        if [ -f archive.tar.gz ] && [ -s archive.tar.gz ]; then
            # Extract archive
            if tar -xzf archive.tar.gz 2>/dev/null; then
                # Find extracted directory
                EXTRACTED_DIR=$(ls -d */ 2>/dev/null | head -n1)
                log_info "Extracted directory: $EXTRACTED_DIR"
                
                # Path to commands
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

# Check authentication
check_auth() {
    log_info "Checking Claude authentication..."
    
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        log_success "API key found in environment"
    elif [ -f "$HOME/.claude/config.json" ] || [ -f "$HOME/.config/claude/config.json" ]; then
        log_success "Claude config file exists"
    else
        log_info "Claude not authenticated yet"
        echo ""
        echo "To authenticate, run 'claude' and follow the OAuth flow"
        echo "Or set: export ANTHROPIC_API_KEY='your-api-key'"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo "====================================="
    echo "   Installation Summary"
    echo "====================================="
    
    # Node.js status
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✓${NC} Node.js: $NODE_VERSION"
    fi
    
    # Claude Code status
    if command -v claude &> /dev/null; then
        echo -e "${GREEN}✓${NC} Claude Code: Installed"
    else
        echo -e "${YELLOW}○${NC} Claude Code: May need to restart terminal"
    fi
    
    # Commands status
    if [ -d "$COMMANDS_DIR" ]; then
        COMMAND_COUNT=$(find "$COMMANDS_DIR" -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} Custom Commands: $COMMAND_COUNT files"
        
        # Show first 5 commands
        if [ "$COMMAND_COUNT" -gt 0 ]; then
            echo ""
            echo "Available commands:"
            ls -1 "$COMMANDS_DIR" 2>/dev/null | head -5 | sed 's/^/  - /'
            [ "$COMMAND_COUNT" -gt 5 ] && echo "  ... and $((COMMAND_COUNT - 5)) more"
        fi
    else
        echo -e "${YELLOW}○${NC} Custom Commands: None"
    fi
    
    # Auth status
    if [ -n "$ANTHROPIC_API_KEY" ] || [ -f "$HOME/.claude/config.json" ] || [ -f "$HOME/.config/claude/config.json" ]; then
        echo -e "${GREEN}✓${NC} Authentication: Configured"
    else
        echo -e "${YELLOW}○${NC} Authentication: Not configured"
    fi
    
    echo "====================================="
}

# Main execution
echo "====================================="
echo "   Claude Code Setup Tool"
echo "====================================="
echo ""

# Run installation steps
install_nodejs
install_claude_code
download_settings
check_auth
show_summary

echo ""
log_success "✨ Setup complete!"

# Final instructions
if ! command -v claude &> /dev/null; then
    echo ""
    echo "To start using Claude Code, run:"
    echo "  source ~/.bashrc"
    echo "Or open a new terminal"
fi
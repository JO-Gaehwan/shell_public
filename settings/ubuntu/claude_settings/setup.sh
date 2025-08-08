#!/bin/bash
set -e  # Exit on unhandled errors

# ========= Colors =========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========= Logging =========
log_info()    { echo -e "${YELLOW}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error()   { echo -e "${RED}✗ $1${NC}"; }

# ========= GitHub repository settings =========
GITHUB_USER="JO-Gaehwan"
REPO_NAME="shell_public"
BRANCH="main"
SETTINGS_PATH="settings/ubuntu/claude_settings"

# ========= Local paths =========
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"

# ========= Helpers =========
have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_path_line() {
  local line='export PATH="$HOME/.local/bin:$PATH"'
  if ! grep -qF "$line" "$HOME/.bashrc" 2>/dev/null; then
    echo "$line" >> "$HOME/.bashrc"
  fi
  # ensure session has it too
  export PATH="$HOME/.local/bin:$PATH"
}

# ========= Install Node.js (Nodesource 20.x) =========
install_nodejs() {
  if have_cmd node; then
    local NODE_VERSION NODE_MAJOR
    NODE_VERSION=$(node --version | cut -d'v' -f2)
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
      log_success "Node.js v$NODE_VERSION is installed"
      return 0
    else
      log_error "Node.js v$NODE_VERSION is too old. Updating to v20..."
    fi
  else
    log_info "Installing Node.js 20.x LTS..."
  fi

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  log_success "Node.js installed successfully ($(node --version))"
}

# ========= Install Claude Code with fallbacks =========
install_claude_code() {
  if have_cmd claude; then
    log_success "Claude Code is already installed"
    return 0
  fi

  log_info "Installing Claude Code (global)..."
  if npm install -g @anthropic-ai/claude-code; then
    log_success "Claude Code installed successfully (system global)"
    return 0
  fi

  log_info "Global install failed. Falling back to user-local prefix (~/.local)..."
  npm config set prefix "$HOME/.local"
  mkdir -p "$HOME/.local/bin"
  ensure_path_line

  if npm install -g @anthropic-ai/claude-code; then
    log_success "Claude Code installed successfully (user local)"
    return 0
  fi

  if have_cmd sudo; then
    log_info "Retrying with sudo (system global)..."
    if sudo npm install -g @anthropic-ai/claude-code; then
      log_success "Claude Code installed successfully (sudo global)"
      return 0
    fi
  fi

  log_error "Failed to install Claude Code"
  echo ""
  echo "Options:"
  echo "1) Install via nvm (no sudo):"
  echo "   curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
  echo "   source \"\$HOME/.nvm/nvm.sh\" && nvm install --lts && npm i -g @anthropic-ai/claude-code"
  echo "2) If allowed, run: sudo npm install -g @anthropic-ai/claude-code"
  exit 1
}

# ========= Download settings (commands) =========
download_settings() {
  log_info "Downloading settings from GitHub..."

  local TEMP_DIR EXTRACTED_DIR COMMANDS_PATH ARCHIVE_URL
  TEMP_DIR=$(mktemp -d)
  pushd "$TEMP_DIR" >/dev/null

  ARCHIVE_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/$BRANCH.tar.gz"
  log_info "Fetching from: $GITHUB_USER/$REPO_NAME"

  if curl -fL "$ARCHIVE_URL" -o archive.tar.gz 2>/dev/null; then
    if [ -s archive.tar.gz ]; then
      if tar -xzf archive.tar.gz 2>/dev/null; then
        EXTRACTED_DIR=$(ls -d */ 2>/dev/null | head -n1)
        log_info "Extracted directory: $EXTRACTED_DIR"

        COMMANDS_PATH="${EXTRACTED_DIR}${SETTINGS_PATH}/commands"
        if [ -d "$COMMANDS_PATH" ]; then
          mkdir -p "$CLAUDE_DIR"
          rm -rf "$COMMANDS_DIR"
          cp -r "$COMMANDS_PATH" "$COMMANDS_DIR"
          chmod -R 755 "$COMMANDS_DIR"
          local COMMAND_COUNT
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

  popd >/dev/null
  rm -rf "$TEMP_DIR"
}

# ========= Check authentication =========
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

# ========= Summary =========
show_summary() {
  echo ""
  echo "====================================="
  echo "   Installation Summary"
  echo "====================================="

  if have_cmd node; then
    echo -e "${GREEN}✓${NC} Node.js: $(node --version)"
  else
    echo -e "${RED}✗${NC} Node.js: Not installed"
  fi

  if have_cmd claude; then
    echo -e "${GREEN}✓${NC} Claude Code: Installed ($(claude --version 2>/dev/null || echo "version unknown"))"
  else
    echo -e "${YELLOW}○${NC} Claude Code: May need to restart terminal"
  fi

  if [ -d "$COMMANDS_DIR" ]; then
    local COMMAND_COUNT
    COMMAND_COUNT=$(find "$COMMANDS_DIR" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Custom Commands: $COMMAND_COUNT files"
    if [ "$COMMAND_COUNT" -gt 0 ]; then
      echo ""
      echo "Available commands:"
      ls -1 "$COMMANDS_DIR" 2>/dev/null | head -5 | sed 's/^/  - /'
      [ "$COMMAND_COUNT" -gt 5 ] && echo "  ... and $((COMMAND_COUNT - 5)) more"
    fi
  else
    echo -e "${YELLOW}○${NC} Custom Commands: None"
  fi

  if [ -n "$ANTHROPIC_API_KEY" ] || [ -f "$HOME/.claude/config.json" ] || [ -f "$HOME/.config/claude/config.json" ]; then
    echo -e "${GREEN}✓${NC} Authentication: Configured"
  else
    echo -e "${YELLOW}○${NC} Authentication: Not configured"
  fi

  echo "====================================="
}

# ========= Main =========
echo "====================================="
echo "   Claude Code Setup Tool"
echo "====================================="
echo ""

install_nodejs
install_claude_code
download_settings
check_auth
show_summary

echo ""
log_success "✨ Setup complete!"

# Final instructions (PATH note if user-local install used)
if ! have_cmd claude; then
  echo ""
  echo "If 'claude' is not found, open a new terminal or run:"
  echo '  source ~/.bashrc'
fi

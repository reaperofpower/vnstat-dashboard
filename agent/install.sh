#!/bin/bash

# vnStat Agent Installer Script
# Quick deployment script for new servers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${1}${2}${NC}"
}

print_status "$BLUE" "=== vnStat Network Monitoring Agent Installer ==="
echo ""

# Check if running as root for system-wide install
if [ "$EUID" -eq 0 ]; then
    INSTALL_DIR="/opt/vnstat-agent"
    print_status "$BLUE" "Installing system-wide to $INSTALL_DIR"
else
    INSTALL_DIR="$HOME/vnstat-agent"
    print_status "$BLUE" "Installing to user directory: $INSTALL_DIR"
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Download or copy the agent script
if [ -f "vnstat-agent.sh" ]; then
    print_status "$GREEN" "Copying vnstat-agent.sh..."
    cp vnstat-agent.sh "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/vnstat-agent.sh"
else
    print_status "$YELLOW" "vnstat-agent.sh not found in current directory"
    print_status "$YELLOW" "Please ensure vnstat-agent.sh is in the same directory as this installer"
    exit 1
fi

# Create symlink for easy access
if [ "$EUID" -eq 0 ]; then
    ln -sf "$INSTALL_DIR/vnstat-agent.sh" /usr/local/bin/vnstat-agent
    print_status "$GREEN" "Created symlink: /usr/local/bin/vnstat-agent"
else
    if [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        ln -sf "$INSTALL_DIR/vnstat-agent.sh" "$HOME/.local/bin/vnstat-agent"
        print_status "$GREEN" "Created symlink: $HOME/.local/bin/vnstat-agent"
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            print_status "$YELLOW" "Note: Add $HOME/.local/bin to your PATH for easier access"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            print_status "$GREEN" "Added to ~/.bashrc (restart shell or run: source ~/.bashrc)"
        fi
    fi
fi

cd "$INSTALL_DIR"

print_status "$GREEN" "Installation completed!"
echo ""
print_status "$BLUE" "Next steps:"
echo "  1. Run setup: $INSTALL_DIR/vnstat-agent.sh setup"
echo "  2. Start agent: $INSTALL_DIR/vnstat-agent.sh start"
echo ""

if [ "$EUID" -eq 0 ]; then
    echo "  Optional - Install as system service:"
    echo "    $INSTALL_DIR/vnstat-agent.sh install"
    echo "    systemctl start vnstat-agent"
    echo ""
fi

echo "  Or use the symlink (if available):"
echo "    vnstat-agent setup"
echo "    vnstat-agent start"
echo ""

# Offer to run setup immediately
echo -n "Would you like to run the setup now? (y/n): "
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    "$INSTALL_DIR/vnstat-agent.sh" setup
fi
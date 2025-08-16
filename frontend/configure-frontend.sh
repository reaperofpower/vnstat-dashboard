#!/bin/bash

# Frontend Configuration Script
# This script helps configure the frontend with the correct API key and backend URL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${1}${2}${NC}"
}

print_header() {
    echo ""
    print_status "$BLUE" "=============================================="
    print_status "$BLUE" "$1"
    print_status "$BLUE" "=============================================="
    echo ""
}

# Function to get API key from backend config
get_backend_api_key() {
    local backend_config="$SCRIPT_DIR/../backend/config.js"
    
    if [ -f "$backend_config" ]; then
        # Extract API key from config.js
        local api_key=$(grep -o "key: '[^']*'" "$backend_config" 2>/dev/null | cut -d"'" -f2)
        if [ -n "$api_key" ] && [ "$api_key" != "{{API_KEY}}" ]; then
            echo "$api_key"
            return 0
        fi
    fi
    
    return 1
}

# Function to create .env file
create_env_file() {
    local api_key="$1"
    local backend_url="$2"
    
    cat > "$ENV_FILE" << EOF
# VnStat Dashboard Frontend Configuration
# Generated on $(date)

# Backend API Configuration
REACT_APP_API_URL=$backend_url
REACT_APP_API_KEY=$api_key
REACT_APP_API_TIMEOUT=30000

# Build Information
REACT_APP_BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REACT_APP_VERSION=2.0.0
EOF

    print_status "$GREEN" "✅ Frontend configuration created: $ENV_FILE"
}

main() {
    local auto_mode=false
    
    # Check for auto mode flag
    if [[ "$1" == "--auto" ]]; then
        auto_mode=true
    fi
    
    if [ "$auto_mode" = false ]; then
        print_header "Frontend Configuration"
    fi
    
    # Try to get API key from backend config
    if api_key=$(get_backend_api_key); then
        if [ "$auto_mode" = false ]; then
            print_status "$GREEN" "✅ Found API key in backend configuration"
        fi
        backend_url="http://localhost:3000/api"
        
        if [ "$auto_mode" = true ]; then
            # Auto mode - just configure without prompting
            create_env_file "$api_key" "$backend_url" >/dev/null 2>&1
            return 0
        else
            print_status "$BLUE" "Configuration:"
            echo "  Backend URL: $backend_url"
            echo "  API Key: ${api_key:0:10}..."
            echo ""
            
            echo -n "Use this configuration? (y/n): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                create_env_file "$api_key" "$backend_url"
                
                print_status "$GREEN" "Frontend configured successfully!"
                echo ""
                print_status "$BLUE" "Next steps:"
                echo "  npm install"
                echo "  npm run build"
                return 0
            fi
        fi
    else
        if [ "$auto_mode" = true ]; then
            # Auto mode failure - exit silently
            return 1
        fi
        print_status "$YELLOW" "⚠️  Could not find API key in backend configuration"
        echo "Please ensure the backend is properly configured first."
        echo ""
    fi
    
    # Manual configuration
    print_status "$BLUE" "Manual Configuration"
    echo ""
    
    echo -n "Backend URL (default: http://localhost:3000/api): "
    read -r backend_url
    backend_url=${backend_url:-http://localhost:3000/api}
    
    echo -n "API Key: "
    read -r api_key
    
    if [ -z "$api_key" ]; then
        print_status "$RED" "API key is required!"
        exit 1
    fi
    
    create_env_file "$api_key" "$backend_url"
    
    print_status "$GREEN" "Frontend configured successfully!"
    echo ""
    print_status "$BLUE" "Next steps:"
    echo "  npm install"
    echo "  npm run build"
}

# Show usage if help requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Frontend Configuration Script"
    echo ""
    echo "Usage: $0 [--auto]"
    echo ""
    echo "Options:"
    echo "  --auto    Automatically configure without prompts (for scripts)"
    echo "  --help    Show this help"
    echo ""
    echo "This script configures the frontend with the correct API key and backend URL."
    echo "It will try to automatically detect the API key from the backend configuration."
    exit 0
fi

main "$@"
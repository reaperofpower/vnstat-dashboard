#!/bin/bash

# VnStat Dashboard Quick Installer
# Downloads only required files for selected component type
# Usage: bash <(curl -s https://raw.githubusercontent.com/yourusername/vnstat-dashboard/main/quick-install.sh) [--all|--dashboard|--agent|--frontend|--backend]

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

print_header() {
    echo ""
    print_status "$BLUE" "=============================================="
    print_status "$BLUE" "$1"
    print_status "$BLUE" "=============================================="
    echo ""
}

# GitHub repository configuration
GITHUB_USER="reaperofpower"
REPO_NAME="vnstat-dashboard"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"

# Installation directory
INSTALL_DIR="/opt/vnstat-dashboard"

# Default installation type
INSTALL_TYPE="interactive"
INSTALL_FRONTEND=false
INSTALL_BACKEND=false
INSTALL_AGENT=false
UPDATE_MODE=false
FORCE_INSTALL=false

# Function to show usage
show_usage() {
    echo "VnStat Dashboard Quick Installer"
    echo ""
    echo "Usage:"
    echo "  Interactive: bash <(curl -s ${BASE_URL}/quick-install.sh)"
    echo ""
    echo "  One-line installs:"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --all"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --dashboard"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --agent"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --frontend"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --backend"
    echo "  bash <(curl -s ${BASE_URL}/quick-install.sh) --uninstall"
    echo ""
    echo "Options:"
    echo "  --all         Install all components"
    echo "  --dashboard   Install frontend + backend"
    echo "  --agent       Install agent only"
    echo "  --frontend    Install frontend only"
    echo "  --backend     Install backend only"
    echo "  --uninstall   Uninstall VnStat Dashboard"
    echo "  --force       Force fresh installation (skip update mode)"
    echo "  --help        Show this help"
    echo ""
}

# Function to detect existing installation
detect_installation() {
    local existing_components=()
    
    # Check for existing components
    if [ -d "$INSTALL_DIR/frontend" ] && [ -f "$INSTALL_DIR/frontend/package.json" ]; then
        existing_components+=("frontend")
    fi
    
    if [ -d "$INSTALL_DIR/backend" ] && [ -f "$INSTALL_DIR/backend/package.json" ]; then
        existing_components+=("backend")
    fi
    
    if [ -d "$INSTALL_DIR/agent" ] && [ -f "$INSTALL_DIR/agent/vnstat-agent.sh" ]; then
        existing_components+=("agent")
    fi
    
    echo "${existing_components[@]}"
}

# Function to check if service is running
is_service_running() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name" 2>/dev/null
}

# Function to backup configuration files
backup_configs() {
    local component="$1"
    local backup_dir="$INSTALL_DIR/.backup-$(date +%Y%m%d-%H%M%S)"
    
    print_status "$BLUE" "Creating configuration backup..."
    mkdir -p "$backup_dir"
    
    case "$component" in
        backend)
            if [ -f "$INSTALL_DIR/backend/config.js" ]; then
                cp "$INSTALL_DIR/backend/config.js" "$backup_dir/backend-config.js"
                print_status "$GREEN" "✅ Backed up backend configuration"
            fi
            ;;
        agent)
            if [ -f "$INSTALL_DIR/agent/agent.conf" ]; then
                cp "$INSTALL_DIR/agent/agent.conf" "$backup_dir/agent.conf"
                print_status "$GREEN" "✅ Backed up agent configuration"
            fi
            ;;
        frontend)
            # Frontend typically doesn't have user-specific configs to preserve
            ;;
    esac
    
    echo "$backup_dir"
}

# Function to restore configuration files
restore_configs() {
    local component="$1"
    local backup_dir="$2"
    
    if [ ! -d "$backup_dir" ]; then
        return
    fi
    
    print_status "$BLUE" "Restoring configuration files..."
    
    case "$component" in
        backend)
            if [ -f "$backup_dir/backend-config.js" ]; then
                cp "$backup_dir/backend-config.js" "$INSTALL_DIR/backend/config.js"
                print_status "$GREEN" "✅ Restored backend configuration"
            fi
            ;;
        agent)
            if [ -f "$backup_dir/agent.conf" ]; then
                cp "$backup_dir/agent.conf" "$INSTALL_DIR/agent/agent.conf"
                print_status "$GREEN" "✅ Restored agent configuration"
            fi
            ;;
    esac
}

# Function to restart services after update
restart_services() {
    local components=("$@")
    
    print_status "$BLUE" "Restarting services after update..."
    
    for component in "${components[@]}"; do
        case "$component" in
            frontend)
                if is_service_running "vnstat-frontend"; then
                    print_status "$BLUE" "Restarting frontend service..."
                    sudo systemctl restart vnstat-frontend
                    print_status "$GREEN" "✅ Frontend service restarted"
                fi
                ;;
            backend)
                if is_service_running "vnstat-backend"; then
                    print_status "$BLUE" "Restarting backend service..."
                    sudo systemctl restart vnstat-backend
                    print_status "$GREEN" "✅ Backend service restarted"
                fi
                ;;
            agent)
                if is_service_running "vnstat-agent"; then
                    print_status "$BLUE" "Restarting agent service..."
                    sudo systemctl restart vnstat-agent
                    print_status "$GREEN" "✅ Agent service restarted"
                fi
                ;;
        esac
    done
}

# Function to update existing installation
update_installation() {
    local existing_components=("$@")
    
    print_header "Update Mode - Existing Installation Detected"
    
    echo "Found existing components: ${existing_components[*]}"
    echo ""
    print_status "$YELLOW" "⚠️  Update mode will:"
    echo "  • Download and replace code files"
    echo "  • Preserve existing configuration files"
    echo "  • Backup configurations before updating"
    echo "  • Restart services after update"
    echo ""
    
    echo -n "Continue with update? (y/n): "
    read -r confirm_update
    if [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        print_status "$YELLOW" "Update cancelled."
        exit 0
    fi
    
    # Set update flags based on existing components
    for component in "${existing_components[@]}"; do
        case "$component" in
            frontend) INSTALL_FRONTEND=true ;;
            backend) INSTALL_BACKEND=true ;;
            agent) INSTALL_AGENT=true ;;
        esac
    done
    
    # Set update mode
    UPDATE_MODE=true
}

# Function to parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --all)
            INSTALL_TYPE="all"
            INSTALL_FRONTEND=true
            INSTALL_BACKEND=true
            INSTALL_AGENT=true
            ;;
        --dashboard)
            INSTALL_TYPE="dashboard"
            INSTALL_FRONTEND=true
            INSTALL_BACKEND=true
            INSTALL_AGENT=false
            ;;
        --agent)
            INSTALL_TYPE="agent"
            INSTALL_FRONTEND=false
            INSTALL_BACKEND=false
            INSTALL_AGENT=true
            ;;
        --frontend)
            INSTALL_TYPE="frontend"
            INSTALL_FRONTEND=true
            INSTALL_BACKEND=false
            INSTALL_AGENT=false
            ;;
        --backend)
            INSTALL_TYPE="backend"
            INSTALL_FRONTEND=false
            INSTALL_BACKEND=true
            INSTALL_AGENT=false
            ;;
        --uninstall)
            download_and_run_uninstaller "$@"
            exit 0
            ;;
        --force)
            FORCE_INSTALL=true
            ;;
        --help|-h|help)
            show_usage
            exit 0
            ;;
        *)
            print_status "$RED" "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
        esac
        shift
    done
    
    # Set interactive mode if no arguments processed
    if [[ "$INSTALL_TYPE" == "" ]]; then
        INSTALL_TYPE="interactive"
    fi
}

# Function to select components interactively
select_components() {
    print_header "VnStat Dashboard Quick Installer"
    
    echo "Please select installation type:"
    echo ""
    echo "1) Complete installation (Frontend + Backend + Agent)"
    echo "2) Dashboard server (Frontend + Backend only)"
    echo "3) Monitoring agent (Agent only)"
    echo "4) Frontend only"
    echo "5) Backend only"
    echo ""
    
    while true; do
        echo -n "Enter your choice (1-5): "
        read -r choice
        
        case $choice in
            1)
                INSTALL_TYPE="all"
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=true
                print_status "$GREEN" "Selected: Complete installation"
                break
                ;;
            2)
                INSTALL_TYPE="dashboard"
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                print_status "$GREEN" "Selected: Dashboard server"
                break
                ;;
            3)
                INSTALL_TYPE="agent"
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=false
                INSTALL_AGENT=true
                print_status "$GREEN" "Selected: Monitoring agent"
                break
                ;;
            4)
                INSTALL_TYPE="frontend"
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=false
                INSTALL_AGENT=false
                print_status "$GREEN" "Selected: Frontend only"
                break
                ;;
            5)
                INSTALL_TYPE="backend"
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                print_status "$GREEN" "Selected: Backend only"
                break
                ;;
            *)
                print_status "$RED" "Invalid choice. Please enter 1-5."
                ;;
        esac
    done
}

# Function to download file
download_file() {
    local url="$1"
    local dest="$2"
    
    print_status "$BLUE" "Downloading: $(basename "$dest")"
    
    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$dest"
    else
        print_status "$RED" "Error: curl or wget is required for download"
        exit 1
    fi
}

# Function to download core files
download_core_files() {
    print_header "Downloading Core Files"
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$(whoami):$(whoami)" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download core files
    download_file "$BASE_URL/README.md" "README.md"
    download_file "$BASE_URL/LICENSE" "LICENSE"
    download_file "$BASE_URL/.gitignore" ".gitignore"
    download_file "$BASE_URL/service-manager.sh" "service-manager.sh"
    
    chmod +x service-manager.sh
}

# Function to download frontend files
download_frontend() {
    print_header "Downloading Frontend Files"
    
    mkdir -p frontend/src/{components,services,utils}
    mkdir -p frontend/public
    
    # Package files
    download_file "$BASE_URL/frontend/package.json" "frontend/package.json"
    download_file "$BASE_URL/frontend/package-lock.json" "frontend/package-lock.json"
    
    # Public files
    download_file "$BASE_URL/frontend/public/index.html" "frontend/public/index.html"
    
    # Source files
    download_file "$BASE_URL/frontend/src/index.js" "frontend/src/index.js"
    download_file "$BASE_URL/frontend/src/index.css" "frontend/src/index.css"
    download_file "$BASE_URL/frontend/src/App.js" "frontend/src/App.js"
    
    # Components
    download_file "$BASE_URL/frontend/src/components/CombinedChart.js" "frontend/src/components/CombinedChart.js"
    download_file "$BASE_URL/frontend/src/components/RealtimeChart.js" "frontend/src/components/RealtimeChart.js"
    download_file "$BASE_URL/frontend/src/components/ServerCard.js" "frontend/src/components/ServerCard.js"
    download_file "$BASE_URL/frontend/src/components/LoadingSpinner.js" "frontend/src/components/LoadingSpinner.js"
    download_file "$BASE_URL/frontend/src/components/ErrorDisplay.js" "frontend/src/components/ErrorDisplay.js"
    
    # Services
    download_file "$BASE_URL/frontend/src/services/apiService.js" "frontend/src/services/apiService.js"
    
    # Utils
    download_file "$BASE_URL/frontend/src/utils/browserCache.js" "frontend/src/utils/browserCache.js"
    download_file "$BASE_URL/frontend/src/utils/dataAggregation.js" "frontend/src/utils/dataAggregation.js"
    download_file "$BASE_URL/frontend/src/utils/formatUtils.js" "frontend/src/utils/formatUtils.js"
}

# Function to download backend files
download_backend() {
    print_header "Downloading Backend Files"
    
    local backup_dir=""
    
    # Handle update mode - backup configurations
    if [[ "$UPDATE_MODE" == "true" ]]; then
        backup_dir=$(backup_configs "backend")
        print_status "$BLUE" "Updating backend files while preserving configuration..."
    fi
    
    mkdir -p backend
    
    download_file "$BASE_URL/backend/package.json" "backend/package.json"
    download_file "$BASE_URL/backend/index.js" "backend/index.js"
    download_file "$BASE_URL/backend/index.template.js" "backend/index.template.js"
    download_file "$BASE_URL/backend/config.template.js" "backend/config.template.js"
    
    # Restore configurations in update mode
    if [[ "$UPDATE_MODE" == "true" ]] && [[ -n "$backup_dir" ]]; then
        restore_configs "backend" "$backup_dir"
    fi
}

# Function to download agent files
download_agent() {
    print_header "Downloading Agent Files"
    
    local backup_dir=""
    
    # Handle update mode - backup configurations
    if [[ "$UPDATE_MODE" == "true" ]]; then
        backup_dir=$(backup_configs "agent")
        print_status "$BLUE" "Updating agent files while preserving configuration..."
    fi
    
    mkdir -p agent
    
    download_file "$BASE_URL/agent/vnstat-agent.sh" "agent/vnstat-agent.sh"
    download_file "$BASE_URL/agent/install.sh" "agent/install.sh"
    download_file "$BASE_URL/agent/README.md" "agent/README.md"
    
    # Legacy agent files for compatibility
    download_file "$BASE_URL/agent/send_vnstat.sh" "agent/send_vnstat.sh"
    download_file "$BASE_URL/agent/send_vnstat_daemon.sh" "agent/send_vnstat_daemon.sh"
    
    chmod +x agent/*.sh
    
    # Restore configurations in update mode
    if [[ "$UPDATE_MODE" == "true" ]] && [[ -n "$backup_dir" ]]; then
        restore_configs "agent" "$backup_dir"
    fi
}

# Function to create local installer
create_local_installer() {
    print_header "Creating Local Installer"
    
    # Create a local installer script that uses the downloaded files
    cat > install-local.sh << 'EOF'
#!/bin/bash

# Local installer for downloaded vnStat Dashboard files
# This script runs the installation using the locally downloaded files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if we have the service manager
if [ ! -f "service-manager.sh" ]; then
    echo "Error: service-manager.sh not found. Please run the quick installer first."
    exit 1
fi

# Run installation based on what's available
if [ -d "frontend" ] && [ -d "backend" ] && [ -d "agent" ]; then
    echo "Running complete installation..."
    bash service-manager.sh install all
elif [ -d "frontend" ] && [ -d "backend" ]; then
    echo "Running dashboard installation..."
    bash service-manager.sh install frontend
    bash service-manager.sh install backend
elif [ -d "agent" ]; then
    echo "Running agent installation..."
    cd agent
    ./vnstat-agent.sh setup
else
    echo "Error: No valid components found"
    exit 1
fi
EOF
    
    chmod +x install-local.sh
}

# Function to run post-download setup
run_setup() {
    print_header "Running Setup"
    
    case "$INSTALL_TYPE" in
        "all")
            print_status "$BLUE" "Setting up complete installation..."
            sudo ./service-manager.sh install all
            ;;
        "dashboard")
            print_status "$BLUE" "Setting up dashboard server..."
            sudo ./service-manager.sh install frontend
            sudo ./service-manager.sh install backend
            ;;
        "agent")
            print_status "$BLUE" "Setting up monitoring agent..."
            cd agent
            ./vnstat-agent.sh setup
            ;;
        "frontend")
            print_status "$BLUE" "Setting up frontend..."
            sudo ./service-manager.sh install frontend
            ;;
        "backend")
            print_status "$BLUE" "Setting up backend..."
            sudo ./service-manager.sh install backend
            ;;
    esac
}

# Function to download and run uninstaller
download_and_run_uninstaller() {
    print_header "VnStat Dashboard Uninstaller"
    
    print_status "$BLUE" "Downloading uninstaller..."
    
    # Create temporary directory
    TEMP_DIR="/tmp/vnstat-uninstall-$$"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download uninstaller script
    if ! download_file "$BASE_URL/uninstall.sh" "uninstall.sh"; then
        print_status "$RED" "Failed to download uninstaller"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Make executable
    chmod +x uninstall.sh
    
    print_status "$GREEN" "Uninstaller downloaded successfully"
    echo ""
    print_status "$BLUE" "Starting uninstaller..."
    echo ""
    
    # Run uninstaller with all arguments passed to this script (except --uninstall)
    args=("$@")
    filtered_args=()
    for arg in "${args[@]}"; do
        if [[ "$arg" != "--uninstall" ]]; then
            filtered_args+=("$arg")
        fi
    done
    
    # Execute uninstaller
    ./uninstall.sh "${filtered_args[@]}"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
}

# Function to show completion message
show_completion() {
    print_header "Installation Complete!"
    
    print_status "$GREEN" "VnStat Dashboard has been installed successfully!"
    echo ""
    
    print_status "$BLUE" "Installation location: $INSTALL_DIR"
    print_status "$BLUE" "Installed components:"
    
    if [[ "$INSTALL_FRONTEND" == "true" ]]; then
        echo "  ✓ Frontend Dashboard"
    fi
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "  ✓ Backend API"
    fi
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        echo "  ✓ Monitoring Agent"
    fi
    echo ""
    
    print_status "$BLUE" "Next steps:"
    echo "  cd $INSTALL_DIR"
    
    if [[ "$INSTALL_FRONTEND" == "true" ]] && [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "  sudo ./service-manager.sh start all"
        echo "  Visit: http://localhost:8080"
    elif [[ "$INSTALL_AGENT" == "true" ]]; then
        echo "  cd agent && ./vnstat-agent.sh start"
    fi
    
    echo ""
    print_status "$GREEN" "Happy monitoring! 📊"
}

# Main installation flow
main() {
    # Check if running as root for certain operations
    if [[ "$1" != "--agent" ]] && [[ "$EUID" -eq 0 ]]; then
        print_status "$YELLOW" "Warning: Running as root. Consider using sudo only when needed."
    fi
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check for existing installation (unless --force is used)
    existing_components=($(detect_installation))
    if [[ ${#existing_components[@]} -gt 0 ]] && [[ "$INSTALL_TYPE" != "uninstall" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        update_installation "${existing_components[@]}"
    elif [[ "$INSTALL_TYPE" == "interactive" ]]; then
        # Interactive selection if no argument provided and no existing installation
        select_components
    fi
    
    print_status "$BLUE" "Installing: $INSTALL_TYPE"
    echo ""
    
    # Download files based on selection
    download_core_files
    
    if [[ "$INSTALL_FRONTEND" == "true" ]]; then
        download_frontend
    fi
    
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        download_backend
    fi
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        download_agent
    fi
    
    create_local_installer
    
    # Handle completion based on mode
    if [[ "$UPDATE_MODE" == "true" ]]; then
        # Update mode - restart services and show completion
        echo ""
        print_status "$GREEN" "✅ Update completed successfully!"
        echo ""
        
        # Collect components that were updated
        updated_components=()
        if [[ "$INSTALL_FRONTEND" == "true" ]]; then
            updated_components+=("frontend")
        fi
        if [[ "$INSTALL_BACKEND" == "true" ]]; then
            updated_components+=("backend")
        fi
        if [[ "$INSTALL_AGENT" == "true" ]]; then
            updated_components+=("agent")
        fi
        
        # Ask if user wants to restart services
        echo -n "Restart services now? (y/n): "
        read -r restart_now
        if [[ "$restart_now" =~ ^[Yy]$ ]]; then
            restart_services "${updated_components[@]}"
        else
            print_status "$BLUE" "Services not restarted. To restart manually:"
            echo "  cd $INSTALL_DIR"
            echo "  sudo ./service-manager.sh restart all"
        fi
        
        echo ""
        print_status "$GREEN" "Update Summary:"
        echo "  ✅ Code files updated"
        echo "  ✅ Configuration files preserved"
        echo "  📂 Backup created in: $INSTALL_DIR/.backup-*"
        
    else
        # Fresh installation mode - run setup
        echo ""
        echo -n "Run setup now? (y/n): "
        read -r run_setup_now
        if [[ "$run_setup_now" =~ ^[Yy]$ ]]; then
            run_setup
            show_completion
        else
            print_status "$BLUE" "Setup skipped. To run setup later:"
            echo "  cd $INSTALL_DIR"
            echo "  sudo ./install-local.sh"
        fi
    fi
}

# Run main function with all arguments
main "$@"
#!/bin/bash

# VnStat Dashboard Uninstaller
# Removes VnStat Dashboard components and services

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

# Function to show usage
show_usage() {
    echo "VnStat Dashboard Uninstaller"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --all               Remove all components"
    echo "  --frontend          Remove frontend only"
    echo "  --backend           Remove backend only"
    echo "  --agent             Remove agent only"
    echo "  --keep-data         Keep database and configuration files"
    echo "  --force             Skip confirmation prompts"
    echo ""
    echo "Examples:"
    echo "  $0                  # Interactive uninstall"
    echo "  $0 --all            # Remove everything"
    echo "  $0 --agent          # Remove agent only"
    echo "  $0 --all --keep-data # Remove services but keep data"
    echo ""
}

# Default settings
INTERACTIVE=true
REMOVE_FRONTEND=false
REMOVE_BACKEND=false
REMOVE_AGENT=false
KEEP_DATA=false
FORCE=false

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --all)
                REMOVE_FRONTEND=true
                REMOVE_BACKEND=true
                REMOVE_AGENT=true
                INTERACTIVE=false
                ;;
            --frontend)
                REMOVE_FRONTEND=true
                INTERACTIVE=false
                ;;
            --backend)
                REMOVE_BACKEND=true
                INTERACTIVE=false
                ;;
            --agent)
                REMOVE_AGENT=true
                INTERACTIVE=false
                ;;
            --keep-data)
                KEEP_DATA=true
                ;;
            --force)
                FORCE=true
                ;;
            *)
                print_status "$RED" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Function to select components interactively
select_components() {
    print_header "VnStat Dashboard Uninstaller"
    
    print_status "$YELLOW" "WARNING: This will remove VnStat Dashboard components!"
    echo ""
    echo "What would you like to uninstall?"
    echo ""
    echo "1) Everything (complete removal)"
    echo "2) Frontend only"
    echo "3) Backend only"
    echo "4) Agent only"
    echo "5) Cancel"
    echo ""
    
    while true; do
        echo -n "Enter your choice (1-5): "
        read -r choice
        
        case $choice in
            1)
                REMOVE_FRONTEND=true
                REMOVE_BACKEND=true
                REMOVE_AGENT=true
                print_status "$GREEN" "Selected: Complete removal"
                break
                ;;
            2)
                REMOVE_FRONTEND=true
                print_status "$GREEN" "Selected: Frontend only"
                break
                ;;
            3)
                REMOVE_BACKEND=true
                print_status "$GREEN" "Selected: Backend only"
                break
                ;;
            4)
                REMOVE_AGENT=true
                print_status "$GREEN" "Selected: Agent only"
                break
                ;;
            5)
                print_status "$BLUE" "Uninstall cancelled"
                exit 0
                ;;
            *)
                print_status "$RED" "Invalid choice. Please enter 1-5."
                ;;
        esac
    done
    
    echo ""
    echo -n "Keep database and configuration files? (y/n): "
    read -r keep_data_choice
    if [[ "$keep_data_choice" =~ ^[Yy]$ ]]; then
        KEEP_DATA=true
    fi
}

# Function to find installation directories
find_installation_dirs() {
    # Common installation locations
    INSTALL_DIRS=(
        "/opt/vnstat-dashboard"
        "$HOME/vnstat-dashboard"
        "./vnstat-dashboard"
        "$(pwd)"
    )
    
    FOUND_DIRS=()
    
    for dir in "${INSTALL_DIRS[@]}"; do
        if [ -d "$dir" ] && ([ -f "$dir/service-manager.sh" ] || [ -d "$dir/agent" ] || [ -d "$dir/frontend" ] || [ -d "$dir/backend" ]); then
            FOUND_DIRS+=("$dir")
        fi
    done
    
    if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
        print_status "$YELLOW" "No VnStat Dashboard installations found in common locations"
        echo ""
        echo -n "Enter custom installation directory: "
        read -r custom_dir
        if [ -d "$custom_dir" ]; then
            FOUND_DIRS+=("$custom_dir")
        else
            print_status "$RED" "Directory not found: $custom_dir"
            exit 1
        fi
    fi
}

# Function to stop services
stop_services() {
    local install_dir="$1"
    
    print_status "$BLUE" "Stopping services..."
    
    # Stop systemd services
    for service in vnstat-frontend vnstat-backend vnstat-agent; do
        if systemctl list-unit-files "$service.service" --no-pager --no-legend 2>/dev/null | grep -q "$service"; then
            print_status "$BLUE" "Stopping $service..."
            sudo systemctl stop "$service" 2>/dev/null || true
            sudo systemctl disable "$service" 2>/dev/null || true
        fi
    done
    
    # Stop agent script if running
    if [ -f "$install_dir/agent/vnstat-agent.sh" ] && [ -f "$install_dir/agent/vnstat-agent.pid" ]; then
        print_status "$BLUE" "Stopping vnstat-agent script..."
        cd "$install_dir/agent"
        ./vnstat-agent.sh stop 2>/dev/null || true
    fi
}

# Function to remove services
remove_services() {
    print_status "$BLUE" "Removing systemd services..."
    
    local services_to_remove=()
    
    if [[ "$REMOVE_FRONTEND" == "true" ]]; then
        services_to_remove+=("vnstat-frontend")
    fi
    
    if [[ "$REMOVE_BACKEND" == "true" ]]; then
        services_to_remove+=("vnstat-backend")
    fi
    
    if [[ "$REMOVE_AGENT" == "true" ]]; then
        services_to_remove+=("vnstat-agent")
    fi
    
    for service in "${services_to_remove[@]}"; do
        if [ -f "/etc/systemd/system/$service.service" ]; then
            print_status "$BLUE" "Removing $service service..."
            sudo rm -f "/etc/systemd/system/$service.service"
        fi
    done
    
    if [ ${#services_to_remove[@]} -gt 0 ]; then
        sudo systemctl daemon-reload
    fi
}

# Function to remove files
remove_files() {
    local install_dir="$1"
    
    print_status "$BLUE" "Removing files from: $install_dir"
    
    if [[ "$REMOVE_FRONTEND" == "true" ]] && [ -d "$install_dir/frontend" ]; then
        if [[ "$FORCE" == "true" ]] || confirm_removal "Remove frontend files?"; then
            rm -rf "$install_dir/frontend"
            print_status "$GREEN" "Frontend files removed"
        fi
    fi
    
    if [[ "$REMOVE_BACKEND" == "true" ]] && [ -d "$install_dir/backend" ]; then
        if [[ "$FORCE" == "true" ]] || confirm_removal "Remove backend files?"; then
            rm -rf "$install_dir/backend"
            print_status "$GREEN" "Backend files removed"
        fi
    fi
    
    if [[ "$REMOVE_AGENT" == "true" ]] && [ -d "$install_dir/agent" ]; then
        if [[ "$FORCE" == "true" ]] || confirm_removal "Remove agent files and logs?"; then
            rm -rf "$install_dir/agent"
            print_status "$GREEN" "Agent files removed"
        fi
    fi
    
    # Remove convenience scripts if removing everything
    if [[ "$REMOVE_FRONTEND" == "true" ]] && [[ "$REMOVE_BACKEND" == "true" ]] && [[ "$REMOVE_AGENT" == "true" ]]; then
        local scripts=("start.sh" "stop.sh" "status.sh" "update.sh" "install-local.sh" "service-manager.sh")
        for script in "${scripts[@]}"; do
            if [ -f "$install_dir/$script" ]; then
                rm -f "$install_dir/$script"
            fi
        done
        
        # Remove documentation
        rm -f "$install_dir"/{README.md,LICENSE,DEPLOYMENT.md,.gitignore}
        
        print_status "$GREEN" "Convenience scripts and documentation removed"
        
        # Remove entire directory if empty or if user confirms
        if [[ "$FORCE" == "true" ]] || confirm_removal "Remove entire installation directory ($install_dir)?"; then
            if [ "$(ls -A $install_dir 2>/dev/null)" ]; then
                rm -rf "$install_dir"
            else
                rmdir "$install_dir" 2>/dev/null || true
            fi
            print_status "$GREEN" "Installation directory removed"
        fi
    fi
}

# Function to clean database
clean_database() {
    if [[ "$REMOVE_BACKEND" == "true" ]] && [[ "$KEEP_DATA" == "false" ]]; then
        echo ""
        if [[ "$FORCE" == "true" ]] || confirm_removal "Remove database and user data?"; then
            print_status "$YELLOW" "To remove database manually, run:"
            echo "  mysql -u root -p"
            echo "  DROP DATABASE IF EXISTS vnstat_dashboard;"
            echo "  DROP USER IF EXISTS 'vnstat_user'@'localhost';"
            echo ""
            
            echo -n "Run database cleanup now? (requires MySQL root password) (y/n): "
            read -r cleanup_now
            if [[ "$cleanup_now" =~ ^[Yy]$ ]]; then
                mysql -u root -p << 'EOF'
DROP DATABASE IF EXISTS vnstat_dashboard;
DROP USER IF EXISTS 'vnstat_user'@'localhost';
FLUSH PRIVILEGES;
EOF
                print_status "$GREEN" "Database cleaned up"
            fi
        fi
    fi
}

# Function to confirm removal
confirm_removal() {
    local message="$1"
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo -n "$message (y/n): "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Function to show final summary
show_summary() {
    print_header "Uninstall Complete"
    
    print_status "$GREEN" "VnStat Dashboard components have been removed:"
    
    if [[ "$REMOVE_FRONTEND" == "true" ]]; then
        echo "  ✓ Frontend removed"
    fi
    
    if [[ "$REMOVE_BACKEND" == "true" ]]; then
        echo "  ✓ Backend removed"
    fi
    
    if [[ "$REMOVE_AGENT" == "true" ]]; then
        echo "  ✓ Agent removed"
    fi
    
    echo ""
    
    if [[ "$KEEP_DATA" == "true" ]]; then
        print_status "$BLUE" "Data and configuration files were preserved"
    fi
    
    print_status "$BLUE" "Manual cleanup that may be needed:"
    echo "- Remove vnstat package: sudo apt remove vnstat"
    echo "- Remove Node.js if no longer needed: sudo apt remove nodejs npm"
    echo "- Remove MySQL if no longer needed: sudo apt remove mysql-server"
    
    if [[ "$REMOVE_BACKEND" == "true" ]] && [[ "$KEEP_DATA" == "false" ]]; then
        echo "- Clean up database as shown above"
    fi
    
    echo ""
    print_status "$GREEN" "Uninstall completed successfully!"
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Interactive selection if no arguments
    if [[ "$INTERACTIVE" == "true" ]]; then
        select_components
    fi
    
    # Check if running as root for service removal
    if [[ "$REMOVE_FRONTEND" == "true" ]] || [[ "$REMOVE_BACKEND" == "true" ]] || [[ "$REMOVE_AGENT" == "true" ]]; then
        if [ "$EUID" -ne 0 ]; then
            print_status "$YELLOW" "Note: Root privileges required for complete service removal"
            echo "Run with sudo for full uninstall, or some services may remain"
            echo ""
        fi
    fi
    
    # Final confirmation
    if [[ "$FORCE" == "false" ]]; then
        print_status "$YELLOW" "This will remove the selected VnStat Dashboard components"
        echo -n "Continue with uninstall? (y/n): "
        read -r final_confirm
        if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
            print_status "$BLUE" "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Find installations
    find_installation_dirs
    
    # Process each installation directory
    for install_dir in "${FOUND_DIRS[@]}"; do
        print_header "Uninstalling from: $install_dir"
        
        stop_services "$install_dir"
        remove_services
        remove_files "$install_dir"
    done
    
    # Clean database
    clean_database
    
    show_summary
}

# Run main function
main "$@"
#!/bin/bash

# VnStat Dashboard Complete Installer
# Installs frontend, backend, agent, and service manager

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "$YELLOW" "Note: Some features require root privileges"
    print_status "$YELLOW" "For full installation, consider running with sudo"
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR"

print_header "VnStat Dashboard Installer"

print_status "$BLUE" "Installation directory: $INSTALL_DIR"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install system dependencies
install_system_deps() {
    print_header "Installing System Dependencies"
    
    # Update package list
    print_status "$BLUE" "Updating package list..."
    sudo apt update
    
    # Install basic dependencies
    local packages="curl wget git build-essential"
    print_status "$BLUE" "Installing basic packages: $packages"
    sudo apt install -y $packages
    
    # Install Node.js if not present
    if ! command_exists node || ! command_exists npm; then
        print_status "$BLUE" "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
    else
        local node_version=$(node -v)
        print_status "$GREEN" "Node.js already installed: $node_version"
    fi
    
    # Install MySQL if requested
    echo ""
    echo -n "Do you want to install MySQL server? (y/n): "
    read -r install_mysql
    if [[ "$install_mysql" =~ ^[Yy]$ ]]; then
        print_status "$BLUE" "Installing MySQL server..."
        sudo apt install -y mysql-server
        print_status "$YELLOW" "Please run 'sudo mysql_secure_installation' after installation"
    fi
    
    # Install vnstat for agent
    if ! command_exists vnstat; then
        print_status "$BLUE" "Installing vnstat..."
        sudo apt install -y vnstat
    else
        print_status "$GREEN" "vnstat already installed"
    fi
    
    # Install other monitoring dependencies
    local monitoring_packages="bc jq"
    print_status "$BLUE" "Installing monitoring packages: $monitoring_packages"
    sudo apt install -y $monitoring_packages
}

# Function to setup backend
setup_backend() {
    print_header "Setting Up Backend"
    
    cd "$INSTALL_DIR/backend"
    
    if [ ! -f "package.json" ]; then
        print_status "$RED" "Error: backend/package.json not found"
        return 1
    fi
    
    print_status "$BLUE" "Installing backend dependencies..."
    npm install
    
    print_status "$GREEN" "Backend setup completed"
    
    # Offer to configure database
    echo ""
    echo -n "Do you want to configure database settings now? (y/n): "
    read -r config_db
    if [[ "$config_db" =~ ^[Yy]$ ]]; then
        configure_database
    fi
}

# Function to configure database
configure_database() {
    print_status "$BLUE" "Database Configuration"
    echo ""
    
    echo -n "Enter database host (default: localhost): "
    read -r db_host
    db_host=${db_host:-localhost}
    
    echo -n "Enter database name (default: vnstat_dashboard): "
    read -r db_name
    db_name=${db_name:-vnstat_dashboard}
    
    echo -n "Enter database user (default: vnstat_user): "
    read -r db_user
    db_user=${db_user:-vnstat_user}
    
    echo -n "Enter database password: "
    read -rs db_password
    echo ""
    
    # Update backend configuration
    local config_file="$INSTALL_DIR/backend/config.json"
    cat > "$config_file" << EOF
{
  "database": {
    "host": "$db_host",
    "user": "$db_user",
    "password": "$db_password",
    "database": "$db_name"
  },
  "api": {
    "port": 3000,
    "key": "$(openssl rand -hex 32)"
  }
}
EOF
    
    print_status "$GREEN" "Database configuration saved to $config_file"
    print_status "$YELLOW" "Please update backend/index.js to use this configuration"
}

# Function to setup frontend
setup_frontend() {
    print_header "Setting Up Frontend"
    
    cd "$INSTALL_DIR/frontend"
    
    if [ ! -f "package.json" ]; then
        print_status "$RED" "Error: frontend/package.json not found"
        return 1
    fi
    
    print_status "$BLUE" "Installing frontend dependencies..."
    npm install
    
    print_status "$BLUE" "Building frontend for production..."
    npm run build
    
    print_status "$GREEN" "Frontend setup completed"
}

# Function to setup agent
setup_agent() {
    print_header "Setting Up Agent"
    
    cd "$INSTALL_DIR/agent"
    
    if [ ! -f "vnstat-agent.sh" ]; then
        print_status "$RED" "Error: agent/vnstat-agent.sh not found"
        return 1
    fi
    
    chmod +x *.sh
    
    print_status "$GREEN" "Agent scripts are now executable"
    
    echo ""
    echo -n "Do you want to configure the agent now? (y/n): "
    read -r config_agent
    if [[ "$config_agent" =~ ^[Yy]$ ]]; then
        ./vnstat-agent.sh setup
    fi
}

# Function to install services
install_services() {
    print_header "Installing System Services"
    
    if [ "$EUID" -ne 0 ]; then
        print_status "$YELLOW" "Skipping service installation (requires root)"
        print_status "$BLUE" "To install services later, run: sudo ./service-manager.sh install all"
        return 0
    fi
    
    cd "$INSTALL_DIR"
    
    echo -n "Install system services? (y/n): "
    read -r install_services
    if [[ "$install_services" =~ ^[Yy]$ ]]; then
        ./service-manager.sh install all
        print_status "$GREEN" "System services installed"
        
        echo ""
        echo -n "Start services now? (y/n): "
        read -r start_services
        if [[ "$start_services" =~ ^[Yy]$ ]]; then
            ./service-manager.sh start all
        fi
    fi
}

# Function to create convenience scripts
create_scripts() {
    print_header "Creating Convenience Scripts"
    
    # Create start script
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./service-manager.sh start all
EOF
    
    # Create stop script
    cat > "$INSTALL_DIR/stop.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./service-manager.sh stop all
EOF
    
    # Create status script
    cat > "$INSTALL_DIR/status.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./service-manager.sh status all
EOF
    
    # Create update script
    cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Updating VnStat Dashboard..."
git pull
./service-manager.sh rebuild all
echo "Update completed!"
EOF
    
    chmod +x "$INSTALL_DIR"/*.sh
    
    print_status "$GREEN" "Created convenience scripts:"
    print_status "$BLUE" "  ./start.sh    - Start all services"
    print_status "$BLUE" "  ./stop.sh     - Stop all services"
    print_status "$BLUE" "  ./status.sh   - Check service status"
    print_status "$BLUE" "  ./update.sh   - Update from git and rebuild"
}

# Function to show final instructions
show_final_instructions() {
    print_header "Installation Complete!"
    
    print_status "$GREEN" "VnStat Dashboard has been installed successfully!"
    echo ""
    
    print_status "$BLUE" "Next Steps:"
    echo ""
    
    if [ "$EUID" -eq 0 ] || [ -f "/etc/systemd/system/vnstat-backend.service" ]; then
        print_status "$BLUE" "1. Service Management:"
        echo "   ./service-manager.sh status all    - Check service status"
        echo "   ./service-manager.sh start all     - Start all services"
        echo "   ./service-manager.sh stop all      - Stop all services"
        echo "   ./service-manager.sh restart all   - Restart all services"
        echo ""
    fi
    
    print_status "$BLUE" "2. Access Points:"
    echo "   Frontend Dashboard: http://localhost:8080"
    echo "   Backend API: http://localhost:3000"
    echo ""
    
    print_status "$BLUE" "3. Agent Setup (on monitored servers):"
    echo "   cd agent/"
    echo "   ./vnstat-agent.sh setup"
    echo "   ./vnstat-agent.sh start"
    echo ""
    
    print_status "$BLUE" "4. Configuration Files:"
    echo "   Backend: backend/index.js (database settings)"
    echo "   Frontend: frontend/.env (API endpoint)"
    echo "   Agent: agent/agent.conf (auto-generated)"
    echo ""
    
    print_status "$BLUE" "5. Logs:"
    echo "   Service logs: journalctl -f -u vnstat-frontend"
    echo "   Agent logs: agent/vnstat-agent.log"
    echo ""
    
    print_status "$YELLOW" "Important:"
    echo "- Configure your database connection in backend/index.js"
    echo "- Update the API key in both backend and agent configurations"
    echo "- Ensure firewall allows connections on ports 3000 and 8080"
    echo ""
    
    print_status "$GREEN" "Happy monitoring! 📊"
}

# Function to select components to install
select_components() {
    print_header "Component Selection"
    
    echo "Please select which components to install:"
    echo ""
    echo "1) Complete installation (Frontend + Backend + Agent)"
    echo "2) Dashboard server (Frontend + Backend only)"
    echo "3) Monitoring server (Agent only)"
    echo "4) Frontend only"
    echo "5) Backend only"
    echo "6) Custom selection"
    echo ""
    
    while true; do
        echo -n "Enter your choice (1-6): "
        read -r choice
        
        case $choice in
            1)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=true
                INSTALL_SERVICES=true
                print_status "$GREEN" "Selected: Complete installation"
                break
                ;;
            2)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                INSTALL_SERVICES=true
                print_status "$GREEN" "Selected: Dashboard server (Frontend + Backend)"
                break
                ;;
            3)
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=false
                INSTALL_AGENT=true
                INSTALL_SERVICES=false
                print_status "$GREEN" "Selected: Monitoring server (Agent only)"
                break
                ;;
            4)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=false
                INSTALL_AGENT=false
                INSTALL_SERVICES=false
                print_status "$GREEN" "Selected: Frontend only"
                break
                ;;
            5)
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                INSTALL_SERVICES=false
                print_status "$GREEN" "Selected: Backend only"
                break
                ;;
            6)
                print_status "$BLUE" "Custom selection:"
                echo ""
                
                echo -n "Install Frontend? (y/n): "
                read -r frontend_choice
                INSTALL_FRONTEND=$([ "$frontend_choice" = "y" ] || [ "$frontend_choice" = "Y" ])
                
                echo -n "Install Backend? (y/n): "
                read -r backend_choice
                INSTALL_BACKEND=$([ "$backend_choice" = "y" ] || [ "$backend_choice" = "Y" ])
                
                echo -n "Install Agent? (y/n): "
                read -r agent_choice
                INSTALL_AGENT=$([ "$agent_choice" = "y" ] || [ "$agent_choice" = "Y" ])
                
                # Install services if any server component is selected
                if [[ "$INSTALL_FRONTEND" == "true" ]] || [[ "$INSTALL_BACKEND" == "true" ]]; then
                    INSTALL_SERVICES=true
                else
                    INSTALL_SERVICES=false
                fi
                
                print_status "$GREEN" "Custom selection configured"
                break
                ;;
            *)
                print_status "$RED" "Invalid choice. Please enter 1-6."
                ;;
        esac
    done
    
    echo ""
    print_status "$BLUE" "Installation plan:"
    echo "  Frontend: $([ "$INSTALL_FRONTEND" = "true" ] && echo "✓ Yes" || echo "✗ No")"
    echo "  Backend:  $([ "$INSTALL_BACKEND" = "true" ] && echo "✓ Yes" || echo "✗ No")"
    echo "  Agent:    $([ "$INSTALL_AGENT" = "true" ] && echo "✓ Yes" || echo "✗ No")"
    echo "  Services: $([ "$INSTALL_SERVICES" = "true" ] && echo "✓ Yes" || echo "✗ No")"
    echo ""
    
    echo -n "Continue with this selection? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "$YELLOW" "Installation cancelled by user"
        exit 0
    fi
}

# Function to install system dependencies based on component selection
install_system_deps_selective() {
    print_header "Installing System Dependencies"
    
    # Update package list
    print_status "$BLUE" "Updating package list..."
    sudo apt update
    
    # Install basic dependencies
    local packages="curl wget git"
    
    # Add dependencies based on selected components
    if [[ "$INSTALL_FRONTEND" == "true" ]] || [[ "$INSTALL_BACKEND" == "true" ]]; then
        packages="$packages build-essential"
        
        # Install Node.js if not present
        if ! command_exists node || ! command_exists npm; then
            print_status "$BLUE" "Installing Node.js and npm..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs
        else
            local node_version=$(node -v)
            print_status "$GREEN" "Node.js already installed: $node_version"
        fi
    fi
    
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        # Install MySQL if requested
        echo ""
        echo -n "Do you want to install MySQL server? (y/n): "
        read -r install_mysql
        if [[ "$install_mysql" =~ ^[Yy]$ ]]; then
            print_status "$BLUE" "Installing MySQL server..."
            sudo apt install -y mysql-server
            print_status "$YELLOW" "Please run 'sudo mysql_secure_installation' after installation"
        fi
    fi
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        # Install vnstat for agent
        if ! command_exists vnstat; then
            print_status "$BLUE" "Installing vnstat..."
            sudo apt install -y vnstat
        else
            print_status "$GREEN" "vnstat already installed"
        fi
        
        # Install other monitoring dependencies
        packages="$packages bc jq"
    fi
    
    if [[ -n "$packages" ]]; then
        print_status "$BLUE" "Installing packages: $packages"
        sudo apt install -y $packages
    fi
}

# Function to install services selectively
install_services_selective() {
    if [[ "$INSTALL_SERVICES" != "true" ]]; then
        print_status "$BLUE" "Skipping service installation (not selected)"
        return 0
    fi
    
    print_header "Installing System Services"
    
    if [ "$EUID" -ne 0 ]; then
        print_status "$YELLOW" "Skipping service installation (requires root)"
        print_status "$BLUE" "To install services later, run: sudo ./service-manager.sh install <component>"
        return 0
    fi
    
    cd "$INSTALL_DIR"
    
    echo -n "Install system services? (y/n): "
    read -r install_services
    if [[ "$install_services" =~ ^[Yy]$ ]]; then
        local services_to_install=""
        
        if [[ "$INSTALL_FRONTEND" == "true" ]]; then
            services_to_install="$services_to_install frontend"
        fi
        
        if [[ "$INSTALL_BACKEND" == "true" ]]; then
            services_to_install="$services_to_install backend"
        fi
        
        if [[ "$INSTALL_AGENT" == "true" ]]; then
            services_to_install="$services_to_install agent"
        fi
        
        for service in $services_to_install; do
            print_status "$BLUE" "Installing $service service..."
            ./service-manager.sh install "$service"
        done
        
        print_status "$GREEN" "System services installed"
        
        echo ""
        echo -n "Start services now? (y/n): "
        read -r start_services
        if [[ "$start_services" =~ ^[Yy]$ ]]; then
            for service in $services_to_install; do
                ./service-manager.sh start "$service"
            done
        fi
    fi
}

# Function to show final instructions based on components
show_final_instructions_selective() {
    print_header "Installation Complete!"
    
    print_status "$GREEN" "VnStat Dashboard components installed successfully!"
    echo ""
    
    print_status "$BLUE" "Installed Components:"
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
    
    print_status "$BLUE" "Next Steps:"
    echo ""
    
    if [[ "$INSTALL_SERVICES" == "true" ]] && ([ "$EUID" -eq 0 ] || [ -f "/etc/systemd/system/vnstat-backend.service" ]); then
        print_status "$BLUE" "1. Service Management:"
        echo "   ./service-manager.sh status all    - Check service status"
        
        if [[ "$INSTALL_FRONTEND" == "true" ]] && [[ "$INSTALL_BACKEND" == "true" ]]; then
            echo "   ./service-manager.sh start all     - Start all services"
        elif [[ "$INSTALL_FRONTEND" == "true" ]]; then
            echo "   ./service-manager.sh start frontend - Start frontend"
        elif [[ "$INSTALL_BACKEND" == "true" ]]; then
            echo "   ./service-manager.sh start backend  - Start backend"
        fi
        echo ""
    fi
    
    print_status "$BLUE" "2. Access Points:"
    if [[ "$INSTALL_FRONTEND" == "true" ]]; then
        echo "   Frontend Dashboard: http://localhost:8080"
    fi
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "   Backend API: http://localhost:3000"
    fi
    echo ""
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        print_status "$BLUE" "3. Agent Setup:"
        echo "   cd agent/"
        echo "   ./vnstat-agent.sh setup  - Configure agent"
        echo "   ./vnstat-agent.sh start  - Start monitoring"
        echo ""
    fi
    
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        print_status "$BLUE" "4. Configuration:"
        echo "   Backend: backend/index.js (database settings)"
        if [[ "$INSTALL_FRONTEND" == "true" ]]; then
            echo "   Frontend: frontend/.env (API endpoint)"
        fi
        echo ""
    fi
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        print_status "$BLUE" "5. Agent Deployment (on other servers):"
        echo "   scp -r agent/ root@other-server:/opt/vnstat-agent/"
        echo "   ssh root@other-server"
        echo "   cd /opt/vnstat-agent && ./vnstat-agent.sh setup"
        echo ""
    fi
    
    print_status "$YELLOW" "Important:"
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "- Configure your database connection in backend/index.js"
        echo "- Update the API key in backend configuration"
    fi
    if [[ "$INSTALL_AGENT" == "true" ]] && [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "- Ensure API key matches between backend and agent"
    fi
    if [[ "$INSTALL_FRONTEND" == "true" ]] || [[ "$INSTALL_BACKEND" == "true" ]]; then
        echo "- Ensure firewall allows connections on required ports"
    fi
    echo ""
    
    print_status "$GREEN" "Happy monitoring! 📊"
}

# Main installation flow
main() {
    select_components
    
    echo ""
    echo -n "Install system dependencies? (recommended for first install) (y/n): "
    read -r install_deps
    if [[ "$install_deps" =~ ^[Yy]$ ]]; then
        install_system_deps_selective
    fi
    
    # Install components based on selection
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        setup_backend
    fi
    
    if [[ "$INSTALL_FRONTEND" == "true" ]]; then
        setup_frontend
    fi
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        setup_agent
    fi
    
    install_services_selective
    create_scripts
    show_final_instructions_selective
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --all              Install all components (default interactive)"
    echo "  --dashboard        Install frontend + backend only"
    echo "  --agent            Install agent only"
    echo "  --frontend         Install frontend only"
    echo "  --backend          Install backend only"
    echo "  --no-deps          Skip system dependency installation"
    echo "  --no-services      Skip system service installation"
    echo ""
    echo "Examples:"
    echo "  $0                  # Interactive installation"
    echo "  $0 --all            # Install everything"
    echo "  $0 --agent          # Install agent only (for monitored servers)"
    echo "  $0 --dashboard      # Install frontend + backend (for dashboard server)"
    echo "  $0 --backend --no-deps  # Install backend only, skip dependencies"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    INTERACTIVE=true
    INSTALL_DEPS=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --all)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=true
                INSTALL_SERVICES=true
                INTERACTIVE=false
                ;;
            --dashboard)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                INSTALL_SERVICES=true
                INTERACTIVE=false
                ;;
            --agent)
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=false
                INSTALL_AGENT=true
                INSTALL_SERVICES=false
                INTERACTIVE=false
                ;;
            --frontend)
                INSTALL_FRONTEND=true
                INSTALL_BACKEND=false
                INSTALL_AGENT=false
                INSTALL_SERVICES=false
                INTERACTIVE=false
                ;;
            --backend)
                INSTALL_FRONTEND=false
                INSTALL_BACKEND=true
                INSTALL_AGENT=false
                INSTALL_SERVICES=false
                INTERACTIVE=false
                ;;
            --no-deps)
                INSTALL_DEPS=false
                ;;
            --no-services)
                INSTALL_SERVICES=false
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

# Check if this is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_arguments "$@"
    
    # Run interactive component selection if no components specified
    if [[ "$INTERACTIVE" == "true" ]]; then
        select_components
    else
        print_status "$BLUE" "Non-interactive installation selected:"
        echo "  Frontend: $([ "$INSTALL_FRONTEND" = "true" ] && echo "✓ Yes" || echo "✗ No")"
        echo "  Backend:  $([ "$INSTALL_BACKEND" = "true" ] && echo "✓ Yes" || echo "✗ No")"
        echo "  Agent:    $([ "$INSTALL_AGENT" = "true" ] && echo "✓ Yes" || echo "✗ No")"
        echo "  Services: $([ "$INSTALL_SERVICES" = "true" ] && echo "✓ Yes" || echo "✗ No")"
        echo ""
    fi
    
    # Install dependencies if requested
    if [[ "$INSTALL_DEPS" == "true" ]]; then
        if [[ "$INTERACTIVE" == "true" ]]; then
            echo -n "Install system dependencies? (recommended for first install) (y/n): "
            read -r install_deps
            if [[ "$install_deps" =~ ^[Yy]$ ]]; then
                install_system_deps_selective
            fi
        else
            install_system_deps_selective
        fi
    fi
    
    # Install components based on selection
    if [[ "$INSTALL_BACKEND" == "true" ]]; then
        setup_backend
    fi
    
    if [[ "$INSTALL_FRONTEND" == "true" ]]; then
        setup_frontend
    fi
    
    if [[ "$INSTALL_AGENT" == "true" ]]; then
        setup_agent
    fi
    
    install_services_selective
    create_scripts
    show_final_instructions_selective
fi
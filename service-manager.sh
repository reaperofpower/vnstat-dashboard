#!/bin/bash

# VnStat Dashboard Service Manager
# Updated for new project structure
# Usage: ./service-manager.sh {start|stop|restart|status|rebuild|install} {frontend|backend|agent|all}

ACTION=$1
SERVICE=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

if [ -z "$ACTION" ] || [ -z "$SERVICE" ]; then
    echo "Usage: $0 {start|stop|restart|status|rebuild|install|uninstall} {frontend|backend|agent|all}"
    echo ""
    echo "Actions:"
    echo "  start     - Start the specified service(s)"
    echo "  stop      - Stop the specified service(s)"
    echo "  restart   - Restart the specified service(s)"
    echo "  status    - Show status of the specified service(s)"
    echo "  rebuild   - Rebuild/reinstall the specified service(s)"
    echo "  install   - Install service files and dependencies"
    echo "  uninstall - Uninstall service files and remove data"
    echo ""
    echo "Services:"
    echo "  frontend  - React dashboard application"
    echo "  backend   - Node.js API server"
    echo "  agent     - Network monitoring agent"
    echo "  all       - All services"
    exit 1
fi

# Function to get PID of a service
get_service_pid() {
    local service_name="$1"
    if systemctl list-unit-files "$service_name.service" --no-pager --no-legend 2>/dev/null | grep -q "$service_name"; then
        systemctl show -p MainPID "$service_name" 2>/dev/null | cut -d= -f2
    else
        echo "0"
    fi
}

# Function to check if service exists
service_exists() {
    local service_name="$1"
    systemctl list-unit-files "$service_name.service" --no-pager --no-legend 2>/dev/null | grep -q "$service_name"
}

# Function to check if PID is actually running
is_pid_running() {
    local pid="$1"
    if [ -n "$pid" ] && [ "$pid" != "0" ]; then
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

# Function to generate secure API key
generate_api_key() {
    # Generate a 32-character random API key
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
    elif [ -f /dev/urandom ]; then
        < /dev/urandom tr -dc 'A-Za-z0-9' | head -c32
    else
        # Fallback method
        date +%s | sha256sum | base64 | head -c 32
    fi
}

# Function to prompt for database configuration
prompt_database_config() {
    print_status "$BLUE" "Database Configuration"
    echo ""
    echo "Please provide your MySQL/MariaDB database details:"
    echo ""
    
    # Database host
    echo -n "Database host (default: localhost): "
    read -r DB_HOST
    DB_HOST=${DB_HOST:-localhost}
    
    # Database port
    echo -n "Database port (default: 3306): "
    read -r DB_PORT
    DB_PORT=${DB_PORT:-3306}
    
    # Database name
    while [[ -z "$DB_NAME" ]]; do
        echo -n "Database name: "
        read -r DB_NAME
        if [[ -z "$DB_NAME" ]]; then
            print_status "$RED" "Database name is required!"
        fi
    done
    
    # Database user
    while [[ -z "$DB_USER" ]]; do
        echo -n "Database username: "
        read -r DB_USER
        if [[ -z "$DB_USER" ]]; then
            print_status "$RED" "Database username is required!"
        fi
    done
    
    # Database password
    while [[ -z "$DB_PASSWORD" ]]; do
        echo -n "Database password: "
        read -s DB_PASSWORD
        echo ""
        if [[ -z "$DB_PASSWORD" ]]; then
            print_status "$RED" "Database password is required!"
        fi
    done
    
    echo ""
    print_status "$GREEN" "Database configuration collected successfully!"
}

# Function to test database connection
test_database_connection() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    local database="$5"
    
    print_status "$BLUE" "Testing database connection..."
    
    if command -v mysql &> /dev/null; then
        if mysql -h "$host" -P "$port" -u "$user" -p"$password" -e "USE $database;" 2>/dev/null; then
            print_status "$GREEN" "✅ Database connection successful!"
            return 0
        else
            print_status "$YELLOW" "⚠️  Database connection test failed"
            echo "This might be normal if the database doesn't exist yet."
            echo ""
            echo -n "Continue anyway? (y/n): "
            read -r continue_anyway
            if [[ "$continue_anyway" =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        fi
    else
        print_status "$YELLOW" "⚠️  MySQL client not found - skipping connection test"
        return 0
    fi
}

# Function to create backend configuration file
create_backend_config() {
    local install_dir="$1"
    local api_key="$2"
    local db_host="$3"
    local db_port="$4"
    local db_user="$5"
    local db_password="$6"
    local db_name="$7"
    
    print_status "$BLUE" "Creating backend configuration..."
    
    # Create config.js from template
    cat > "$install_dir/backend/config.js" << EOF
// VnStat Dashboard Backend Configuration
// Generated by installer on $(date)

module.exports = {
  // API Configuration
  api: {
    port: 3000,
    host: '0.0.0.0',
    key: '$api_key'
  },
  
  // Database Configuration
  database: {
    host: '$db_host',
    user: '$db_user',
    password: '$db_password',
    database: '$db_name',
    port: $db_port
  },
  
  // CORS Configuration
  cors: {
    enabled: true,
    origin: '*' // Configure as needed for production
  }
};
EOF
    
    print_status "$GREEN" "✅ Backend configuration created: $install_dir/backend/config.js"
}

# Function to setup backend files
setup_backend_files() {
    local install_dir="$1"
    
    print_status "$BLUE" "Setting up backend files..."
    
    # Copy template to main file if it doesn't exist or user confirms
    if [ ! -f "$install_dir/backend/index.js" ] || [ -f "$install_dir/backend/index.template.js" ]; then
        if [ -f "$install_dir/backend/index.template.js" ]; then
            cp "$install_dir/backend/index.template.js" "$install_dir/backend/index.js"
            print_status "$GREEN" "✅ Backend index.js updated from template"
        fi
    fi
    
    # Set proper permissions
    chmod 644 "$install_dir/backend/config.js" 2>/dev/null || true
    chmod 644 "$install_dir/backend/index.js" 2>/dev/null || true
}

# Function to check if Node.js is installed
check_nodejs() {
    if ! command -v node &> /dev/null; then
        print_status "$RED" "Error: Node.js is not installed"
        echo "Please install Node.js 16+ before continuing"
        return 1
    fi
    
    local node_version=$(node -v | sed 's/v//')
    local major_version=$(echo $node_version | cut -d. -f1)
    if [ "$major_version" -lt 16 ]; then
        print_status "$YELLOW" "Warning: Node.js version $node_version detected. Version 16+ is recommended"
    fi
    
    return 0
}

# Function to install service files
install_services() {
    local service="$1"
    
    case $service in
        frontend)
            install_frontend_service
            ;;
        backend)
            install_backend_service
            ;;
        agent)
            install_agent_service
            ;;
        all)
            install_frontend_service
            install_backend_service
            install_agent_service
            ;;
    esac
}

# Install frontend service
install_frontend_service() {
    print_status "$BLUE" "Installing frontend service..."
    
    if ! check_nodejs; then
        return 1
    fi
    
    # Configure frontend with API key from backend
    cd "$SCRIPT_DIR/frontend"
    if [ -f "./configure-frontend.sh" ]; then
        print_status "$BLUE" "Configuring frontend with backend API key..."
        if ! ./configure-frontend.sh --auto 2>/dev/null; then
            print_status "$YELLOW" "⚠️  Could not auto-configure frontend. Manual configuration may be needed."
        fi
    fi
    
    # Install dependencies
    if [ ! -d "node_modules" ]; then
        print_status "$BLUE" "Installing frontend dependencies..."
        npm install
    fi
    
    # Build production version
    print_status "$BLUE" "Building frontend..."
    npm run build
    
    # Create systemd service file
    sudo tee /etc/systemd/system/vnstat-frontend.service > /dev/null << EOF
[Unit]
Description=VnStat Dashboard Frontend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$SCRIPT_DIR/frontend
ExecStart=/usr/bin/npx serve -s build -l 8080
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable vnstat-frontend
    print_status "$GREEN" "Frontend service installed successfully"
}

# Install backend service
install_backend_service() {
    print_status "$BLUE" "Installing backend service..."
    
    if ! check_nodejs; then
        return 1
    fi
    
    # Prompt for database configuration if config doesn't exist
    if [ ! -f "$SCRIPT_DIR/backend/config.js" ]; then
        print_status "$BLUE" "Backend configuration not found. Setting up..."
        echo ""
        
        # Generate API key
        API_KEY=$(generate_api_key)
        print_status "$GREEN" "🔐 Generated API key: $API_KEY"
        echo ""
        
        # Get database configuration
        prompt_database_config
        
        # Test database connection
        if ! test_database_connection "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"; then
            print_status "$RED" "Database configuration failed. Aborting backend installation."
            return 1
        fi
        
        # Create configuration file
        create_backend_config "$SCRIPT_DIR" "$API_KEY" "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"
        
        echo ""
        print_status "$GREEN" "📝 Configuration Summary:"
        echo "   API Key: $API_KEY"
        echo "   Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
        echo ""
        print_status "$YELLOW" "⚠️  IMPORTANT: Save these credentials securely!"
        echo "   The API key is required for agent configuration."
        echo ""
    else
        print_status "$GREEN" "✅ Backend configuration already exists"
    fi
    
    # Setup backend files
    setup_backend_files "$SCRIPT_DIR"
    
    # Install dependencies
    cd "$SCRIPT_DIR/backend"
    if [ ! -d "node_modules" ]; then
        print_status "$BLUE" "Installing backend dependencies..."
        npm install
    fi
    
    # Create systemd service file
    sudo tee /etc/systemd/system/vnstat-backend.service > /dev/null << EOF
[Unit]
Description=VnStat Dashboard Backend API
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$SCRIPT_DIR/backend
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable vnstat-backend
    print_status "$GREEN" "Backend service installed successfully"
}

# Install agent service
install_agent_service() {
    print_status "$BLUE" "Installing agent service..."
    
    cd "$SCRIPT_DIR/agent"
    
    # Make agent executable
    chmod +x vnstat-agent.sh
    
    # Run agent installation
    if [ -f "vnstat-agent.sh" ]; then
        ./vnstat-agent.sh install
        print_status "$GREEN" "Agent service installed successfully"
    else
        print_status "$RED" "Error: vnstat-agent.sh not found"
        return 1
    fi
}

# Uninstall frontend service
uninstall_frontend_service() {
    print_status "$BLUE" "Uninstalling frontend service..."
    
    # Stop and disable service
    if service_exists "vnstat-frontend"; then
        sudo systemctl stop vnstat-frontend 2>/dev/null
        sudo systemctl disable vnstat-frontend 2>/dev/null
        sudo rm -f /etc/systemd/system/vnstat-frontend.service
        sudo systemctl daemon-reload
    fi
    
    # Remove frontend files
    if [ -d "$SCRIPT_DIR/frontend" ]; then
        echo -n "Remove frontend files? (y/n): "
        read -r remove_files
        if [[ "$remove_files" =~ ^[Yy]$ ]]; then
            rm -rf "$SCRIPT_DIR/frontend"
            print_status "$GREEN" "Frontend files removed"
        fi
    fi
    
    print_status "$GREEN" "Frontend service uninstalled"
}

# Uninstall backend service
uninstall_backend_service() {
    print_status "$BLUE" "Uninstalling backend service..."
    
    # Stop and disable service
    if service_exists "vnstat-backend"; then
        sudo systemctl stop vnstat-backend 2>/dev/null
        sudo systemctl disable vnstat-backend 2>/dev/null
        sudo rm -f /etc/systemd/system/vnstat-backend.service
        sudo systemctl daemon-reload
    fi
    
    # Remove backend files
    if [ -d "$SCRIPT_DIR/backend" ]; then
        echo -n "Remove backend files? (y/n): "
        read -r remove_files
        if [[ "$remove_files" =~ ^[Yy]$ ]]; then
            rm -rf "$SCRIPT_DIR/backend"
            print_status "$GREEN" "Backend files removed"
        fi
    fi
    
    # Ask about database
    echo ""
    echo -n "Remove database and data? (y/n): "
    read -r remove_db
    if [[ "$remove_db" =~ ^[Yy]$ ]]; then
        print_status "$YELLOW" "Manual database cleanup required:"
        echo "  mysql -u root -p"
        echo "  DROP DATABASE vnstat_dashboard;"
        echo "  DROP USER 'vnstat_user'@'localhost';"
    fi
    
    print_status "$GREEN" "Backend service uninstalled"
}

# Uninstall agent service
uninstall_agent_service() {
    print_status "$BLUE" "Uninstalling agent service..."
    
    # Stop and disable service
    if service_exists "vnstat-agent"; then
        sudo systemctl stop vnstat-agent 2>/dev/null
        sudo systemctl disable vnstat-agent 2>/dev/null
        sudo rm -f /etc/systemd/system/vnstat-agent.service
        sudo systemctl daemon-reload
    fi
    
    # Remove agent files
    if [ -d "$SCRIPT_DIR/agent" ]; then
        # Stop agent if running via script
        if [ -f "$SCRIPT_DIR/agent/vnstat-agent.pid" ]; then
            cd "$SCRIPT_DIR/agent"
            ./vnstat-agent.sh stop 2>/dev/null
        fi
        
        echo -n "Remove agent files and logs? (y/n): "
        read -r remove_files
        if [[ "$remove_files" =~ ^[Yy]$ ]]; then
            rm -rf "$SCRIPT_DIR/agent"
            print_status "$GREEN" "Agent files removed"
        fi
    fi
    
    print_status "$GREEN" "Agent service uninstalled"
}

# Function to uninstall services
uninstall_services() {
    local service="$1"
    
    if [ "$EUID" -ne 0 ]; then
        print_status "$RED" "Please run as root to uninstall services"
        exit 1
    fi
    
    print_status "$YELLOW" "WARNING: This will remove services and may delete data!"
    echo -n "Are you sure you want to continue? (y/n): "
    read -r confirm_uninstall
    if [[ ! "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        print_status "$BLUE" "Uninstall cancelled"
        return 0
    fi
    
    case $service in
        frontend)
            uninstall_frontend_service
            ;;
        backend)
            uninstall_backend_service
            ;;
        agent)
            uninstall_agent_service
            ;;
        all)
            uninstall_frontend_service
            uninstall_backend_service
            uninstall_agent_service
            
            # Remove convenience scripts
            echo ""
            echo -n "Remove convenience scripts (start.sh, stop.sh, etc.)? (y/n): "
            read -r remove_scripts
            if [[ "$remove_scripts" =~ ^[Yy]$ ]]; then
                rm -f "$SCRIPT_DIR"/{start.sh,stop.sh,status.sh,update.sh,install-local.sh}
                print_status "$GREEN" "Convenience scripts removed"
            fi
            
            # Remove main directory
            echo ""
            echo -n "Remove entire installation directory ($SCRIPT_DIR)? (y/n): "
            read -r remove_all
            if [[ "$remove_all" =~ ^[Yy]$ ]]; then
                cd /
                rm -rf "$SCRIPT_DIR"
                print_status "$GREEN" "Installation directory removed"
                print_status "$BLUE" "VnStat Dashboard completely uninstalled"
                return 0
            fi
            ;;
    esac
}

# Map service names
case $SERVICE in
    frontend)
        SERVICES="vnstat-frontend"
        ;;
    backend)
        SERVICES="vnstat-backend"
        ;;
    agent)
        SERVICES="vnstat-agent"
        ;;
    all)
        SERVICES="vnstat-frontend vnstat-backend vnstat-agent"
        ;;
    *)
        print_status "$RED" "Invalid service: $SERVICE"
        echo "Valid options: frontend, backend, agent, all"
        exit 1
        ;;
esac

case $ACTION in
    install)
        if [ "$EUID" -ne 0 ]; then
            print_status "$RED" "Please run as root to install services"
            exit 1
        fi
        install_services "$SERVICE"
        ;;
    start)
        for svc in $SERVICES; do
            if ! service_exists "$svc"; then
                print_status "$RED" "Error: Service $svc not found. Run: $0 install $SERVICE"
                continue
            fi
            
            current_pid=$(get_service_pid "$svc")
            if is_pid_running "$current_pid"; then
                print_status "$YELLOW" "Service $svc is already running (PID: $current_pid)"
                continue
            fi
            
            print_status "$BLUE" "Starting $svc..."
            if sudo systemctl start $svc; then
                sudo systemctl enable $svc >/dev/null 2>&1
                sleep 2
                new_pid=$(get_service_pid "$svc")
                if is_pid_running "$new_pid"; then
                    print_status "$GREEN" "Successfully started $svc (PID: $new_pid)"
                else
                    print_status "$RED" "Error: Failed to start $svc - no valid PID after start"
                fi
            else
                print_status "$RED" "Error: Failed to start service $svc"
            fi
        done
        ;;
    stop)
        for svc in $SERVICES; do
            if ! service_exists "$svc"; then
                print_status "$RED" "Error: Service $svc not found"
                continue
            fi
            
            current_pid=$(get_service_pid "$svc")
            if ! is_pid_running "$current_pid"; then
                print_status "$YELLOW" "Service $svc is not running"
                continue
            fi
            
            print_status "$BLUE" "Stopping $svc (current PID: $current_pid)..."
            if sudo systemctl stop $svc; then
                sleep 2
                check_pid=$(get_service_pid "$svc")
                if ! is_pid_running "$check_pid"; then
                    print_status "$GREEN" "Successfully stopped $svc (PID $current_pid is gone)"
                else
                    print_status "$YELLOW" "Warning: $svc may still be running (PID: $check_pid)"
                fi
            else
                print_status "$RED" "Error: Failed to stop service $svc"
            fi
        done
        ;;
    restart)
        for svc in $SERVICES; do
            if ! service_exists "$svc"; then
                print_status "$RED" "Error: Service $svc not found. Run: $0 install $SERVICE"
                continue
            fi
            
            current_pid=$(get_service_pid "$svc")
            if is_pid_running "$current_pid"; then
                print_status "$BLUE" "Restarting $svc (current PID: $current_pid)..."
            else
                print_status "$BLUE" "Restarting $svc (not currently running)..."
            fi
            
            if sudo systemctl restart $svc; then
                sleep 2
                new_pid=$(get_service_pid "$svc")
                if is_pid_running "$new_pid"; then
                    if [ "$current_pid" != "$new_pid" ]; then
                        print_status "$GREEN" "Successfully restarted $svc (PID changed: $current_pid -> $new_pid)"
                    else
                        print_status "$GREEN" "Successfully restarted $svc (PID: $new_pid)"
                    fi
                else
                    print_status "$RED" "Error: Service $svc failed to start after restart"
                fi
            else
                print_status "$RED" "Error: Failed to restart service $svc"
            fi
        done
        ;;
    status)
        for svc in $SERVICES; do
            if ! service_exists "$svc"; then
                print_status "$RED" "Service $svc: Not installed"
                continue
            fi
            
            current_pid=$(get_service_pid "$svc")
            if is_pid_running "$current_pid"; then
                print_status "$GREEN" "Service $svc: Running (PID: $current_pid)"
            else
                print_status "$RED" "Service $svc: Not running"
            fi
            
            systemctl status $svc --no-pager -l
            echo ""
        done
        ;;
    rebuild)
        case $SERVICE in
            frontend)
                print_status "$BLUE" "Rebuilding frontend..."
                cd "$SCRIPT_DIR/frontend"
                npm run build
                print_status "$GREEN" "Frontend rebuilt successfully"
                if service_exists "vnstat-frontend"; then
                    sudo systemctl restart vnstat-frontend
                    print_status "$GREEN" "Frontend service restarted"
                fi
                ;;
            backend)
                print_status "$BLUE" "Rebuilding backend..."
                cd "$SCRIPT_DIR/backend"
                npm install
                print_status "$GREEN" "Backend dependencies updated"
                if service_exists "vnstat-backend"; then
                    sudo systemctl restart vnstat-backend
                    print_status "$GREEN" "Backend service restarted"
                fi
                ;;
            agent)
                print_status "$BLUE" "Rebuilding agent..."
                cd "$SCRIPT_DIR/agent"
                chmod +x *.sh
                print_status "$GREEN" "Agent scripts updated"
                if service_exists "vnstat-agent"; then
                    sudo systemctl restart vnstat-agent
                    print_status "$GREEN" "Agent service restarted"
                fi
                ;;
            all)
                print_status "$BLUE" "Rebuilding all services..."
                cd "$SCRIPT_DIR/frontend"
                npm run build
                cd "$SCRIPT_DIR/backend"
                npm install
                cd "$SCRIPT_DIR/agent"
                chmod +x *.sh
                print_status "$GREEN" "All services rebuilt successfully"
                
                for svc in $SERVICES; do
                    if service_exists "$svc"; then
                        sudo systemctl restart $svc
                    fi
                done
                print_status "$GREEN" "All services restarted"
                ;;
        esac
        ;;
    uninstall)
        uninstall_services "$SERVICE"
        ;;
    *)
        print_status "$RED" "Invalid action: $ACTION"
        echo "Valid actions: start, stop, restart, status, rebuild, install, uninstall"
        exit 1
        ;;
esac
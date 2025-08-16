#!/bin/bash

# vnStat Network Monitoring Agent
# Collects and sends network statistics to dashboard backend

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/agent.conf"
PID_FILE="$SCRIPT_DIR/vnstat-agent.pid"
LOG_FILE="$SCRIPT_DIR/vnstat-agent.log"

# Default configuration
DEFAULT_BACKEND_URL="http://92.112.126.209:3000/api/data"
DEFAULT_API_KEY=""
DEFAULT_TIMEZONE="auto"
DEFAULT_INTERVAL="5"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {start|stop|restart|status|setup|install}"
    echo ""
    echo "Commands:"
    echo "  setup     - Interactive setup (first time configuration)"
    echo "  start     - Start the agent in background"
    echo "  stop      - Stop the running agent"
    echo "  restart   - Restart the agent"
    echo "  status    - Show agent status"
    echo "  install   - Install as system service"
    echo ""
}

# Function to check if agent is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to check dependencies
check_dependency() {
    local cmd="$1"
    local package="$2"
    
    if ! command -v "$cmd" &> /dev/null; then
        print_status "$RED" "Error: $cmd is not installed."
        echo "To install it, run: sudo apt update && sudo apt install -y $package"
        echo "Would you like to install it now? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y "$package"
            if ! command -v "$cmd" &> /dev/null; then
                print_status "$RED" "Failed to install $cmd. Exiting."
                exit 1
            fi
        else
            print_status "$RED" "Cannot continue without $cmd. Exiting."
            exit 1
        fi
    fi
}

# Function to detect hostname
detect_hostname() {
    local hostname=""
    
    # Try different methods to get hostname
    if command -v hostname &> /dev/null; then
        hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null)
    fi
    
    if [ -z "$hostname" ]; then
        hostname=$(cat /etc/hostname 2>/dev/null)
    fi
    
    if [ -z "$hostname" ]; then
        hostname=$(uname -n 2>/dev/null)
    fi
    
    if [ -z "$hostname" ]; then
        hostname="unknown-$(date +%s)"
    fi
    
    echo "$hostname"
}

# Function to detect timezone
detect_timezone() {
    print_status "$BLUE" "Detecting timezone automatically..."
    local api_response=$(curl -s --connect-timeout 10 "http://ip-api.com/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$api_response" ]; then
        local detected_tz=$(echo "$api_response" | jq -r '.timezone // empty' 2>/dev/null)
        if [ -n "$detected_tz" ] && [ "$detected_tz" != "null" ]; then
            print_status "$GREEN" "Detected timezone: $detected_tz"
            echo "$detected_tz"
        else
            print_status "$YELLOW" "Failed to parse timezone from API response, using UTC"
            echo "UTC"
        fi
    else
        print_status "$YELLOW" "Failed to detect timezone automatically, using UTC"
        echo "UTC"
    fi
}

# Function to create configuration file
create_config() {
    local server_name="$1"
    local backend_url="$2"
    local api_key="$3"
    local timezone="$4"
    local interval="$5"
    
    cat > "$CONFIG_FILE" << EOF
# vnStat Agent Configuration File
# Generated on $(date)

SERVER_NAME="$server_name"
BACKEND_URL="$backend_url"
API_KEY="$api_key"
TIMEZONE="$timezone"
INTERVAL="$interval"
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_status "$GREEN" "Configuration saved to $CONFIG_FILE"
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Function for interactive setup
setup() {
    print_status "$BLUE" "=== vnStat Agent Setup ==="
    echo ""
    
    # Check dependencies first
    print_status "$BLUE" "Checking dependencies..."
    check_dependency "bc" "bc"
    check_dependency "jq" "jq"
    check_dependency "vnstat" "vnstat"
    check_dependency "curl" "curl"
    
    print_status "$GREEN" "All dependencies are installed!"
    echo ""
    
    # Get server name
    local detected_hostname=$(detect_hostname)
    echo "Detected hostname: $detected_hostname"
    echo -n "Enter server name (press Enter to use detected hostname): "
    read -r server_name
    if [ -z "$server_name" ]; then
        server_name="$detected_hostname"
    fi
    
    # Get backend URL
    echo -n "Enter backend URL (press Enter for default: $DEFAULT_BACKEND_URL): "
    read -r backend_url
    if [ -z "$backend_url" ]; then
        backend_url="$DEFAULT_BACKEND_URL"
    fi
    
    # Get API key
    echo ""
    print_status "$YELLOW" "🔐 API Key Configuration"
    echo "The API key is generated during backend installation."
    echo "Check your backend installation output or config.js file."
    echo ""
    while [ -z "$api_key" ]; do
        echo -n "Enter API key (required): "
        read -r api_key
        if [ -z "$api_key" ]; then
            print_status "$RED" "API key is required! Cannot continue without it."
        fi
    done
    
    # Get timezone
    echo "Timezone options:"
    echo "  auto - Automatic detection"
    echo "  UTC - Coordinated Universal Time"
    echo "  America/New_York - Eastern Time"
    echo "  Europe/London - London Time"
    echo "  Or specify any valid timezone"
    echo -n "Enter timezone (press Enter for auto): "
    read -r timezone
    if [ -z "$timezone" ]; then
        timezone="auto"
    fi
    
    if [ "$timezone" = "auto" ]; then
        timezone=$(detect_timezone)
    fi
    
    # Get update interval
    echo -n "Enter update interval in seconds (press Enter for default: $DEFAULT_INTERVAL): "
    read -r interval
    if [ -z "$interval" ] || ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        interval="$DEFAULT_INTERVAL"
    fi
    
    echo ""
    print_status "$BLUE" "Configuration Summary:"
    echo "  Server Name: $server_name"
    echo "  Backend URL: $backend_url"
    echo "  API Key: ${api_key:0:10}..."
    echo "  Timezone: $timezone"
    echo "  Update Interval: ${interval}s"
    echo ""
    
    echo -n "Save this configuration? (y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        create_config "$server_name" "$backend_url" "$api_key" "$timezone" "$interval"
        print_status "$GREEN" "Setup completed successfully!"
        echo ""
        echo "Next steps:"
        echo "  $0 start    - Start the agent"
        echo "  $0 install  - Install as system service (optional)"
    else
        print_status "$YELLOW" "Setup cancelled."
    fi
}

# Function to send data to backend
send_data() {
    local vnstat_data="$1"
    
    # Get current timestamp in specified timezone
    local timestamp
    if [ "$TIMEZONE" = "UTC" ]; then
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        timestamp=$(TZ="$TIMEZONE" date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\([0-9][0-9]\)$/:\1/')
    fi
    
    # Validate JSON data first
    if ! echo "$vnstat_data" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON data received from vnstat"
        return 1
    fi
    
    # Extract bytes per second from live data
    local rx_bps=$(echo "$vnstat_data" | jq '.rx.bytespersecond // 0' 2>/dev/null || echo "0")
    local tx_bps=$(echo "$vnstat_data" | jq '.tx.bytespersecond // 0' 2>/dev/null || echo "0")
    
    # Validate that we got numeric values
    if ! [[ "$rx_bps" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        rx_bps="0"
    fi
    if ! [[ "$tx_bps" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        tx_bps="0"
    fi
    
    # Convert bytes per second to KB per second
    local rx_kbps=$(echo "scale=2; $rx_bps / 1024" | bc 2>/dev/null || echo "0")
    local tx_kbps=$(echo "scale=2; $tx_bps / 1024" | bc 2>/dev/null || echo "0")
    
    # Build JSON payload
    local json_payload=$(jq -n \
      --arg name "$SERVER_NAME" \
      --arg time "$timestamp" \
      --argjson rx "$rx_kbps" \
      --argjson tx "$tx_kbps" \
      '{server_name: $name, timestamp: $time, rx_rate: $rx, tx_rate: $tx}')
    
    # Send to backend
    local response=$(curl -s -w "%{http_code}" -X POST "$BACKEND_URL" \
      -H "Content-Type: application/json" \
      -H "x-api-key: $API_KEY" \
      -d "$json_payload" 2>/dev/null)
    
    local http_code="${response: -3}"
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_message "Data sent successfully (RX: ${rx_kbps}KB/s, TX: ${tx_kbps}KB/s)"
    else
        log_message "Failed to send data (HTTP: $http_code)"
    fi
}

# Function to start the agent
start_agent() {
    if is_running; then
        print_status "$YELLOW" "Agent is already running (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    if ! load_config; then
        print_status "$RED" "Configuration not found. Please run: $0 setup"
        return 1
    fi
    
    print_status "$BLUE" "Starting vnStat Agent..."
    print_status "$BLUE" "Server: $SERVER_NAME"
    print_status "$BLUE" "Backend: $BACKEND_URL"
    print_status "$BLUE" "Logging to: $LOG_FILE"
    
    # Start agent in background
    (
        echo $$ > "$PID_FILE"
        log_message "Agent started (PID: $$)"
        
        # Cleanup function
        cleanup() {
            log_message "Agent stopping..."
            rm -f "$PID_FILE"
            exit 0
        }
        
        trap cleanup SIGINT SIGTERM
        
        # Main monitoring loop
        while true; do
            log_message "Starting vnstat live monitoring..."
            
            vnstat -l --json | while IFS= read -r line; do
                # Check if we got a valid JSON line with data
                if echo "$line" | jq empty 2>/dev/null && [[ "$line" == *'"index"'* ]]; then
                    send_data "$line"
                fi
            done
            
            # If vnstat exits, wait before restarting
            log_message "vnstat exited, restarting in ${INTERVAL} seconds..."
            sleep "$INTERVAL"
        done
    ) &
    
    sleep 1
    if is_running; then
        print_status "$GREEN" "Agent started successfully (PID: $(cat $PID_FILE))"
    else
        print_status "$RED" "Failed to start agent"
        return 1
    fi
}

# Function to stop the agent
stop_agent() {
    if ! is_running; then
        print_status "$YELLOW" "Agent is not running"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    print_status "$BLUE" "Stopping agent (PID: $pid)..."
    
    kill "$pid" 2>/dev/null
    sleep 2
    
    if is_running; then
        print_status "$YELLOW" "Agent didn't stop gracefully, forcing..."
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi
    
    rm -f "$PID_FILE"
    print_status "$GREEN" "Agent stopped"
}

# Function to show agent status
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        print_status "$GREEN" "Agent is running (PID: $pid)"
        
        if load_config; then
            echo "Configuration:"
            echo "  Server: $SERVER_NAME"
            echo "  Backend: $BACKEND_URL"
            echo "  Timezone: $TIMEZONE"
            echo "  Interval: ${INTERVAL}s"
        fi
        
        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "Recent log entries:"
            tail -n 5 "$LOG_FILE"
        fi
    else
        print_status "$RED" "Agent is not running"
    fi
}

# Function to install as system service
install_service() {
    if [ "$EUID" -ne 0 ]; then
        print_status "$RED" "Please run as root to install system service"
        exit 1
    fi
    
    local service_file="/etc/systemd/system/vnstat-agent.service"
    local script_path="$(realpath "$0")"
    
    cat > "$service_file" << EOF
[Unit]
Description=vnStat Network Monitoring Agent
After=network.target
Wants=network-online.target

[Service]
Type=forking
User=root
WorkingDirectory=$SCRIPT_DIR
ExecStart=$script_path start
ExecStop=$script_path stop
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vnstat-agent
    
    print_status "$GREEN" "Service installed successfully!"
    echo "To start: sudo systemctl start vnstat-agent"
    echo "To check status: sudo systemctl status vnstat-agent"
}

# Main script logic
case "$1" in
    setup)
        setup
        ;;
    start)
        start_agent
        ;;
    stop)
        stop_agent
        ;;
    restart)
        stop_agent
        sleep 1
        start_agent
        ;;
    status)
        show_status
        ;;
    install)
        install_service
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
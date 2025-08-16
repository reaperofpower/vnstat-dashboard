#!/bin/bash

# LEGACY SCRIPT - Use vnstat-agent.sh for new installations
SERVER_NAME="${VNSTAT_SERVER_NAME:-PLEASE-CONFIGURE-SERVER-NAME}"  # Change this per server
BACKEND_URL="${VNSTAT_BACKEND_URL:-http://127.0.0.1:3000/api/data}"
API_KEY="${VNSTAT_API_KEY:-PLEASE-CONFIGURE-API-KEY}"
TIMEZONE="${VNSTAT_TIMEZONE:-auto}"  # Set to "auto" for automatic detection, or specify timezone

# Function to check if a command exists and prompt to install if missing
check_dependency() {
    local cmd="$1"
    local package="$2"
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed."
        echo "To install it, run: sudo apt update && sudo apt install -y $package"
        echo "Would you like to install it now? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y "$package"
            if ! command -v "$cmd" &> /dev/null; then
                echo "Failed to install $cmd. Exiting."
                exit 1
            fi
        else
            echo "Cannot continue without $cmd. Exiting."
            exit 1
        fi
    fi
}

# Check required dependencies
check_dependency "bc" "bc"
check_dependency "jq" "jq"
check_dependency "vnstat" "vnstat"
check_dependency "curl" "curl"

# Function to detect timezone automatically
detect_timezone() {
    echo "Detecting timezone automatically..."
    local api_response=$(curl -s --connect-timeout 10 "http://ip-api.com/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$api_response" ]; then
        local detected_tz=$(echo "$api_response" | jq -r '.timezone // empty' 2>/dev/null)
        if [ -n "$detected_tz" ] && [ "$detected_tz" != "null" ]; then
            echo "Detected timezone: $detected_tz"
            TIMEZONE="$detected_tz"
        else
            echo "Failed to parse timezone from API response, using UTC"
            TIMEZONE="UTC"
        fi
    else
        echo "Failed to detect timezone automatically, using UTC"
        TIMEZONE="UTC"
    fi
}

# Auto-detect timezone if set to "auto"
if [ "$TIMEZONE" = "auto" ]; then
    detect_timezone
fi

# Function to send data to backend
send_data() {
    local vnstat_data="$1"
    
    # Get current timestamp in specified timezone
    if [ "$TIMEZONE" = "UTC" ]; then
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        TIMESTAMP=$(TZ="$TIMEZONE" date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\([0-9][0-9]\)$/:\1/')
    fi
    
    # Validate JSON data first
    if ! echo "$vnstat_data" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON data received from vnstat"
        return 1
    fi
    
    # Extract bytes per second from live data
    RX_BPS=$(echo "$vnstat_data" | jq '.rx.bytespersecond // 0' 2>/dev/null || echo "0")
    TX_BPS=$(echo "$vnstat_data" | jq '.tx.bytespersecond // 0' 2>/dev/null || echo "0")
    
    # Validate that we got numeric values
    if ! [[ "$RX_BPS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        RX_BPS="0"
    fi
    if ! [[ "$TX_BPS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        TX_BPS="0"
    fi
    
    # Convert bytes per second to KB per second
    RX_KBPS=$(echo "scale=2; $RX_BPS / 1024" | bc 2>/dev/null || echo "0")
    TX_KBPS=$(echo "scale=2; $TX_BPS / 1024" | bc 2>/dev/null || echo "0")
    
    # Build JSON payload
    JSON_PAYLOAD=$(jq -n \
      --arg name "$SERVER_NAME" \
      --arg time "$TIMESTAMP" \
      --argjson rx "$RX_KBPS" \
      --argjson tx "$TX_KBPS" \
      '{server_name: $name, timestamp: $time, rx_rate: $rx, tx_rate: $tx}')
    
    # Send to backend
    curl -s -X POST "$BACKEND_URL" \
      -H "Content-Type: application/json" \
      -H "x-api-key: $API_KEY" \
      -d "$JSON_PAYLOAD" > /dev/null
}

# Function to handle cleanup on exit
cleanup() {
    echo "Stopping vnstat daemon..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo "Starting vnstat continuous monitoring daemon..."
echo "Server: $SERVER_NAME"
echo "Backend: $BACKEND_URL"
echo "Press Ctrl+C to stop"

# Main loop
while true; do
    echo "Starting vnstat live monitoring..."
    
    vnstat -l --json | while IFS= read -r line; do
        # Check if we got a valid JSON line with data
        if echo "$line" | jq empty 2>/dev/null && [[ "$line" == *'"index"'* ]]; then
            echo "Processing sample: $(echo "$line" | jq -r '.index // "unknown"')"
            send_data "$line"
        fi
    done
    
    # If vnstat exits, wait a bit before restarting
    echo "vnstat exited, restarting in 5 seconds..."
    sleep 5
done
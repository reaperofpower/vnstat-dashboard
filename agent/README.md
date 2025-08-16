# vnStat Network Monitoring Agent

An improved network monitoring agent that collects vnstat data and sends it to a centralized dashboard backend.

## Features

- **Interactive Setup**: Prompts for hostname and configuration on first run
- **Background Operation**: Runs as a daemon process
- **Automatic Hostname Detection**: Detects server hostname automatically
- **Timezone Support**: Auto-detects timezone or allows manual configuration
- **Service Management**: Can be installed as a system service
- **Logging**: Comprehensive logging of operations
- **Dependency Checking**: Automatically checks and installs required packages
- **Configuration Management**: Stores settings in a configuration file

## Quick Start

### Option 1: Using the Installer (Recommended)

```bash
# Download or copy the agent files to your server
wget https://your-domain.com/vnstat-agent.sh
wget https://your-domain.com/install.sh
chmod +x *.sh

# Run the installer
./install.sh

# Follow the prompts to configure and start
```

### Option 2: Manual Installation

```bash
# Make the script executable
chmod +x vnstat-agent.sh

# Run interactive setup
./vnstat-agent.sh setup

# Start the agent
./vnstat-agent.sh start
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Interactive setup (first time configuration) |
| `start` | Start the agent in background |
| `stop` | Stop the running agent |
| `restart` | Restart the agent |
| `status` | Show agent status and recent logs |
| `install` | Install as system service (requires root) |

## Configuration

The agent stores configuration in `agent.conf`:

```bash
# Example configuration
SERVER_NAME="my-server.example.com"
BACKEND_URL="http://92.112.126.209:3000/api/data"
API_KEY="your-api-key-here"
TIMEZONE="America/New_York"
INTERVAL="5"
```

## System Service Installation

To install as a system service (requires root):

```bash
sudo ./vnstat-agent.sh install
sudo systemctl start vnstat-agent
sudo systemctl status vnstat-agent
```

## Dependencies

The agent automatically checks for and can install:
- `bc` - Basic calculator
- `jq` - JSON processor
- `vnstat` - Network statistics utility
- `curl` - HTTP client

## Files Created

- `agent.conf` - Configuration file
- `vnstat-agent.pid` - Process ID file (when running)
- `vnstat-agent.log` - Operation log file

## Improvements Over Original

1. **No Manual Hostname Editing**: Automatically detects and prompts for hostname
2. **Background Operation**: Proper daemon functionality with PID management
3. **Service Integration**: Can be installed as systemd service
4. **Better Error Handling**: Comprehensive logging and error reporting
5. **Configuration Management**: Persistent configuration storage
6. **Status Monitoring**: Easy status checking and log viewing
7. **Automatic Dependencies**: Checks and installs required packages
8. **Timezone Detection**: Automatic timezone detection with manual override

## Usage Examples

```bash
# First time setup
./vnstat-agent.sh setup

# Start monitoring
./vnstat-agent.sh start

# Check if running
./vnstat-agent.sh status

# View recent activity
tail -f vnstat-agent.log

# Stop the agent
./vnstat-agent.sh stop

# Install as system service
sudo ./vnstat-agent.sh install
sudo systemctl enable vnstat-agent
sudo systemctl start vnstat-agent
```

## Troubleshooting

### Agent won't start
- Check if configuration exists: `ls -la agent.conf`
- Verify dependencies: `./vnstat-agent.sh setup`
- Check logs: `tail vnstat-agent.log`

### No data appearing in dashboard
- Verify backend URL and API key in configuration
- Check network connectivity: `curl -I http://92.112.126.209:3000`
- Monitor logs for HTTP errors

### Permission issues
- Ensure script is executable: `chmod +x vnstat-agent.sh`
- For system service, run installer as root: `sudo ./vnstat-agent.sh install`

## Migration from Old Scripts

If you're using the old `send_vnstat.sh` or `send_vnstat_daemon.sh`:

1. Stop any existing cron jobs or running processes
2. Run the new agent setup: `./vnstat-agent.sh setup`
3. Use your existing server name and configuration
4. Start the new agent: `./vnstat-agent.sh start`

The new agent provides better reliability and easier management.
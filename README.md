# VnStat Network Dashboard

A complete network monitoring solution that collects, aggregates, and visualizes network statistics from multiple servers using vnstat data.

![Dashboard Preview](https://img.shields.io/badge/Status-Production%20Ready-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Version](https://img.shields.io/badge/Version-2.0.0-orange)

## 🎉 What's New in v2.0

- 🔐 **Automatic API Key Generation**: Secure 32-character keys generated during installation
- 🗄️ **Interactive Database Setup**: Prompts for database credentials with connection testing  
- ⚙️ **Enhanced Configuration System**: Template-based configuration with validation
- 🛡️ **Improved Security**: No more hardcoded credentials or default API keys
- 📋 **Better Error Handling**: Detailed error messages and troubleshooting guides
- 🚀 **Streamlined Installation**: One-line installs with intelligent component selection

## 🚀 Features

### Dashboard (Frontend)
- **Real-time Monitoring**: Live network activity for the last 15 minutes with 30-second intervals
- **Historical Analysis**: Time-based aggregated views (1h, 6h, 12h, 1d, 3d, 1w)
- **Multiple Visualizations**: Combined throughput chart + individual server charts
- **Advanced Timezone Normalization**: Handles multi-timezone deployments seamlessly
- **Smart Aggregation**: Exactly 60 data points per chart with proper averaging
- **Mbps Display**: Network throughput shown in megabits per second
- **Uptime Tracking**: Server uptime percentages based on data points
- **Responsive Design**: Works on desktop and mobile devices

### Backend (API)
- **RESTful API**: Clean endpoints for data collection and retrieval
- **MySQL Storage**: Reliable data persistence with optimized queries
- **API Security**: API key authentication for all endpoints
- **CORS Support**: Configurable cross-origin resource sharing
- **Time Range Queries**: Flexible data retrieval with various time ranges
- **Data Aggregation**: Server-side data processing for performance

### Agent (Data Collection)
- **Interactive Setup**: Prompts for hostname and configuration on first run
- **Background Operation**: Runs as a proper daemon with PID management
- **Auto-detection**: Automatically detects hostname and timezone
- **Dependency Management**: Checks and installs required packages
- **Service Integration**: Can be installed as systemd service
- **Comprehensive Logging**: Detailed operation logs with rotation
- **Error Recovery**: Automatic restart on failures

## 📁 Project Structure

```
vnstat-dashboard/
├── frontend/                # React.js dashboard application
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── services/       # API service layer
│   │   ├── utils/          # Utility functions
│   │   └── App.js         # Main application
│   ├── public/            # Static assets
│   └── package.json       # Dependencies and scripts
├── backend/               # Node.js API server
│   ├── index.js          # Main server file
│   └── package.json      # Dependencies
├── agent/                # Server monitoring agent
│   ├── vnstat-agent.sh   # Main agent script
│   ├── install.sh        # Quick installer
│   └── README.md         # Agent documentation
└── README.md             # This file
```

## 🔐 Security

VnStat Dashboard v2.0+ implements enterprise-grade security practices:

- **🚫 No Hardcoded Credentials**: All API keys are generated during installation
- **🔑 Secure API Keys**: 32-character randomly generated keys using OpenSSL/urandom
- **🛡️ Environment-Based Configuration**: Credentials stored in secure config files
- **🔒 API Authentication**: All endpoints require valid API key authentication
- **🗂️ Configuration Isolation**: Frontend and backend configurations kept separate
- **⚙️ Automatic Setup**: Security configuration handled during installation

### Legacy File Security
⚠️ **Critical Security Update**: If upgrading from older versions, ensure you:

1. **API Keys**: Update any scripts using the old hardcoded API key `5QVindrQo3J8LrgWoJzSrsqk1bHGIWAE`
2. **Database Credentials**: Replace any hardcoded database connections with environment variables
3. **Configuration Migration**: Use the new `config.js` system for secure credential storage

The installer automatically handles this transition for new installations. For manual upgrades, see `backend/.env.example` for environment variable configuration.

## 🛠️ Installation

### 🚀 One-Line Installation

**Interactive installer** (prompts for component selection):
```bash
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh)
```

**Direct component installation**:
```bash
# Complete installation (everything)
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --all

# Dashboard server (frontend + backend)
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --dashboard

# Monitoring agent only (perfect for monitored servers)
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --agent

# Individual components
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --frontend
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --backend
```

### 🔄 Updates

**Automatic Update Detection**:
```bash
# The installer automatically detects existing installations and preserves configurations
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh)
```

**Force Fresh Installation**:
```bash
# Skip update mode and perform fresh installation (overwrites existing configs)
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --all --force
```

**Update Features**:
- 🔍 **Auto-Detection**: Automatically detects existing installations
- 🛡️ **Config Preservation**: Backs up and restores configuration files
- 🔄 **Smart Updates**: Only updates code files, preserves settings
- 🗂️ **Backup Creation**: Creates timestamped backups before updating
- 🚀 **Service Management**: Optional service restart after updates

> 💡 **Smart Downloads**: The installer only downloads files needed for your selected components, making it super lightweight!

### 🗑️ Uninstallation

**One-line uninstall** (interactive):
```bash
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall
```

**Direct uninstall options**:
```bash
# Remove everything
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all

# Remove specific components
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --frontend
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --backend
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --agent

# Force removal without prompts
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all --force

# Keep data/configuration files
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all --keep-data
```

> 💡 **Smart Downloads**: The installer only downloads files needed for your selected components, making it super lightweight!

### Alternative: Git Clone Installation

If you prefer to clone the full repository:

```bash
git clone https://github.com/reaperofpower/vnstat-dashboard.git
cd vnstat-dashboard
sudo ./install.sh --all  # or your preferred option
```

### Deployment Scenarios

#### Scenario 1: Single Server (Complete)
Install everything on one server:
```bash
sudo ./install.sh --all
```

#### Scenario 2: Dedicated Dashboard Server
Install dashboard components on a central server:
```bash
sudo ./install.sh --dashboard
```

#### Scenario 3: Monitored Servers
Install agent only on servers you want to monitor:
```bash
sudo ./install.sh --agent
```

#### Scenario 4: Distributed Setup
1. **Dashboard server**:
   ```bash
   sudo ./install.sh --dashboard
   ```

2. **Each monitored server**:
   ```bash
   sudo ./install.sh --agent
   ```

3. **Configure agents** to point to dashboard server in agent setup

### Manual Installation

#### Prerequisites
- Node.js 16+ (installer can install this)
- MySQL 5.7+ or MariaDB 10.3+ (installer can install this)
- Linux servers with vnstat installed (for agents)

> 💡 **New in v2.0**: The installer now includes interactive database configuration and automatic API key generation for enhanced security!

#### Backend Setup

1. **Navigate to backend directory**:
```bash
cd backend
npm install
```

2. **Configure MySQL database**:
```sql
CREATE DATABASE vnstat_dashboard;
CREATE USER 'vnstat_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON vnstat_dashboard.* TO 'vnstat_user'@'localhost';
```

3. **Configuration Options**:

**Option A: Use the installer (Recommended)**
```bash
sudo ./service-manager.sh install backend
# The installer will prompt for database details and generate an API key automatically
```

**Option B: Manual configuration**
```bash
# Copy configuration template
cp config.template.js config.js

# Edit config.js with your database details and API key
nano config.js
```

**Option C: Legacy configuration**
Update database configuration directly in `index.js` (not recommended for new installations):
```javascript
const db = mysql.createConnection({
  host: 'localhost',
  user: 'vnstat_user',
  password: 'your_password',
  database: 'vnstat_dashboard'
});
```

#### Frontend Setup

1. **Build frontend**:
```bash
cd frontend
npm install
npm run build
```

#### Service Installation

Use the included service manager for easy deployment:

```bash
# Install all services
sudo ./service-manager.sh install all

# Start services
sudo ./service-manager.sh start all

# Check status
./service-manager.sh status all
```

### Agent Deployment

#### Option 1: Using the installer (Recommended)
```bash
# Copy entire project to monitored server
scp -r vnstat-dashboard/ root@your-server:/opt/
cd /opt/vnstat-dashboard/agent
./vnstat-agent.sh setup
./vnstat-agent.sh start
```

#### Option 2: Agent-only deployment
```bash
# Copy just agent files
scp agent/* root@your-server:/opt/vnstat-agent/
cd /opt/vnstat-agent
./install.sh  # Agent-specific installer
```

3. **Follow the interactive setup**:
```bash
vnstat-agent setup
```

4. **Start monitoring**:
```bash
vnstat-agent start
```

## 🔧 Configuration

### 🆕 Automated Configuration (v2.0+)

The installer now provides **interactive configuration** for both database and API security:

#### During Backend Installation:
1. **Database Configuration**: Prompts for MySQL/MariaDB connection details
2. **API Key Generation**: Automatically generates a secure 32-character API key
3. **Connection Testing**: Validates database connectivity before proceeding
4. **Configuration File**: Creates `backend/config.js` with your settings

#### Configuration File Structure:
```javascript
// backend/config.js (auto-generated)
module.exports = {
  api: {
    port: 3000,
    host: '0.0.0.0',
    key: 'your-auto-generated-secure-api-key'
  },
  database: {
    host: 'localhost',
    user: 'your-db-user',
    password: 'your-db-password',
    database: 'your-db-name',
    port: 3306
  },
  cors: {
    enabled: true,
    origin: '*'
  }
};
```

### Environment Variables (Legacy Support)

| Variable | Description | Default |
|----------|-------------|---------|
| `API_URL` | Backend API endpoint | `http://localhost:3000/api` |
| `API_TIMEOUT` | Request timeout in ms | `30000` |
| `API_KEY` | API authentication key | Auto-generated during install |

### Agent Configuration

#### 🆕 Interactive Agent Setup (v2.0+)
```bash
# Run interactive setup (prompts for all configuration)
./vnstat-agent.sh setup
```

The setup wizard will prompt for:
- **Server Name**: Hostname for identification (auto-detected)
- **Backend URL**: Your dashboard server API endpoint
- **API Key**: The key generated during backend installation ⚠️ **Required!**
- **Timezone**: Automatic detection or manual specification
- **Update Interval**: Data submission frequency (default: 5 seconds)

#### Configuration File
The agent stores configuration in `agent.conf`:

```bash
SERVER_NAME="server.example.com"
BACKEND_URL="http://your-backend:3000/api/data"
API_KEY="your-generated-api-key-from-backend-install"
TIMEZONE="America/New_York"
INTERVAL="5"
```

#### Getting Your API Key
The API key is displayed during backend installation. You can also find it in:
```bash
# Check backend configuration
cat /opt/vnstat-dashboard/backend/config.js

# Or check backend logs during startup
sudo journalctl -u vnstat-backend -f
```

## 🚦 Usage

### Dashboard Features

1. **Real-time Chart**: Shows last 15 minutes of total throughput per server
2. **Combined Chart**: Aggregated view across all servers with selectable time ranges
3. **Server Cards**: Individual server statistics with expandable historical charts
4. **Time Range Selection**: 1h, 6h, 12h, 1d, 3d, 1w views
5. **Timezone Normalization**: Multi-timezone server support with unified time buckets

### Service Management

Use the service manager for easy control of all components:

```bash
# Service Manager Commands
./service-manager.sh {start|stop|restart|status|rebuild|install} {frontend|backend|agent|all}

# Examples
./service-manager.sh status all           # Check all services
./service-manager.sh start all            # Start all services
./service-manager.sh restart frontend     # Restart just frontend
./service-manager.sh rebuild backend      # Rebuild backend and restart
```

Or use the convenience scripts:
```bash
./start.sh      # Start all services
./stop.sh       # Stop all services  
./status.sh     # Check all services
./update.sh     # Update from git and rebuild
```

### Agent Management

```bash
# Check status
vnstat-agent status

# Start/stop/restart
vnstat-agent start
vnstat-agent stop
vnstat-agent restart

# View logs
tail -f /path/to/vnstat-agent.log

# Install as system service
sudo vnstat-agent install
sudo systemctl start vnstat-agent
```

## 📊 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/servers` | GET | List all servers with latest stats |
| `/api/aggregate` | GET | Get aggregated network statistics |
| `/api/server/:name/history` | GET | Historical data for specific server |
| `/api/data` | POST | Submit new network data (agent endpoint) |

## 🔄 Data Flow

1. **Agent Collection**: vnstat-agent.sh collects real-time vnstat data
2. **Data Transmission**: Agent sends JSON data to backend API every 5 seconds
3. **Backend Storage**: API stores data in MySQL with timestamps
4. **Frontend Queries**: Dashboard fetches and aggregates data from API
5. **Visualization**: Charts display processed data with advanced timezone normalization for multi-timezone deployments

## 🌍 Timezone Normalization

VnStat Dashboard includes **advanced timezone normalization** to handle multi-timezone deployments:

### Features
- **Automatic Detection**: Frontend automatically detects user's local timezone
- **Unified Time Buckets**: Servers from different timezones are aggregated into consistent time slots
- **Multi-Timezone Support**: Prevents data separation when servers span multiple timezones
- **Consistent Aggregation**: All charts use normalized timestamps for accurate historical analysis

### Technical Implementation
- **Frontend Normalization**: `apiService.normalizeTimestamp()` converts all timestamps to user's local timezone
- **Time Bucket Alignment**: Data aggregation aligns timestamps before grouping for accurate averaging
- **Real-time & Historical**: Works for both live monitoring and historical analysis
- **Chart Integration**: Seamlessly integrated with Chart.js time scales

### Deployment Scenarios
✅ **Single Timezone**: Works perfectly for traditional single-timezone deployments  
✅ **Multi-Timezone**: Handles servers across different timezones without data fragmentation  
✅ **Global Monitoring**: Ideal for worldwide server monitoring with centralized dashboard  

## 🎯 Performance Features

- **Browser Caching**: Reduces API calls by ~90% with localStorage caching
- **Time-based Aggregation**: 60-point maximum per chart regardless of time range
- **Randomized Refresh**: 50-70 second intervals to distribute server load
- **Efficient Queries**: Optimized database queries with proper indexing
- **Request Batching**: Multiple data requests processed in parallel

## 🐛 Troubleshooting

### Common Issues

1. **Dashboard shows no data**:
   - Verify backend API is running and accessible
   - Check API key configuration
   - Ensure agents are sending data: `vnstat-agent status`

2. **Agent connection errors**:
   - Verify backend URL and port
   - Check firewall rules  
   - **Validate API key**: Ensure agent uses the same API key from backend installation
   - Check `backend/config.js` for the correct API key
   - Run agent setup again: `./vnstat-agent.sh setup`

3. **Performance issues**:
   - Reduce agent reporting frequency
   - Check database performance and indexing
   - Monitor server resources

### Debug Commands

```bash
# Check agent logs
tail -f vnstat-agent.log

# Test API connectivity (use your generated API key)
curl -H "x-api-key: YOUR_GENERATED_API_KEY" http://your-backend:3000/api/servers

# Find your API key
grep "key:" /opt/vnstat-dashboard/backend/config.js

# Monitor backend logs
journalctl -f -u vnstat-backend

# Check database connectivity
mysql -u vnstat_user -p vnstat_dashboard
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [vnStat](https://humdi.net/vnstat/) - Network traffic monitor
- [Chart.js](https://www.chartjs.org/) - Flexible JavaScript charting
- [React](https://reactjs.org/) - Frontend framework
- [Express](https://expressjs.com/) - Backend web framework

## 📧 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting section
- Review agent logs and API responses

---

**Built with ❤️ for network monitoring enthusiasts**
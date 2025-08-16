# VnStat Dashboard Deployment Guide

## 🚀 Quick Deployment

### Before You Start

The GitHub URLs are already configured for the public repository:
- Repository: https://github.com/reaperofpower/vnstat-dashboard
- Raw files: https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/

### Deployment Scenarios

#### Scenario 1: Single Server Setup
Perfect for small setups where everything runs on one server:

```bash
# Install everything on one server
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --all
```

#### Scenario 2: Centralized Dashboard
Set up a dedicated dashboard server that monitors multiple remote servers:

**Dashboard Server:**
```bash
# Install dashboard components
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --dashboard
```

**Monitored Servers (run on each server you want to monitor):**
```bash
# Install monitoring agent only
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --agent
```

#### Scenario 3: Development Setup
Separate frontend and backend for development:

**Backend Server:**
```bash
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --backend
```

**Frontend Server:**
```bash
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --frontend
```

### Configuration After Installation

#### Dashboard Server Configuration

1. **Configure Database** (if backend installed):
   ```bash
   cd /opt/vnstat-dashboard/backend
   # Edit index.js to update database credentials
   nano index.js
   ```

2. **Start Services**:
   ```bash
   cd /opt/vnstat-dashboard
   sudo ./service-manager.sh start all
   ```

3. **Access Dashboard**: Open http://your-server-ip:8080

#### Agent Configuration

1. **Configure Agent** (run on each monitored server):
   ```bash
   cd /opt/vnstat-dashboard/agent
   ./vnstat-agent.sh setup  # Interactive setup
   ./vnstat-agent.sh start  # Start monitoring
   ```

2. **Verify Agent Status**:
   ```bash
   ./vnstat-agent.sh status
   ```

### Firewall Configuration

Open required ports:

```bash
# For dashboard server
sudo ufw allow 8080  # Frontend
sudo ufw allow 3000  # Backend API

# For monitored servers (outbound only)
# No incoming ports needed - agents connect outbound to dashboard
```

### SSL/HTTPS Setup (Optional)

Use nginx or Apache as reverse proxy:

```nginx
# nginx example
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Monitoring and Maintenance

#### Service Management
```bash
cd /opt/vnstat-dashboard

# Check status
./service-manager.sh status all

# Restart services
./service-manager.sh restart all

# View logs
sudo journalctl -f -u vnstat-frontend
sudo journalctl -f -u vnstat-backend
```

#### Agent Management
```bash
# On monitored servers
cd /opt/vnstat-dashboard/agent

# Check agent status
./vnstat-agent.sh status

# View agent logs
tail -f vnstat-agent.log

# Restart agent
./vnstat-agent.sh restart
```

#### Updates
```bash
cd /opt/vnstat-dashboard

# Update from git (if cloned)
./update.sh

# Or re-run quick installer
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --all
```

### Uninstallation

#### Quick Uninstall (Interactive)
```bash
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall
```

#### Direct Uninstall Options
```bash
# Remove everything
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all

# Remove specific components only
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --frontend
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --backend
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --agent

# Force removal without confirmation prompts
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all --force

# Keep database and configuration files
bash <(curl -s https://raw.githubusercontent.com/reaperofpower/vnstat-dashboard/main/quick-install.sh) --uninstall --all --keep-data
```

#### Manual Uninstall
If you prefer manual control:
```bash
# Using service manager
cd /opt/vnstat-dashboard
sudo ./service-manager.sh uninstall all

# Using standalone uninstaller (if available locally)
sudo ./uninstall.sh --all
```

### Troubleshooting

#### Common Issues

1. **Dashboard shows no data**:
   - Check backend service: `sudo systemctl status vnstat-backend`
   - Verify database connection in backend/index.js
   - Check agent status on monitored servers

2. **Agent connection errors**:
   - Verify backend URL in agent configuration
   - Check API key matches between backend and agent
   - Ensure firewall allows outbound connections from monitored servers

3. **Service won't start**:
   - Check logs: `sudo journalctl -u service-name`
   - Verify file permissions
   - Check Node.js installation

#### Debug Commands
```bash
# Test backend API
curl -H "x-api-key: YOUR_API_KEY" http://localhost:3000/api/servers

# Test agent connectivity
cd /opt/vnstat-dashboard/agent
./vnstat-agent.sh status

# Check service logs
sudo journalctl -f -u vnstat-frontend
sudo journalctl -f -u vnstat-backend
sudo journalctl -f -u vnstat-agent
```

### Security Considerations

1. **Change default API key** in backend configuration
2. **Use strong database passwords**
3. **Configure firewall rules** properly
4. **Keep system updated** regularly
5. **Use HTTPS in production** with proper certificates

### Performance Optimization

1. **Database optimization**:
   - Add proper indexes on timestamp columns
   - Set up log rotation for large datasets
   - Consider partitioning for very large datasets

2. **Frontend optimization**:
   - Enable gzip compression
   - Configure proper caching headers
   - Use CDN for static assets in production

3. **Agent optimization**:
   - Adjust reporting frequency if needed
   - Monitor resource usage on heavily loaded servers
   - Use agent-only installation for minimal footprint

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review logs for error messages
- Create an issue in the GitHub repository
- Check firewall and network connectivity

---

**Happy monitoring!** 📊
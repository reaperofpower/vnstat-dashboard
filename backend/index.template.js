const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();

// Load configuration
let config;
try {
  config = require('./config.js');
} catch (err) {
  console.error('❌ Configuration file not found. Please run the installer or create config.js manually.');
  console.error('Example: cp config.template.js config.js and edit the values.');
  process.exit(1);
}

// 🔐 API Key from configuration
const API_KEY = config.api.key;
const port = config.api.port;
const host = config.api.host;

app.use(cors(config.cors.enabled ? { origin: config.cors.origin } : {}));
app.use(bodyParser.json());

// 🔐 Middleware to check API key
app.use('/api', (req, res, next) => {
  const key = req.headers['x-api-key'];
  if (!key || key !== API_KEY) {
    return res.status(403).json({ 
      error: 'Forbidden', 
      message: 'Invalid or missing API key. Include x-api-key header.' 
    });
  }
  next();
});

// MySQL connection setup
const db = mysql.createConnection({
  host: config.database.host,
  user: config.database.user,
  password: config.database.password,
  database: config.database.database,
  port: config.database.port || 3306
});

// Database connection with retry logic
function connectToDatabase() {
  db.connect(err => {
    if (err) {
      console.error('❌ Failed to connect to MySQL database:');
      console.error(`   Host: ${config.database.host}:${config.database.port}`);
      console.error(`   Database: ${config.database.database}`);
      console.error(`   User: ${config.database.user}`);
      console.error(`   Error: ${err.message}`);
      console.error('');
      console.error('💡 Please check your database configuration in config.js');
      console.error('   - Verify the database server is running');
      console.error('   - Check credentials and permissions');
      console.error('   - Ensure the database exists');
      process.exit(1);
    }
    
    console.log('✅ Connected to MySQL database');
    console.log(`   Host: ${config.database.host}:${config.database.port}`);
    console.log(`   Database: ${config.database.database}`);

    // Create table if not exists
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS vnstat_data (
        id INT AUTO_INCREMENT PRIMARY KEY,
        server_name VARCHAR(255) NOT NULL,
        timestamp DATETIME NOT NULL,
        rx_rate FLOAT NOT NULL DEFAULT 0,
        tx_rate FLOAT NOT NULL DEFAULT 0,
        INDEX idx_server_timestamp (server_name, timestamp),
        INDEX idx_timestamp (timestamp)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `;
    
    db.query(createTableQuery, err => {
      if (err) {
        console.error('❌ Failed to create vnstat_data table:', err.message);
        process.exit(1);
      }
      console.log('✅ Database table ready: vnstat_data');
    });
  });
}

connectToDatabase();

// Health check endpoint (no API key required)
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    database: 'connected',
    version: '2.0.0'
  });
});

// API Info endpoint (no API key required)
app.get('/api/info', (req, res) => {
  res.json({
    name: 'VnStat Dashboard API',
    version: '2.0.0',
    endpoints: [
      'POST /api/data - Submit network data',
      'GET /api/servers - List servers with stats',
      'GET /api/aggregate - Aggregated network statistics',
      'GET /api/servers/:name/history - Server historical data'
    ],
    authentication: 'Required: x-api-key header'
  });
});

// POST endpoint to insert data
app.post('/api/data', (req, res) => {
  const { server_name, timestamp, rx_rate, tx_rate } = req.body;
  
  if (!server_name || !timestamp || rx_rate === undefined || tx_rate === undefined) {
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Missing required fields: server_name, timestamp, rx_rate, tx_rate'
    });
  }
  
  const query = 'INSERT INTO vnstat_data (server_name, timestamp, rx_rate, tx_rate) VALUES (?, ?, ?, ?)';
  db.query(query, [server_name, timestamp, rx_rate, tx_rate], (err) => {
    if (err) {
      console.error('Database insert error:', err);
      return res.status(500).json({
        error: 'Database Error',
        message: 'Failed to insert data'
      });
    }
    res.json({ success: true, message: 'Data inserted successfully' });
  });
});

// Helper function to parse time range to hours
function parseTimeRangeToHours(range) {
  if (!range) return 24; // Default to 24 hours
  
  const match = range.match(/^(\d+)([hdmwy])$/);
  if (!match) return 24; // Default if invalid format
  
  const value = parseInt(match[1]);
  const unit = match[2];
  
  switch (unit) {
    case 'h': return value;           // hours
    case 'd': return value * 24;      // days to hours
    case 'w': return value * 24 * 7;  // weeks to hours
    case 'm': return value * 24 * 30; // months to hours (approximate)
    case 'y': return value * 24 * 365; // years to hours (approximate)
    default: return 24;
  }
}

// GET endpoint to fetch data per server with time range support
app.get('/api/servers', (req, res) => {
  const range = req.query.range || '24h'; // Default to 24 hours
  const hoursBack = parseTimeRangeToHours(range);
  
  const query = `
    SELECT 
      server_name, 
      MAX(timestamp) as latest_time,
      AVG(rx_rate) as rx_rate,
      AVG(tx_rate) as tx_rate,
      COUNT(*) as data_points
    FROM vnstat_data 
    WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? HOUR)
    GROUP BY server_name
    ORDER BY server_name
  `;
  
  db.query(query, [hoursBack], (err, results) => {
    if (err) {
      console.error('Database query error:', err);
      return res.status(500).json({
        error: 'Database Error',
        message: 'Failed to fetch server data'
      });
    }
    res.json(results);
  });
});

// GET endpoint to fetch aggregated throughput with time range support
app.get('/api/aggregate', (req, res) => {
  const range = req.query.range || '24h'; // Default to 24 hours
  const hoursBack = parseTimeRangeToHours(range);
  
  const query = `
    SELECT 
      SUM(avg_rx) as total_rx, 
      SUM(avg_tx) as total_tx,
      COUNT(DISTINCT server_name) as server_count,
      MIN(earliest_time) as time_range_start,
      MAX(latest_time) as time_range_end
    FROM (
      SELECT 
        server_name,
        AVG(rx_rate) as avg_rx,
        AVG(tx_rate) as avg_tx,
        MIN(timestamp) as earliest_time,
        MAX(timestamp) as latest_time
      FROM vnstat_data
      WHERE timestamp >= DATE_SUB(NOW(), INTERVAL ? HOUR)
      GROUP BY server_name
    ) as server_averages
  `;
  
  db.query(query, [hoursBack], (err, results) => {
    if (err) {
      console.error('Database query error:', err);
      return res.status(500).json({
        error: 'Database Error',
        message: 'Failed to fetch aggregate data'
      });
    }
    res.json(results[0]);
  });
});

// GET endpoint to fetch historical data for a specific server
app.get('/api/servers/:serverName/history', (req, res) => {
  const { serverName } = req.params;
  const range = req.query.range || '1h'; // Default to 1 hour for chart
  const hoursBack = parseTimeRangeToHours(range);
  const limit = parseInt(req.query.limit) || 50; // Limit data points for chart performance
  
  const query = `
    SELECT 
      timestamp,
      rx_rate,
      tx_rate
    FROM vnstat_data 
    WHERE server_name = ? 
    AND timestamp >= DATE_SUB(NOW(), INTERVAL ? HOUR)
    ORDER BY timestamp DESC
    LIMIT ?
  `;
  
  db.query(query, [serverName, hoursBack, limit], (err, results) => {
    if (err) {
      console.error('Database query error:', err);
      return res.status(500).json({
        error: 'Database Error',
        message: 'Failed to fetch server history'
      });
    }
    // Reverse to get chronological order for chart
    res.json(results.reverse());
  });
});

// Debug endpoint to check recent data
app.get('/api/debug/recent', (req, res) => {
  const query = `
    SELECT 
      server_name, 
      timestamp, 
      rx_rate, 
      tx_rate, 
      TIMESTAMPDIFF(MINUTE, timestamp, NOW()) as minutes_ago 
    FROM vnstat_data 
    ORDER BY timestamp DESC 
    LIMIT 20
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Database query error:', err);
      return res.status(500).json({
        error: 'Database Error',
        message: 'Failed to fetch debug data'
      });
    }
    res.json({
      recent_data: results,
      current_time: new Date().toISOString(),
      api_key_configured: !!API_KEY,
      database_config: {
        host: config.database.host,
        database: config.database.database,
        user: config.database.user
      }
    });
  });
});

// Start server
app.listen(port, host, () => {
  console.log('🚀 VnStat Dashboard Backend started successfully!');
  console.log(`   URL: http://${host}:${port}`);
  console.log(`   Health: http://${host}:${port}/health`);
  console.log(`   API Info: http://${host}:${port}/api/info`);
  console.log('');
  console.log('🔐 Security:');
  console.log(`   API Key: ${API_KEY ? '✅ Configured' : '❌ Not set'}`);
  console.log('   Remember to include x-api-key header in API requests');
  console.log('');
});
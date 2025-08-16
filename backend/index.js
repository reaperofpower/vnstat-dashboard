
const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const cors = require('cors');

// ⚠️  LEGACY CONFIGURATION FILE ⚠️
// This file is kept for backward compatibility only.
// For new installations, use index.template.js with config.js
// To migrate: cp index.template.js index.js && configure your config.js

const app = express();
const port = 3000;

// 🔐 API Key Configuration
// IMPORTANT: This is the legacy configuration method
// For new installations, use the config.js system (see index.template.js)
const API_KEY = process.env.VNSTAT_API_KEY || "PLEASE-CONFIGURE-SECURE-API-KEY";

app.use(cors());
app.use(bodyParser.json());

// 🔐 Middleware to check API key
app.use((req, res, next) => {
  const key = req.headers['x-api-key'];
  if (key !== API_KEY) {
    return res.status(403).send('Forbidden: Invalid API Key');
  }
  next();
});

// MySQL connection setup
// IMPORTANT: This is the legacy configuration method
// For new installations, use the config.js system (see index.template.js)
const db = mysql.createConnection({
  host: process.env.VNSTAT_DB_HOST || 'localhost',
  user: process.env.VNSTAT_DB_USER || 'PLEASE-CONFIGURE-DB-USER',
  password: process.env.VNSTAT_DB_PASSWORD || 'PLEASE-CONFIGURE-DB-PASSWORD',
  database: process.env.VNSTAT_DB_NAME || 'PLEASE-CONFIGURE-DB-NAME',
  port: process.env.VNSTAT_DB_PORT || 3306
});

db.connect(err => {
  if (err) throw err;
  console.log('Connected to MySQL database.');

  // Create table if not exists
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS vnstat_data (
      id INT AUTO_INCREMENT PRIMARY KEY,
      server_name VARCHAR(255),
      timestamp DATETIME,
      rx_rate FLOAT,
      tx_rate FLOAT
    )
  `;
  db.query(createTableQuery, err => {
    if (err) throw err;
    console.log('vnstat_data table ensured.');
  });
});

// POST endpoint to insert data
app.post('/api/data', (req, res) => {
  const { server_name, timestamp, rx_rate, tx_rate } = req.body;
  const query = 'INSERT INTO vnstat_data (server_name, timestamp, rx_rate, tx_rate) VALUES (?, ?, ?, ?)';
  db.query(query, [server_name, timestamp, rx_rate, tx_rate], (err) => {
    if (err) {
      console.error(err);
      return res.status(500).send('Database insert error');
    }
    res.send('Data inserted successfully');
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
      console.error(err);
      return res.status(500).send('Database query error');
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
      console.error(err);
      return res.status(500).send('Database query error');
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
      console.error(err);
      return res.status(500).send('Database query error');
    }
    // Reverse to get chronological order for chart
    res.json(results.reverse());
  });
});

// Debug endpoint to check data timestamps
app.get('/api/debug/data', (req, res) => {
  const query = 'SELECT server_name, timestamp, rx_rate, tx_rate, TIMESTAMPDIFF(HOUR, timestamp, NOW()) as hours_ago FROM vnstat_data ORDER BY timestamp DESC LIMIT 20';
  
  db.query(query, (err, results) => {
    if (err) {
      console.error(err);
      return res.status(500).send('Database query error');
    }
    res.json(results);
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`vnStat backend listening at http://0.0.0.0:${port}`);
});

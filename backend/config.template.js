// VnStat Dashboard Backend Configuration Template
// This file is used by the installer to generate config.js

module.exports = {
  // API Configuration
  api: {
    port: 3000,
    host: '0.0.0.0',
    key: '{{API_KEY}}' // Will be replaced by installer
  },
  
  // Database Configuration
  database: {
    host: '{{DB_HOST}}',
    user: '{{DB_USER}}',
    password: '{{DB_PASSWORD}}',
    database: '{{DB_NAME}}',
    port: 3306
  },
  
  // CORS Configuration
  cors: {
    enabled: true,
    origin: '*' // Configure as needed
  }
};
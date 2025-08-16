// Format bytes with proper units
export const formatBytes = (bytes, decimals = 2) => {
  if (bytes === 0 || bytes === null || bytes === undefined || isNaN(bytes)) {
    return '0 B/s';
  }

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];

  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

// Format bytes specifically for KiB/s data from backend
export const formatKiB = (kib, decimals = 2) => {
  if (kib === 0 || kib === null || kib === undefined || isNaN(kib)) {
    return '0 KiB/s';
  }
  
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['KiB/s', 'MiB/s', 'GiB/s', 'TiB/s'];
  
  // If less than 1 KiB/s, show in bytes
  if (kib < 1) {
    return (kib * 1024).toFixed(dm) + ' B/s';
  }
  
  const i = Math.floor(Math.log(kib) / Math.log(k));
  return parseFloat((kib / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
};

// Get numeric value and unit separately for chart formatting
export const getValueAndUnit = (kib) => {
  if (kib === 0 || kib === null || kib === undefined || isNaN(kib)) {
    return { value: 0, unit: 'KiB/s' };
  }
  
  const k = 1024;
  const sizes = ['KiB/s', 'MiB/s', 'GiB/s', 'TiB/s'];
  
  if (kib < 1) {
    return { value: parseFloat((kib * 1024).toFixed(2)), unit: 'B/s' };
  }
  
  const i = Math.floor(Math.log(kib) / Math.log(k));
  const value = parseFloat((kib / Math.pow(k, i)).toFixed(2));
  
  return { value, unit: sizes[i] };
};

// Calculate time difference for status display
export const getTimeDifference = (timestamp) => {
  if (!timestamp) return { text: 'Unknown', status: 'offline', color: '#f44336' };
  
  const now = new Date();
  const lastUpdate = new Date(timestamp);
  const diffMinutes = Math.floor((now - lastUpdate) / (1000 * 60));
  
  let status = 'online';
  let color = '#4caf50';
  let text = `${diffMinutes}m ago`;
  
  if (diffMinutes > 15) {
    status = 'offline';
    color = '#f44336';
    const hours = Math.floor(diffMinutes / 60);
    const mins = diffMinutes % 60;
    text = `Offline (${hours}h ${mins}m ago)`;
  } else if (diffMinutes > 5) {
    status = 'warning';
    color = '#ff9800';
    text = `${diffMinutes}m ago`;
  } else if (diffMinutes < 1) {
    text = 'Just now';
  }
  
  return { text, status, color };
};

// Normalize data for consistent chart display
export const normalizeChartData = (data, key) => {
  if (!Array.isArray(data) || data.length === 0) return [];
  
  return data
    .filter(item => item[key] !== null && item[key] !== undefined && !isNaN(item[key]))
    .map(item => ({
      ...item,
      [key]: Number(item[key])
    }));
};

// Calculate average of array values
export const calculateAverage = (values) => {
  if (!Array.isArray(values) || values.length === 0) return 0;
  
  const validValues = values.filter(val => val !== null && val !== undefined && !isNaN(val));
  if (validValues.length === 0) return 0;
  
  return validValues.reduce((sum, val) => sum + Number(val), 0) / validValues.length;
};

// Calculate uptime based on data points over time
export const calculateUptime = (dataPoints, timeRange = '24h') => {
  if (!dataPoints || dataPoints <= 0) return { percentage: 0, text: '0% uptime' };
  
  // Expected data points based on time range (assuming ~5 second intervals)
  const expectedPointsMap = {
    '1h': 720,    // 60 minutes * 12 points per minute
    '6h': 4320,   // 6 * 60 * 12
    '12h': 8640,  // 12 * 60 * 12
    '1d': 17280,  // 24 * 60 * 12
    '3d': 51840,  // 3 * 24 * 60 * 12
    '1w': 120960  // 7 * 24 * 60 * 12
  };
  
  const expectedPoints = expectedPointsMap[timeRange] || expectedPointsMap['1d'];
  const percentage = Math.min(100, (dataPoints / expectedPoints) * 100);
  
  if (percentage >= 99) return { percentage, text: '99%+ uptime' };
  if (percentage >= 95) return { percentage, text: `${percentage.toFixed(1)}% uptime` };
  if (percentage >= 80) return { percentage, text: `${percentage.toFixed(1)}% uptime` };
  
  return { percentage, text: `${percentage.toFixed(1)}% uptime` };
};
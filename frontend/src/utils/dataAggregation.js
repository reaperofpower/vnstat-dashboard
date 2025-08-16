// Data aggregation utilities for time-based averaging
import { format, startOfMinute, startOfHour, startOfDay, addMinutes, addHours, addDays, subHours, subDays, subMinutes } from 'date-fns';
import { apiService } from '../services/apiService';

// Standardize timestamps to consistent intervals to handle server time differences
const standardizeTimestamp = (timestamp, timeRange = '1h') => {
  const date = new Date(timestamp);
  
  // Choose interval based on time range
  let intervalSeconds;
  switch (timeRange) {
    case '1h':
    case '6h':
      intervalSeconds = 5; // 5-second intervals for short ranges
      break;
    case '12h':
    case '1d':
      intervalSeconds = 30; // 30-second intervals for medium ranges
      break;
    case '3d':
    case '1w':
      intervalSeconds = 60; // 1-minute intervals for long ranges
      break;
    default:
      intervalSeconds = 5;
  }
  
  const seconds = date.getSeconds();
  const standardizedSeconds = Math.floor(seconds / intervalSeconds) * intervalSeconds;
  
  // Round to nearest interval
  const standardized = new Date(date);
  standardized.setSeconds(standardizedSeconds, 0); // Set seconds and clear milliseconds
  
  return standardized;
};

// Get the appropriate time bucket function based on time range
const getTimeBucketFunction = (timeRange) => {
  switch (timeRange) {
    case '1h':
      return startOfMinute; // 1-minute buckets for 1 hour = ~60 points
    case '6h':
      return (date) => {
        const start = startOfHour(date);
        const minutes = Math.floor(date.getMinutes() / 6) * 6; // 6-minute buckets = ~60 points
        return addMinutes(start, minutes);
      };
    case '12h':
      return (date) => {
        const start = startOfHour(date);
        const minutes = Math.floor(date.getMinutes() / 12) * 12; // 12-minute buckets = ~60 points
        return addMinutes(start, minutes);
      };
    case '1d':
      return (date) => {
        const start = startOfHour(date);
        const minutes = Math.floor(date.getMinutes() / 24) * 24; // 24-minute buckets = ~60 points
        return addMinutes(start, minutes);
      };
    case '3d':
      return (date) => {
        const start = startOfHour(date);
        const hours = Math.floor(date.getHours() / 1.2) * 1.2; // ~1.2-hour buckets = ~60 points
        return addHours(startOfDay(date), Math.floor(hours));
      };
    case '1w':
      return (date) => {
        const start = startOfHour(date);
        const hours = Math.floor(date.getHours() / 2.8) * 2.8; // ~2.8-hour buckets = ~60 points
        return addHours(startOfDay(date), Math.floor(hours));
      };
    default:
      return startOfMinute;
  }
};

// Get the number of data points we want for each time range
const getTargetDataPoints = (timeRange) => {
  switch (timeRange) {
    case '1h': return 60;    // 1 point per minute
    case '6h': return 60;    // 1 point per 6 minutes
    case '12h': return 60;   // 1 point per 12 minutes
    case '1d': return 60;    // 1 point per 24 minutes
    case '3d': return 60;    // 1 point per ~1.2 hours
    case '1w': return 60;    // 1 point per ~2.8 hours
    default: return 60;
  }
};

// Get the cutoff time for filtering data to the requested time range
const getTimeRangeCutoff = (timeRange) => {
  const now = new Date();
  switch (timeRange) {
    case '1h': return subHours(now, 1);
    case '6h': return subHours(now, 6);
    case '12h': return subHours(now, 12);
    case '1d': return subHours(now, 24);
    case '3d': return subDays(now, 3);
    case '1w': return subDays(now, 7);
    default: return subHours(now, 1);
  }
};

// Aggregate raw data points into time buckets with averaging
export const aggregateDataByTime = (rawData, timeRange) => {
  if (!rawData || !Array.isArray(rawData) || rawData.length === 0) {
    return [];
  }

  const bucketFunction = getTimeBucketFunction(timeRange);
  const cutoffTime = getTimeRangeCutoff(timeRange);
  const buckets = new Map();

  // Group data points into time buckets, filtering by time range
  rawData.forEach(point => {
    if (!point.timestamp || (!point.rx_rate && point.rx_rate !== 0) || (!point.tx_rate && point.tx_rate !== 0)) {
      return;
    }

    const normalizedTime = apiService.normalizeTimestamp(point.timestamp);
    
    // Filter out data points that are outside the requested time range
    if (normalizedTime < cutoffTime) {
      return;
    }

    // Standardize timestamp to handle small time differences between servers
    const standardizedTime = standardizeTimestamp(normalizedTime, timeRange);
    const bucketTime = bucketFunction(standardizedTime);
    const bucketKey = bucketTime.getTime();

    if (!buckets.has(bucketKey)) {
      buckets.set(bucketKey, {
        timestamp: bucketTime,
        rx_values: [],
        tx_values: [],
        count: 0
      });
    }

    const bucket = buckets.get(bucketKey);
    bucket.rx_values.push(Number(point.rx_rate) || 0);
    bucket.tx_values.push(Number(point.tx_rate) || 0);
    bucket.count++;
  });

  // Calculate averages for each bucket
  const aggregatedData = Array.from(buckets.values())
    .map(bucket => ({
      timestamp: bucket.timestamp,
      rx_rate: bucket.rx_values.length > 0 
        ? bucket.rx_values.reduce((sum, val) => sum + val, 0) / bucket.rx_values.length 
        : 0,
      tx_rate: bucket.tx_values.length > 0 
        ? bucket.tx_values.reduce((sum, val) => sum + val, 0) / bucket.tx_values.length 
        : 0,
      data_points: bucket.count,
      timestamp_formatted: format(bucket.timestamp, 'MMM dd, HH:mm:ss')
    }))
    .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

  // Limit to target number of data points (keep most recent)
  const targetPoints = getTargetDataPoints(timeRange);
  if (aggregatedData.length > targetPoints) {
    return aggregatedData.slice(-targetPoints);
  }

  return aggregatedData;
};

// Aggregate combined data from multiple servers
export const aggregateCombinedServerData = (allServerData, timeRange) => {
  if (!allServerData || !Array.isArray(allServerData) || allServerData.length === 0) {
    return [];
  }

  const bucketFunction = getTimeBucketFunction(timeRange);
  const cutoffTime = getTimeRangeCutoff(timeRange);
  const buckets = new Map();

  // Process each server's data
  allServerData.forEach((serverData, serverIndex) => {
    if (!serverData || !Array.isArray(serverData) || serverData.length === 0) {
      return;
    }

    serverData.forEach(point => {
      if (!point.timestamp || (!point.rx_rate && point.rx_rate !== 0) || (!point.tx_rate && point.tx_rate !== 0)) {
        return;
      }

      const normalizedTime = apiService.normalizeTimestamp(point.timestamp);
      
      // Filter out data points that are outside the requested time range
      if (normalizedTime < cutoffTime) {
        return;
      }

      // Standardize timestamp to handle small time differences between servers
      const standardizedTime = standardizeTimestamp(normalizedTime, timeRange);
      const bucketTime = bucketFunction(standardizedTime);
      const bucketKey = bucketTime.getTime();

      if (!buckets.has(bucketKey)) {
        buckets.set(bucketKey, {
          timestamp: bucketTime,
          servers: new Map(),
          total_rx: 0,
          total_tx: 0,
          server_count: 0
        });
      }

      const bucket = buckets.get(bucketKey);
      
      if (!bucket.servers.has(serverIndex)) {
        bucket.servers.set(serverIndex, {
          rx_values: [],
          tx_values: []
        });
      }

      const serverBucket = bucket.servers.get(serverIndex);
      serverBucket.rx_values.push(Number(point.rx_rate) || 0);
      serverBucket.tx_values.push(Number(point.tx_rate) || 0);
    });
  });

  // Calculate combined averages for each time bucket
  const combinedData = Array.from(buckets.values())
    .map(bucket => {
      let totalRx = 0;
      let totalTx = 0;
      let serverCount = 0;

      bucket.servers.forEach(serverData => {
        if (serverData.rx_values.length > 0 && serverData.tx_values.length > 0) {
          const avgRx = serverData.rx_values.reduce((sum, val) => sum + val, 0) / serverData.rx_values.length;
          const avgTx = serverData.tx_values.reduce((sum, val) => sum + val, 0) / serverData.tx_values.length;
          
          totalRx += avgRx;
          totalTx += avgTx;
          serverCount++;
        }
      });

      return {
        timestamp: bucket.timestamp,
        total_rx: totalRx,
        total_tx: totalTx,
        server_count: serverCount,
        timestamp_formatted: format(bucket.timestamp, 'MMM dd, HH:mm:ss')
      };
    })
    .filter(point => point.server_count > 0) // Only include buckets with data
    .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

  // Limit to target number of data points
  const targetPoints = getTargetDataPoints(timeRange);
  if (combinedData.length > targetPoints) {
    return combinedData.slice(-targetPoints);
  }

  return combinedData;
};

// Get appropriate time range for backend API calls based on frontend time range
export const getBackendTimeRange = (frontendTimeRange) => {
  switch (frontendTimeRange) {
    case '1h': return '75m';  // Get 75 minutes of data to ensure we have full hour coverage
    case '6h': return '8h';   // Get 8 hours for 6 hours of display
    case '12h': return '15h'; // Get 15 hours for 12 hours of display
    case '1d': return '30h';  // Get 30 hours for 1 day of display
    case '3d': return '4d';   // Get 4 days for 3 days of display
    case '1w': return '10d';  // Get 10 days for 1 week of display
    default: return '75m';
  }
};

// Get limit for backend API calls (more raw data points for better averaging)
export const getBackendLimit = (timeRange) => {
  switch (timeRange) {
    case '1h': return 900;   // Get ~75 minutes worth of 5-second data points (75*60/5 = 900)
    case '6h': return 600;   // Increased for better 6-hour coverage  
    case '12h': return 800;  // Increased for better 12-hour coverage
    case '1d': return 1440;  // Get 30 hours worth of data points (30*60/1.25 ≈ 1440)
    case '3d': return 720;   // Increased for better 3-day coverage
    case '1w': return 840;   // Increased for better 1-week coverage
    default: return 900;
  }
};
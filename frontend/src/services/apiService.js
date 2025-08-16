import axios from 'axios';
import { zonedTimeToUtc, utcToZonedTime, format } from 'date-fns-tz';
import { parseISO } from 'date-fns';
import { setCacheData, getCacheData } from '../utils/browserCache';

const API_URL = process.env.REACT_APP_API_URL || 'http://127.0.0.1:3000/api';
const API_TIMEOUT = parseInt(process.env.REACT_APP_API_TIMEOUT) || 30000;

const apiClient = axios.create({
  baseURL: API_URL,
  timeout: API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': process.env.REACT_APP_API_KEY || 'Please-configure-API-key-in-environment'
  }
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error);
    
    if (error.code === 'ECONNABORTED') {
      return Promise.reject(new Error('Request timeout - server took too long to respond'));
    }
    
    if (error.response) {
      const { status, data } = error.response;
      return Promise.reject(new Error(`Server error (${status}): ${data?.message || 'Unknown error'}`));
    } else if (error.request) {
      return Promise.reject(new Error('Network error - unable to connect to server'));
    } else {
      return Promise.reject(new Error(`Request failed: ${error.message}`));
    }
  }
);

// Get user's timezone
const getUserTimezone = () => {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
};

// Normalize timestamp to user's timezone
const normalizeTimestamp = (timestamp) => {
  if (!timestamp) return null;
  
  try {
    const userTz = getUserTimezone();
    let date;
    
    // Handle different timestamp formats
    if (typeof timestamp === 'string') {
      // If it's already an ISO string, parse it
      if (timestamp.includes('T') || timestamp.includes('Z')) {
        date = parseISO(timestamp);
      } else {
        // Assume it's a MySQL datetime string (treat as UTC)
        date = parseISO(timestamp + 'Z');
      }
    } else if (timestamp instanceof Date) {
      date = timestamp;
    } else {
      // Assume it's a Unix timestamp
      date = new Date(timestamp);
    }
    
    // Convert to user's timezone
    const zonedDate = utcToZonedTime(date, userTz);
    return zonedDate;
  } catch (error) {
    console.error('Error normalizing timestamp:', error);
    return new Date(timestamp);
  }
};

// Format timestamp for display
const formatTimestamp = (timestamp, formatString = 'MMM dd, HH:mm:ss') => {
  const normalized = normalizeTimestamp(timestamp);
  if (!normalized) return 'Unknown';
  
  const userTz = getUserTimezone();
  return format(normalized, formatString, { timeZone: userTz });
};

// Simple request cache to prevent duplicate requests
const requestCache = new Map();
const CACHE_TTL = 5000; // 5 seconds

const getCachedRequest = (key) => {
  const cached = requestCache.get(key);
  if (cached && (Date.now() - cached.timestamp < CACHE_TTL)) {
    return cached.promise;
  }
  return null;
};

const setCachedRequest = (key, promise) => {
  requestCache.set(key, {
    promise,
    timestamp: Date.now()
  });
  
  // Clean up cache entry after completion
  promise.finally(() => {
    setTimeout(() => requestCache.delete(key), CACHE_TTL);
  });
  
  return promise;
};

// Retry function with exponential backoff
const retryRequest = async (requestFn, retries = 2, delay = 2000) => {
  for (let i = 0; i < retries; i++) {
    try {
      return await requestFn();
    } catch (error) {
      // Don't retry on timeout errors for large requests
      if (error.code === 'ECONNABORTED' && i > 0) {
        throw error;
      }
      
      if (i === retries - 1) throw error;
      
      console.log(`Request failed, retrying in ${delay}ms... (${i + 1}/${retries})`);
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 1.5; // Less aggressive exponential backoff
    }
  }
};

export const apiService = {
  // Get all servers with current data
  getServers: async (timeRange = '1d', forceRefresh = false) => {
    const cacheParams = { range: timeRange };
    
    // Check browser cache first (unless force refresh)
    if (!forceRefresh) {
      const cachedData = getCacheData('servers', cacheParams);
      if (cachedData) {
        console.log(`Using cached servers data (${timeRange})`);
        return cachedData;
      }
    }
    
    // Fetch fresh data
    console.log(`Fetching fresh servers data (${timeRange})`);
    const servers = await retryRequest(async () => {
      const response = await apiClient.get(`/servers?range=${timeRange}`);
      return response.data;
    });
    
    // Process and normalize data
    const processedData = servers.map(server => ({
      ...server,
      latest_time: normalizeTimestamp(server.latest_time),
      latest_time_formatted: formatTimestamp(server.latest_time)
    }));
    
    // Cache for 8 seconds (shorter than refresh interval)
    setCacheData('servers', processedData, cacheParams, 8000);
    
    return processedData;
  },

  // Get aggregated data
  getAggregate: async (timeRange = '1d', forceRefresh = false) => {
    const cacheParams = { range: timeRange };
    
    // Check browser cache first (unless force refresh)
    if (!forceRefresh) {
      const cachedData = getCacheData('aggregate', cacheParams);
      if (cachedData) {
        console.log(`Using cached aggregate data (${timeRange})`);
        return cachedData;
      }
    }
    
    // Fetch fresh data
    console.log(`Fetching fresh aggregate data (${timeRange})`);
    const data = await retryRequest(async () => {
      const response = await apiClient.get(`/aggregate?range=${timeRange}`);
      return response.data;
    });
    
    const processedData = {
      ...data,
      time_range_start: normalizeTimestamp(data.time_range_start),
      time_range_end: normalizeTimestamp(data.time_range_end),
      time_range_start_formatted: formatTimestamp(data.time_range_start),
      time_range_end_formatted: formatTimestamp(data.time_range_end)
    };
    
    // Cache for 8 seconds (shorter than refresh interval)
    setCacheData('aggregate', processedData, cacheParams, 8000);
    
    return processedData;
  },

  // Get historical data for charts
  getServerHistory: async (serverName, timeRange = '1h', limit = 50, forceRefresh = false) => {
    const cacheParams = { server: serverName, range: timeRange, limit };
    
    // Check browser cache first (unless force refresh)
    if (!forceRefresh) {
      const cachedData = getCacheData('history', cacheParams);
      if (cachedData) {
        console.log(`Using cached history data for ${serverName} (${timeRange})`);
        return cachedData;
      }
    }
    
    // Fetch fresh data
    console.log(`Fetching fresh history data for ${serverName} (${timeRange})`);
    const historyData = await retryRequest(async () => {
      const response = await apiClient.get(`/servers/${encodeURIComponent(serverName)}/history?range=${timeRange}&limit=${limit}`);
      return response.data;
    });
    
    // Process and normalize data
    const processedData = historyData.map(point => ({
      ...point,
      timestamp: normalizeTimestamp(point.timestamp),
      timestamp_formatted: formatTimestamp(point.timestamp, 'HH:mm:ss')
    })).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    
    // Cache the processed data for 45 seconds (shorter than refresh interval)
    setCacheData('history', processedData, cacheParams, 45000);
    
    return processedData;
  },

  // Get all data at once with error resilience
  getAllData: async (timeRange = '1d', forceRefresh = false) => {
    try {
      const [serversResult, aggregateResult] = await Promise.allSettled([
        apiService.getServers(timeRange, forceRefresh),
        apiService.getAggregate(timeRange, forceRefresh)
      ]);
      
      const servers = serversResult.status === 'fulfilled' ? serversResult.value : [];
      const aggregate = aggregateResult.status === 'fulfilled' ? aggregateResult.value : { 
        total_rx: 0, 
        total_tx: 0, 
        server_count: 0 
      };
      
      // If both requests failed, throw an error
      if (serversResult.status === 'rejected' && aggregateResult.status === 'rejected') {
        throw new Error(`Failed to fetch data: ${serversResult.reason?.message || 'Unknown error'}`);
      }
      
      return { servers, aggregate };
    } catch (error) {
      throw new Error(`Failed to fetch data: ${error.message}`);
    }
  },

  // Utility functions
  getUserTimezone,
  normalizeTimestamp,
  formatTimestamp
};

export default apiService;
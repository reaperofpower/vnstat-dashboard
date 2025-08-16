// Browser cache utilities for vnstat dashboard data
const CACHE_PREFIX = 'vnstat_';
const DEFAULT_CACHE_DURATION = 60000; // 60 seconds

// Generate random interval between 50-70 seconds
export const getRandomRefreshInterval = () => {
  return Math.floor(Math.random() * 20000) + 50000; // 50000-70000ms (50-70 seconds)
};

// Get cache key for data
const getCacheKey = (type, params = {}) => {
  const paramString = Object.keys(params).length > 0 
    ? '_' + Object.values(params).join('_') 
    : '';
  return `${CACHE_PREFIX}${type}${paramString}`;
};

// Check if cached data is still valid
const isCacheValid = (timestamp, duration = DEFAULT_CACHE_DURATION) => {
  return Date.now() - timestamp < duration;
};

// Set data in browser cache
export const setCacheData = (type, data, params = {}, duration = DEFAULT_CACHE_DURATION) => {
  try {
    const cacheKey = getCacheKey(type, params);
    const cacheData = {
      data,
      timestamp: Date.now(),
      duration
    };
    localStorage.setItem(cacheKey, JSON.stringify(cacheData));
    return true;
  } catch (error) {
    console.warn('Failed to cache data:', error);
    return false;
  }
};

// Get data from browser cache
export const getCacheData = (type, params = {}) => {
  try {
    const cacheKey = getCacheKey(type, params);
    const cachedItem = localStorage.getItem(cacheKey);
    
    if (!cachedItem) {
      return null;
    }
    
    const { data, timestamp, duration } = JSON.parse(cachedItem);
    
    if (isCacheValid(timestamp, duration)) {
      return data;
    } else {
      // Clean up expired cache
      localStorage.removeItem(cacheKey);
      return null;
    }
  } catch (error) {
    console.warn('Failed to get cached data:', error);
    return null;
  }
};

// Clear specific cache entry
export const clearCacheData = (type, params = {}) => {
  try {
    const cacheKey = getCacheKey(type, params);
    localStorage.removeItem(cacheKey);
    return true;
  } catch (error) {
    console.warn('Failed to clear cache:', error);
    return false;
  }
};

// Clear all vnstat cache data
export const clearAllCache = () => {
  try {
    const keysToRemove = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith(CACHE_PREFIX)) {
        keysToRemove.push(key);
      }
    }
    
    keysToRemove.forEach(key => localStorage.removeItem(key));
    return true;
  } catch (error) {
    console.warn('Failed to clear all cache:', error);
    return false;
  }
};

// Get cache size and info
export const getCacheInfo = () => {
  try {
    let cacheSize = 0;
    let entryCount = 0;
    const entries = [];
    
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith(CACHE_PREFIX)) {
        const value = localStorage.getItem(key);
        if (value) {
          cacheSize += value.length;
          entryCount++;
          
          try {
            const { timestamp, duration } = JSON.parse(value);
            entries.push({
              key: key.replace(CACHE_PREFIX, ''),
              size: value.length,
              age: Date.now() - timestamp,
              expires: timestamp + duration,
              valid: isCacheValid(timestamp, duration)
            });
          } catch (e) {
            // Invalid cache entry
          }
        }
      }
    }
    
    return {
      totalSize: cacheSize,
      entryCount,
      entries
    };
  } catch (error) {
    console.warn('Failed to get cache info:', error);
    return { totalSize: 0, entryCount: 0, entries: [] };
  }
};
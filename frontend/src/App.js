import React, { useState, useEffect, useCallback } from 'react';
import RealtimeChart from './components/RealtimeChart';
import CombinedChart from './components/CombinedChart';
import ServerCard from './components/ServerCard';
import LoadingSpinner from './components/LoadingSpinner';
import ErrorDisplay from './components/ErrorDisplay';
import VersionFooter from './components/VersionFooter';
import ThemeToggle from './components/ThemeToggle';
import { apiService } from './services/apiService';
import { getRandomRefreshInterval } from './utils/browserCache';

function App() {
  const [servers, setServers] = useState([]);
  const [aggregate, setAggregate] = useState({ total_rx: 0, total_tx: 0, server_count: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const [timeRange, setTimeRange] = useState('1d');

  const fetchData = useCallback(async (forceRefresh = false) => {
    try {
      setLoading(true);
      setError(null);

      const { servers: serverData, aggregate: aggData } = await apiService.getAllData(timeRange, forceRefresh);

      // Validate and set servers data
      const validServers = Array.isArray(serverData) ? serverData.filter(server => 
        server && 
        typeof server.server_name === 'string' && 
        server.server_name.trim() !== '' &&
        typeof server.rx_rate === 'number' &&
        typeof server.tx_rate === 'number'
      ) : [];

      // Validate and set aggregate data
      const validAggregate = {
        total_rx: typeof aggData?.total_rx === 'number' ? aggData.total_rx : 0,
        total_tx: typeof aggData?.total_tx === 'number' ? aggData.total_tx : 0,
        server_count: typeof aggData?.server_count === 'number' ? aggData.server_count : validServers.length,
        time_range_start: aggData?.time_range_start,
        time_range_end: aggData?.time_range_end
      };

      setServers(validServers);
      setAggregate(validAggregate);
      setLastUpdate(new Date());
      
      // Trigger refresh for child components
      setRefreshTrigger(prev => prev + 1);

    } catch (err) {
      console.error('Failed to fetch data:', err);
      setError(err.message || 'Failed to fetch data');
      
      // Keep existing data on error to prevent blank screen
      if (servers.length === 0) {
        setServers([]);
        setAggregate({ total_rx: 0, total_tx: 0, server_count: 0 });
      }
    } finally {
      setLoading(false);
    }
  }, [timeRange, servers.length]);

  const handleRetry = useCallback(() => {
    fetchData();
  }, [fetchData]);

  const handleTimeRangeChange = useCallback((newRange) => {
    if (newRange !== timeRange) {
      setTimeRange(newRange);
    }
  }, [timeRange]);

  useEffect(() => {
    // Initial load uses cache
    fetchData(false);

    // Set up randomized refresh between 50-70 seconds with force refresh
    const setupRandomRefresh = () => {
      const randomInterval = getRandomRefreshInterval();
      console.log(`Next refresh in ${Math.round(randomInterval/1000)} seconds`);
      
      return setTimeout(() => {
        if (!loading) {
          console.log('Performing scheduled refresh with fresh data');
          fetchData(true); // Force refresh on scheduled updates
        }
        // Schedule next random refresh
        const nextIntervalId = setupRandomRefresh();
        return nextIntervalId;
      }, randomInterval);
    };

    const intervalId = setupRandomRefresh();

    return () => clearTimeout(intervalId);
  }, [fetchData, loading]);

  const getStatusColor = () => {
    if (loading) return '#ff9800';
    if (error) return '#f44336';
    return '#4caf50';
  };

  const getStatusText = () => {
    if (loading) return 'Updating...';
    if (error) return 'Connection Error';
    return 'Connected';
  };

  return (
    <div className="container">
      {/* Header */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center',
        marginBottom: '20px',
        flexWrap: 'wrap',
        gap: '15px'
      }}>
        <h1 style={{ 
          margin: '0', 
          color: 'var(--text-primary)', 
          display: 'flex', 
          alignItems: 'center', 
          gap: '12px',
          fontSize: '2rem',
          fontWeight: '600'
        }}>
          <svg 
            width="40" 
            height="40" 
            viewBox="0 0 40 40" 
            fill="none" 
            xmlns="http://www.w3.org/2000/svg"
            style={{ filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.1))' }}
          >
            {/* Network monitoring icon */}
            <rect width="40" height="40" rx="8" fill="url(#gradient)" />
            <defs>
              <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#4CAF50" />
                <stop offset="100%" stopColor="#45a049" />
              </linearGradient>
            </defs>
            {/* Server/router icon */}
            <rect x="6" y="8" width="28" height="6" rx="2" fill="white" opacity="0.9" />
            <circle cx="10" cy="11" r="1" fill="#4CAF50" />
            <circle cx="13" cy="11" r="1" fill="#4CAF50" />
            <circle cx="16" cy="11" r="1" fill="#4CAF50" />
            
            {/* Network activity lines */}
            <path d="M8 18 L16 22 L24 18 L32 22" stroke="white" strokeWidth="2" fill="none" opacity="0.8" />
            <path d="M8 24 L16 28 L24 24 L32 28" stroke="white" strokeWidth="2" fill="none" opacity="0.6" />
            <path d="M8 30 L16 34 L24 30 L32 34" stroke="white" strokeWidth="2" fill="none" opacity="0.4" />
          </svg>
          Network Monitor
        </h1>
        
        <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
          {/* Theme Toggle */}
          <ThemeToggle />
          
          {/* Time Range Selector */}
          <div>
            <label style={{ marginRight: '8px', fontSize: '14px', color: 'var(--text-secondary)' }}>
              Range:
            </label>
            <select 
              value={timeRange} 
              onChange={(e) => handleTimeRangeChange(e.target.value)}
              style={{
                padding: '6px 10px',
                borderRadius: '4px',
                border: '1px solid var(--input-border)',
                backgroundColor: 'var(--input-bg)',
                color: 'var(--text-primary)',
                fontSize: '14px'
              }}
            >
              <option value="1h">1 hour</option>
              <option value="6h">6 hours</option>
              <option value="12h">12 hours</option>
              <option value="1d">1 day</option>
              <option value="3d">3 days</option>
              <option value="1w">1 week</option>
            </select>
          </div>

          {/* Status Indicator */}
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '8px',
            fontSize: '14px',
            color: 'var(--text-secondary)'
          }}>
            <div style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              backgroundColor: getStatusColor(),
              boxShadow: !error && !loading ? `0 0 6px ${getStatusColor()}` : 'none'
            }}></div>
            <span>{getStatusText()}</span>
          </div>
        </div>
      </div>

      {/* Timezone Info */}
      <div className="timezone-info" style={{
        fontSize: '12px',
        color: 'var(--text-secondary)',
        marginBottom: '20px',
        textAlign: 'center',
        padding: '8px',
        backgroundColor: 'var(--bg-secondary)',
        borderRadius: '4px',
        border: '1px solid var(--border-color)'
      }}>
        Displaying data in your timezone: <strong>{apiService.getUserTimezone()}</strong>
        {lastUpdate && !error && (
          <span style={{ marginLeft: '20px' }}>
            Last updated: {apiService.formatTimestamp(lastUpdate, 'MMM dd, HH:mm:ss')}
          </span>
        )}
      </div>

      {/* Main Content */}
      {loading && servers.length === 0 && (
        <LoadingSpinner message="Loading vnstat data..." />
      )}

      {error && servers.length === 0 && (
        <ErrorDisplay 
          error={error}
          onRetry={handleRetry}
          title="Failed to Load Dashboard"
        />
      )}

      {!loading && servers.length === 0 && !error && (
        <div className="card">
          <div style={{
            textAlign: 'center',
            padding: '40px',
            color: '#666'
          }}>
            <h3>No Server Data Available</h3>
            <p>No servers are currently reporting vnstat data.</p>
            <button 
              onClick={handleRetry}
              style={{
                padding: '10px 20px',
                backgroundColor: '#2196f3',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
                marginTop: '10px'
              }}
            >
              Refresh Data
            </button>
          </div>
        </div>
      )}

      {servers.length > 0 && (
        <>
          {/* Real-time Chart */}
          <RealtimeChart 
            servers={servers} 
            refreshTrigger={refreshTrigger}
          />

          {/* Combined Chart */}
          <CombinedChart 
            servers={servers} 
            refreshTrigger={refreshTrigger}
          />

          {/* Server Stats Summary */}
          <div className="card" style={{ marginTop: '20px' }}>
            <h3 style={{ marginTop: '0' }}>Network Summary</h3>
            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: '20px',
              marginTop: '15px'
            }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '5px' }}>
                  Total Servers
                </div>
                <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#333' }}>
                  {servers.length}
                </div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '5px' }}>
                  Online Servers
                </div>
                <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#4caf50' }}>
                  {servers.filter(s => {
                    const now = new Date();
                    const lastUpdate = new Date(s.latest_time);
                    const diffMinutes = Math.floor((now - lastUpdate) / (1000 * 60));
                    return diffMinutes <= 15;
                  }).length}
                </div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '5px' }}>
                  Total Inbound
                </div>
                <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#4caf50' }}>
                  {aggregate.total_rx ? (aggregate.total_rx / 1024).toFixed(2) + ' MiB/s' : '0 KiB/s'}
                </div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: '12px', color: '#666', marginBottom: '5px' }}>
                  Total Outbound
                </div>
                <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#2196f3' }}>
                  {aggregate.total_tx ? (aggregate.total_tx / 1024).toFixed(2) + ' MiB/s' : '0 KiB/s'}
                </div>
              </div>
            </div>
          </div>

          {/* Individual Server Cards */}
          <div style={{ marginTop: '30px' }}>
            <h2 style={{ marginBottom: '20px', color: '#333' }}>
              Individual Server Stats
            </h2>
            <div className="server-grid">
              {servers.map((server, index) => (
                <ServerCard 
                  key={`${server.server_name}-${index}`}
                  server={server}
                  refreshTrigger={refreshTrigger}
                />
              ))}
            </div>
          </div>
        </>
      )}

      {/* Version Footer */}
      <VersionFooter />
    </div>
  );
}

export default App;
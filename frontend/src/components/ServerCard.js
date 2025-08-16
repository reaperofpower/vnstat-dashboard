import React, { useState, useEffect, useCallback } from 'react';
import { Line } from 'react-chartjs-2';
import { apiService } from '../services/apiService';
import { formatKiB, getTimeDifference, getValueAndUnit, calculateUptime } from '../utils/formatUtils';
import { aggregateDataByTime, getBackendTimeRange, getBackendLimit } from '../utils/dataAggregation';

const ServerCard = ({ server, refreshTrigger }) => {
  const [chartData, setChartData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [showChart, setShowChart] = useState(false);
  const [timeRange, setTimeRange] = useState('1h');

  const fetchServerHistory = useCallback(async () => {
    if (!showChart || !server?.server_name) return;

    try {
      setLoading(true);
      setError(null);

      // Get backend parameters for more data points
      const backendTimeRange = getBackendTimeRange(timeRange);
      const backendLimit = getBackendLimit(timeRange);

      const historyData = await apiService.getServerHistory(server.server_name, backendTimeRange, backendLimit, false);
      
      if (historyData && Array.isArray(historyData) && historyData.length > 0) {
        // Aggregate data using time-based averaging
        const aggregatedData = aggregateDataByTime(historyData, timeRange);

        if (aggregatedData.length > 0) {
          // Convert KiB/s to Mbps (megabits per second)
          // Data from vnstat is in KiB/s (kibibytes per second)
          // 1 KiB/s = 1024 bytes/s = 1024 * 8 bits/s = 8192 bits/s
          // 1 Mbps = 1,000,000 bits/s
          const kibToMbps = (kibPerSecond) => (kibPerSecond * 8192) / 1000000;

          const chartData = {
            labels: aggregatedData.map(point => new Date(point.timestamp)),
            datasets: [
              {
                label: 'RX (Mbps)',
                data: aggregatedData.map(point => kibToMbps(point.rx_rate || 0).toFixed(2)),
                borderColor: '#4caf50',
                backgroundColor: 'rgba(76, 175, 80, 0.1)',
                fill: false,
                tension: 0.2,
                pointRadius: 1,
                pointHoverRadius: 3
              },
              {
                label: 'TX (Mbps)',
                data: aggregatedData.map(point => kibToMbps(point.tx_rate || 0).toFixed(2)),
                borderColor: '#2196f3',
                backgroundColor: 'rgba(33, 150, 243, 0.1)',
                fill: false,
                tension: 0.2,
                pointRadius: 1,
                pointHoverRadius: 3
              }
            ]
          };

          setChartData(chartData);
        } else {
          setChartData(null);
        }
      } else {
        setChartData(null);
      }
    } catch (err) {
      console.error(`Failed to fetch history for ${server.server_name}:`, err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [server?.server_name, timeRange, showChart]);

  useEffect(() => {
    if (showChart) {
      fetchServerHistory();
    }
  }, [fetchServerHistory, refreshTrigger]);

  if (!server) {
    return null;
  }

  const timeStatus = getTimeDifference(server.latest_time);

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: true,
        position: 'top'
      },
      tooltip: {
        callbacks: {
          afterLabel: function(context) {
            return `Time: ${apiService.formatTimestamp(chartData.labels[context.dataIndex], 'HH:mm:ss')}`;
          }
        }
      }
    },
    scales: {
      x: {
        type: 'time',
        time: {
          displayFormats: {
            minute: 'HH:mm'
          }
        },
        title: {
          display: true,
          text: `Time (${apiService.getUserTimezoneFast()})`
        }
      },
      y: {
        beginAtZero: true,
        title: {
          display: true,
          text: 'Throughput (Mbps)'
        },
        ticks: {
          callback: function(value) {
            return parseFloat(value).toFixed(1);
          }
        }
      }
    }
  };

  return (
    <div className="card" style={{
      border: `2px solid ${timeStatus.status === 'offline' ? '#f44336' : 
                           timeStatus.status === 'warning' ? '#ff9800' : '#4caf50'}`,
      backgroundColor: timeStatus.status === 'offline' ? '#ffebee' : 'white'
    }}>
      {/* Server Header */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        marginBottom: '15px' 
      }}>
        <h3 style={{ 
          margin: '0', 
          fontSize: '18px',
          color: timeStatus.status === 'offline' ? '#c62828' : '#333'
        }}>
          {server.server_name}
        </h3>
        <div style={{
          width: '12px',
          height: '12px',
          borderRadius: '50%',
          backgroundColor: timeStatus.color,
          boxShadow: timeStatus.status === 'online' ? `0 0 8px ${timeStatus.color}` : 'none'
        }}></div>
      </div>

      {/* Current Statistics */}
      <div style={{ marginBottom: '15px' }}>
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: '1fr 1fr', 
          gap: '10px',
          marginBottom: '10px'
        }}>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '2px' }}>
              Inbound (RX)
            </div>
            <div style={{ 
              fontSize: '16px', 
              fontWeight: 'bold',
              color: '#4caf50'
            }}>
              {formatKiB(server.rx_rate)}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '12px', color: '#666', marginBottom: '2px' }}>
              Outbound (TX)
            </div>
            <div style={{ 
              fontSize: '16px', 
              fontWeight: 'bold',
              color: '#2196f3'
            }}>
              {formatKiB(server.tx_rate)}
            </div>
          </div>
        </div>

        {/* Uptime */}
        <div style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>
          {server.data_points ? calculateUptime(server.data_points, '1d').text : 'Uptime: N/A'}
        </div>
      </div>

      {/* Status */}
      <div style={{ 
        fontSize: '12px',
        color: timeStatus.color,
        fontWeight: timeStatus.status === 'offline' ? 'bold' : 'normal',
        textAlign: 'center',
        marginBottom: '15px',
        padding: '5px',
        backgroundColor: timeStatus.status === 'offline' ? 'rgba(244, 67, 54, 0.1)' : 
                         timeStatus.status === 'warning' ? 'rgba(255, 152, 0, 0.1)' : 
                         'rgba(76, 175, 80, 0.1)',
        borderRadius: '4px'
      }}>
        {timeStatus.text}
        {server.latest_time_formatted && (
          <div style={{ marginTop: '2px', fontSize: '11px' }}>
            Last update: {server.latest_time_formatted}
          </div>
        )}
      </div>

      {/* Chart Toggle */}
      <div style={{ textAlign: 'center', marginBottom: showChart ? '15px' : '0' }}>
        <button
          onClick={() => setShowChart(!showChart)}
          style={{
            padding: '6px 12px',
            backgroundColor: showChart ? '#f44336' : '#2196f3',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '12px',
            marginRight: showChart ? '10px' : '0'
          }}
        >
          {showChart ? 'Hide Chart' : 'Show Chart'}
        </button>
        
        {showChart && (
          <select 
            value={timeRange} 
            onChange={(e) => setTimeRange(e.target.value)}
            style={{
              padding: '4px 8px',
              borderRadius: '4px',
              border: '1px solid #ccc',
              fontSize: '12px'
            }}
          >
            <option value="1h">1h</option>
            <option value="6h">6h</option>
            <option value="12h">12h</option>
            <option value="1d">1d</option>
            <option value="3d">3d</option>
            <option value="1w">1w</option>
          </select>
        )}
      </div>

      {/* Chart */}
      {showChart && (
        <div>
          {loading && (
            <div style={{ 
              height: '200px', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              color: '#666',
              fontSize: '14px'
            }}>
              Loading chart...
            </div>
          )}

          {error && (
            <div style={{ 
              height: '200px', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              flexDirection: 'column',
              color: '#f44336',
              fontSize: '14px'
            }}>
              <div>Chart Error: {error}</div>
              <button
                onClick={fetchServerHistory}
                style={{
                  marginTop: '10px',
                  padding: '4px 8px',
                  backgroundColor: '#2196f3',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '12px'
                }}
              >
                Retry
              </button>
            </div>
          )}

          {!loading && !error && chartData && (
            <div style={{ height: '200px' }}>
              <Line data={chartData} options={chartOptions} />
            </div>
          )}

          {!loading && !error && !chartData && (
            <div style={{ 
              height: '200px', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              color: '#666',
              fontSize: '14px'
            }}>
              No historical data available
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ServerCard;
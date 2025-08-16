import React, { useEffect, useState, useCallback } from 'react';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
} from 'chart.js';
import 'chartjs-adapter-date-fns';
import { apiService } from '../services/apiService';
import { getValueAndUnit } from '../utils/formatUtils';
import { aggregateCombinedServerData, getBackendTimeRange, getBackendLimit } from '../utils/dataAggregation';
import { getRandomRefreshInterval } from '../utils/browserCache';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
);

const CombinedChart = ({ servers, refreshTrigger }) => {
  const [chartData, setChartData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [timeRange, setTimeRange] = useState('1h');

  const fetchCombinedData = useCallback(async () => {
    if (!servers || servers.length === 0) {
      setChartData(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Get backend parameters for more data points
      const backendTimeRange = getBackendTimeRange(timeRange);
      const backendLimit = getBackendLimit(timeRange);

      // Fetch historical data for all servers with increased limits
      const historyPromises = servers.map(server =>
        apiService.getServerHistory(server.server_name, backendTimeRange, backendLimit, false)
      );

      const allHistoryResults = await Promise.allSettled(historyPromises);

      // Extract successful results
      const allServerData = allHistoryResults
        .filter(result => result.status === 'fulfilled' && result.value)
        .map(result => result.value);

      if (allServerData.length === 0) {
        setChartData(null);
        setLoading(false);
        return;
      }

      // Aggregate data using time-based averaging
      const aggregatedData = aggregateCombinedServerData(allServerData, timeRange);

      if (aggregatedData.length === 0) {
        setChartData(null);
        setLoading(false);
        return;
      }

      // Convert KiB/s to Mbps (megabits per second)
      // Data from vnstat is in KiB/s (kibibytes per second)
      // 1 KiB/s = 1024 bytes/s = 1024 * 8 bits/s = 8192 bits/s
      // 1 Mbps = 1,000,000 bits/s
      const kibToMbps = (kibPerSecond) => (kibPerSecond * 8192) / 1000000;

      // Prepare chart data
      const chartData = {
        labels: aggregatedData.map(point => new Date(point.timestamp)),
        datasets: [
          {
            label: 'Total Inbound (Mbps)',
            data: aggregatedData.map(point => kibToMbps(point.total_rx || 0).toFixed(2)),
            borderColor: '#4caf50',
            backgroundColor: 'rgba(76, 175, 80, 0.1)',
            fill: false,
            tension: 0.2,
            pointRadius: 2,
            pointHoverRadius: 4
          },
          {
            label: 'Total Outbound (Mbps)',
            data: aggregatedData.map(point => kibToMbps(point.total_tx || 0).toFixed(2)),
            borderColor: '#2196f3',
            backgroundColor: 'rgba(33, 150, 243, 0.1)',
            fill: false,
            tension: 0.2,
            pointRadius: 2,
            pointHoverRadius: 4
          }
        ]
      };

      setChartData(chartData);
    } catch (err) {
      console.error('Failed to fetch combined chart data:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [servers, timeRange]);

  useEffect(() => {
    fetchCombinedData();
  }, [fetchCombinedData, refreshTrigger]);

  // Separate useEffect for randomized auto-refresh
  useEffect(() => {
    const setupRandomRefresh = () => {
      const randomInterval = getRandomRefreshInterval();
      console.log(`Combined chart next refresh in ${Math.round(randomInterval/1000)} seconds`);
      
      return setTimeout(() => {
        if (!loading) {
          console.log('Performing combined chart scheduled refresh');
          fetchCombinedData();
        }
        // Schedule next random refresh
        const nextIntervalId = setupRandomRefresh();
        return nextIntervalId;
      }, randomInterval);
    };

    const intervalId = setupRandomRefresh();
    return () => clearTimeout(intervalId);
  }, [fetchCombinedData, loading]);

  const getTimeDisplayFormat = (range) => {
    switch (range) {
      case '1h':
        return { minute: 'HH:mm', hour: 'HH:mm' };
      case '6h':
      case '12h':
        return { hour: 'HH:mm', day: 'MMM dd' };
      case '1d':
        return { hour: 'HH:mm', day: 'MMM dd' };
      case '3d':
      case '1w':
        return { hour: 'MMM dd HH:mm', day: 'MMM dd' };
      default:
        return { minute: 'HH:mm', hour: 'HH:mm' };
    }
  };

  const getDataPointDescription = (range) => {
    switch (range) {
      case '1h': return '60 points (1-minute averages)';
      case '6h': return '60 points (6-minute averages)';
      case '12h': return '60 points (12-minute averages)';
      case '1d': return '60 points (24-minute averages)';
      case '3d': return '60 points (~1.2-hour averages)';
      case '1w': return '60 points (~2.8-hour averages)';
      default: return '60 points (averaged)';
    }
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      title: {
        display: true,
        text: `Combined Network Throughput - ${servers?.length || 0} servers (${getDataPointDescription(timeRange)})`
      },
      legend: {
        position: 'top'
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            const label = context.dataset.label || '';
            const value = parseFloat(context.parsed.y).toFixed(2);
            return `${label}: ${value}`;
          },
          afterLabel: function(context) {
            const dataIndex = context.dataIndex;
            const aggregatedPoint = chartData?.labels ? chartData.labels[dataIndex] : null;
            if (aggregatedPoint) {
              return `Time: ${apiService.formatTimestamp(aggregatedPoint, 'MMM dd, HH:mm:ss')}`;
            }
            return '';
          }
        }
      }
    },
    scales: {
      x: {
        type: 'time',
        time: {
          displayFormats: getTimeDisplayFormat(timeRange)
        },
        title: {
          display: true,
          text: `Time (${apiService.getUserTimezone()})`
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
    },
    interaction: {
      intersect: false,
      mode: 'index'
    }
  };

  const handleTimeRangeChange = (newRange) => {
    setTimeRange(newRange);
  };

  if (loading) {
    return (
      <div className="card">
        <div className="loading">
          <div>Loading combined throughput chart...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="card">
        <div className="error">
          <h3>Chart Error</h3>
          <p>{error}</p>
          <button onClick={fetchCombinedData} style={{
            padding: '8px 16px',
            backgroundColor: '#2196f3',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            marginTop: '10px'
          }}>
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (!chartData || !servers || servers.length === 0) {
    return (
      <div className="card">
        <h2>Combined Network Throughput</h2>
        <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
          No server data available for chart
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>Combined Network Throughput</h2>
        <div>
          <label style={{ marginRight: '10px' }}>Time Range:</label>
          <select 
            value={timeRange} 
            onChange={(e) => handleTimeRangeChange(e.target.value)}
            style={{
              padding: '5px 10px',
              borderRadius: '4px',
              border: '1px solid #ccc'
            }}
          >
            <option value="1h">1 Hour</option>
            <option value="6h">6 Hours</option>
            <option value="12h">12 Hours</option>
            <option value="1d">1 Day</option>
            <option value="3d">3 Days</option>
            <option value="1w">1 Week</option>
          </select>
        </div>
      </div>
      
      <div style={{ height: '400px' }}>
        <Line data={chartData} options={chartOptions} />
      </div>
      
      <div style={{ 
        marginTop: '15px', 
        fontSize: '12px', 
        color: '#666', 
        textAlign: 'center' 
      }}>
        Displaying data in your local timezone: {apiService.getUserTimezone()}<br/>
        Data points are averaged over time buckets • Chart updates every 50-70 seconds (randomized)
      </div>
    </div>
  );
};

export default CombinedChart;
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
import { addSeconds, subMinutes } from 'date-fns';
import { useTheme } from '../contexts/ThemeContext';
import { mergeChartOptions } from '../utils/chartTheme';

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

const RealtimeChart = ({ servers, refreshTrigger }) => {
  const [chartData, setChartData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const { isDarkMode } = useTheme();

  // Generate colors for each server
  const getServerColor = (index) => {
    const colors = [
      '#ff6b6b', '#4ecdc4', '#45b7d1', '#96ceb4', '#ffeaa7',
      '#dda0dd', '#98d8c8', '#f7dc6f', '#bb8fce', '#85c1e9',
      '#f8c471', '#82e0aa', '#f1948a', '#85c1e9', '#d7bde2'
    ];
    return colors[index % colors.length];
  };

  // Aggregate data into 30-second buckets with timezone normalization
  const aggregateRealtimeData = useCallback((rawData) => {
    if (!rawData || !Array.isArray(rawData) || rawData.length === 0) {
      return [];
    }

    // Use normalized current time for consistent bucketing across timezones
    const now = apiService.normalizeTimestamp(new Date());
    const startTime = subMinutes(now, 15); // 15 minutes ago
    const buckets = new Map();

    // Create 30-second buckets for the last 15 minutes using normalized time
    for (let i = 0; i < 30; i++) {
      const bucketTime = addSeconds(startTime, i * 30);
      const bucketKey = Math.floor(bucketTime.getTime() / 30000) * 30000; // Round to 30-second intervals
      buckets.set(bucketKey, {
        timestamp: new Date(bucketKey),
        rx_values: [],
        tx_values: [],
        count: 0
      });
    }

    // Group data points into buckets using normalized timestamps
    rawData.forEach(point => {
      if (!point.timestamp || (!point.rx_rate && point.rx_rate !== 0) || (!point.tx_rate && point.tx_rate !== 0)) {
        return;
      }

      // Normalize the point timestamp to user's timezone
      const pointTime = apiService.normalizeTimestamp(point.timestamp);
      
      // Debug: Log original vs normalized time for first few points
      if (Math.random() < 0.01) { // Only log 1% of points to avoid spam
        console.log(`Timezone normalization - Original: ${point.timestamp}, Normalized: ${pointTime}`);
      }
      
      // Filter to last 15 minutes only
      if (pointTime < startTime) {
        return;
      }

      // Use normalized time for consistent bucketing
      const bucketKey = Math.floor(pointTime.getTime() / 30000) * 30000;
      const bucket = buckets.get(bucketKey);
      
      if (bucket) {
        bucket.rx_values.push(Number(point.rx_rate) || 0);
        bucket.tx_values.push(Number(point.tx_rate) || 0);
        bucket.count++;
      }
    });

    // Calculate averages for each bucket and sum RX + TX for total throughput
    const aggregatedData = Array.from(buckets.values())
      .map(bucket => {
        const avgRx = bucket.rx_values.length > 0 
          ? bucket.rx_values.reduce((sum, val) => sum + val, 0) / bucket.rx_values.length 
          : 0;
        const avgTx = bucket.tx_values.length > 0 
          ? bucket.tx_values.reduce((sum, val) => sum + val, 0) / bucket.tx_values.length 
          : 0;
        
        return {
          timestamp: bucket.timestamp,
          total_throughput: avgRx + avgTx, // Sum RX + TX for total throughput
          data_points: bucket.count
        };
      })
      .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    return aggregatedData;
  }, []);

  const fetchRealtimeData = useCallback(async () => {
    if (!servers || servers.length === 0) {
      setChartData(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Fetch last 20 minutes of data with high frequency for each server
      const historyPromises = servers.map(server =>
        apiService.getServerHistory(server.server_name, '20m', 240, false)
      );

      const allHistoryResults = await Promise.allSettled(historyPromises);

      // Extract successful results
      const allServerData = allHistoryResults
        .map((result, index) => ({
          serverName: servers[index].server_name,
          data: result.status === 'fulfilled' && result.value ? result.value : []
        }))
        .filter(server => server.data.length > 0);

      if (allServerData.length === 0) {
        setChartData(null);
        setLoading(false);
        return;
      }

      // Convert KiB/s to Mbps
      const kibToMbps = (kibPerSecond) => (kibPerSecond * 8192) / 1000000;

      // Process each server's data
      const datasets = [];
      
      allServerData.forEach((serverData, index) => {
        const aggregatedData = aggregateRealtimeData(serverData.data);
        const color = getServerColor(index);

        // Total throughput dataset (RX + TX combined)
        datasets.push({
          label: `${serverData.serverName} Total (Mbps)`,
          data: aggregatedData.map(point => ({
            x: point.timestamp,
            y: kibToMbps(point.total_throughput || 0).toFixed(3)
          })),
          borderColor: color,
          backgroundColor: color + '20',
          fill: false,
          tension: 0.3,
          pointRadius: 1,
          pointHoverRadius: 3,
          borderWidth: 2
        });
      });

      setChartData({ datasets });
    } catch (err) {
      console.error('Failed to fetch realtime chart data:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [servers, aggregateRealtimeData]);

  useEffect(() => {
    fetchRealtimeData();
  }, [fetchRealtimeData, refreshTrigger]);

  // Auto-refresh every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      console.log('Performing realtime chart refresh');
      fetchRealtimeData();
    }, 30000); // 30 seconds

    return () => clearInterval(interval);
  }, [fetchRealtimeData]);

  const baseChartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      title: {
        display: true,
        text: `Real-time Total Throughput - Last 15 Minutes (Timezone Normalized)`
      },
      legend: {
        position: 'top',
        labels: {
          boxWidth: 12,
          font: {
            size: 10
          }
        }
      },
      tooltip: {
        callbacks: {
          label: function(context) {
            const label = context.dataset.label || '';
            const value = parseFloat(context.parsed.y).toFixed(3);
            return `${label}: ${value}`;
          },
          afterLabel: function(context) {
            return `Time: ${apiService.formatTimestamp(context.parsed.x, 'HH:mm:ss')}`;
          }
        }
      }
    },
    scales: {
      x: {
        type: 'time',
        time: {
          displayFormats: {
            minute: 'HH:mm',
            second: 'HH:mm:ss'
          },
          unit: 'minute'
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
            return parseFloat(value).toFixed(2);
          }
        }
      }
    },
    interaction: {
      intersect: false,
      mode: 'index'
    }
  };

  const chartOptions = mergeChartOptions(baseChartOptions, isDarkMode);

  if (loading) {
    return (
      <div className="card">
        <div className="loading">
          <div>Loading real-time chart...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="card">
        <div className="error">
          <h3>Real-time Chart Error</h3>
          <p>{error}</p>
          <button onClick={fetchRealtimeData} style={{
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
        <h2>Real-time Total Throughput</h2>
        <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
          No server data available for real-time chart
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <div style={{ height: '350px' }}>
        <Line data={chartData} options={chartOptions} />
      </div>
      
      <div style={{ 
        marginTop: '15px', 
        fontSize: '11px', 
        color: '#666', 
        textAlign: 'center' 
      }}>
        Real-time view • 30-second intervals • Auto-refreshes every 30 seconds<br/>
        Shows total throughput (RX + TX combined) per server
      </div>
    </div>
  );
};

export default RealtimeChart;
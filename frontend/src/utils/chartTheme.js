// Chart.js theme configuration for light/dark mode
export const getChartTheme = (isDarkMode) => {
  return {
    plugins: {
      legend: {
        labels: {
          color: isDarkMode ? '#ffffff' : '#333333'
        }
      },
      title: {
        color: isDarkMode ? '#ffffff' : '#333333'
      },
      tooltip: {
        backgroundColor: isDarkMode ? '#2a2a2a' : '#ffffff',
        titleColor: isDarkMode ? '#ffffff' : '#333333',
        bodyColor: isDarkMode ? '#b3b3b3' : '#666666',
        borderColor: isDarkMode ? '#555555' : '#cccccc',
        borderWidth: 1
      }
    },
    scales: {
      x: {
        grid: {
          color: isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'
        },
        ticks: {
          color: isDarkMode ? '#b3b3b3' : '#666666'
        },
        title: {
          color: isDarkMode ? '#ffffff' : '#333333'
        }
      },
      y: {
        grid: {
          color: isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)'
        },
        ticks: {
          color: isDarkMode ? '#b3b3b3' : '#666666'
        },
        title: {
          color: isDarkMode ? '#ffffff' : '#333333'
        }
      }
    }
  };
};

// Merge chart options with theme
export const mergeChartOptions = (baseOptions, isDarkMode) => {
  const themeOptions = getChartTheme(isDarkMode);
  
  return {
    ...baseOptions,
    plugins: {
      ...baseOptions.plugins,
      ...themeOptions.plugins,
      legend: {
        ...baseOptions.plugins?.legend,
        ...themeOptions.plugins.legend
      },
      title: {
        ...baseOptions.plugins?.title,
        ...themeOptions.plugins.title
      },
      tooltip: {
        ...baseOptions.plugins?.tooltip,
        ...themeOptions.plugins.tooltip
      }
    },
    scales: {
      ...baseOptions.scales,
      x: {
        ...baseOptions.scales?.x,
        ...themeOptions.scales.x,
        grid: {
          ...baseOptions.scales?.x?.grid,
          ...themeOptions.scales.x.grid
        },
        ticks: {
          ...baseOptions.scales?.x?.ticks,
          ...themeOptions.scales.x.ticks
        },
        title: {
          ...baseOptions.scales?.x?.title,
          ...themeOptions.scales.x.title
        }
      },
      y: {
        ...baseOptions.scales?.y,
        ...themeOptions.scales.y,
        grid: {
          ...baseOptions.scales?.y?.grid,
          ...themeOptions.scales.y.grid
        },
        ticks: {
          ...baseOptions.scales?.y?.ticks,
          ...themeOptions.scales.y.ticks
        },
        title: {
          ...baseOptions.scales?.y?.title,
          ...themeOptions.scales.y.title
        }
      }
    }
  };
};
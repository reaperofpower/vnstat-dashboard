import React from 'react';

const ErrorDisplay = ({ error, onRetry, title = 'Error' }) => {
  return (
    <div className="error">
      <h3 style={{ margin: '0 0 10px 0', color: '#c62828' }}>
        {title}
      </h3>
      <p style={{ margin: '0 0 15px 0' }}>
        {error || 'An unexpected error occurred'}
      </p>
      {onRetry && (
        <button
          onClick={onRetry}
          style={{
            padding: '8px 16px',
            backgroundColor: '#2196f3',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          Try Again
        </button>
      )}
    </div>
  );
};

export default ErrorDisplay;
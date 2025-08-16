import React, { useState, useEffect } from 'react';
import { getFrontendVersion, getBuildTime, getBackendVersion, formatVersionInfo } from '../utils/version';

const VersionFooter = () => {
  const [versionInfo, setVersionInfo] = useState({
    frontend: getFrontendVersion(),
    backend: 'loading...',
    buildDate: new Date(getBuildTime()).toLocaleDateString(),
    fullInfo: ''
  });
  const [showDetails, setShowDetails] = useState(false);

  useEffect(() => {
    const fetchBackendVersion = async () => {
      const backendVersion = await getBackendVersion();
      const buildTime = getBuildTime();
      const info = formatVersionInfo(getFrontendVersion(), backendVersion, buildTime);
      setVersionInfo(info);
    };

    fetchBackendVersion();
  }, []);

  const handleVersionClick = () => {
    setShowDetails(!showDetails);
  };

  return (
    <div className="version-footer" style={{
      marginTop: '40px',
      padding: '20px',
      textAlign: 'center',
      fontSize: '12px',
      color: 'var(--text-tertiary)',
      borderTop: '1px solid var(--border-color)',
      backgroundColor: 'var(--bg-tertiary)'
    }}>
      <div style={{ marginBottom: '10px' }}>
        VnStat Dashboard - Real-time network monitoring with timezone normalization
      </div>
      
      <div 
        onClick={handleVersionClick}
        className="version-details"
        style={{
          cursor: 'pointer',
          padding: '5px 10px',
          borderRadius: '4px',
          backgroundColor: showDetails ? 'var(--bg-secondary)' : 'transparent',
          transition: 'background-color 0.2s',
          display: 'inline-block',
          border: showDetails ? '1px solid var(--border-light)' : 'none'
        }}
        title="Click to toggle version details"
      >
        {showDetails ? (
          <div style={{ lineHeight: '1.4' }}>
            <div><strong>Frontend:</strong> v{versionInfo.frontend}</div>
            <div><strong>Backend:</strong> v{versionInfo.backend}</div>
            <div><strong>Build Date:</strong> {versionInfo.buildDate}</div>
            <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '5px' }}>
              Click to minimize
            </div>
          </div>
        ) : (
          <div>
            <span>v{versionInfo.frontend}</span>
            {versionInfo.backend !== 'loading...' && versionInfo.backend !== 'unknown' && (
              <span> | Backend v{versionInfo.backend}</span>
            )}
            <span style={{ fontSize: '11px', marginLeft: '8px', color: 'var(--text-secondary)' }}>
              (click for details)
            </span>
          </div>
        )}
      </div>

      {versionInfo.backend === 'unknown' && (
        <div style={{ 
          fontSize: '11px', 
          color: 'var(--warning-color)', 
          marginTop: '5px',
          fontStyle: 'italic'
        }}>
          Backend version unavailable
        </div>
      )}
    </div>
  );
};

export default VersionFooter;
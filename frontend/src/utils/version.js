import packageJson from '../../package.json';

// Frontend version from package.json
export const getFrontendVersion = () => {
  return packageJson.version;
};

// Build time (set at build time)
export const getBuildTime = () => {
  // This will be set during build process
  return process.env.REACT_APP_BUILD_TIME || new Date().toISOString();
};

// Git commit hash (if available)
export const getGitCommit = () => {
  return process.env.REACT_APP_GIT_COMMIT || 'unknown';
};

// Get backend version from API
export const getBackendVersion = async () => {
  try {
    const API_URL = process.env.REACT_APP_API_URL || 'http://127.0.0.1:3000';
    const healthUrl = API_URL.replace('/api', '') + '/health';
    const response = await fetch(healthUrl);
    if (response.ok) {
      const data = await response.json();
      return data.version || 'unknown';
    }
  } catch (error) {
    console.warn('Could not fetch backend version:', error);
  }
  return 'unknown';
};

export const formatVersionInfo = (frontendVersion, backendVersion, buildTime) => {
  const buildDate = new Date(buildTime).toLocaleDateString();
  return {
    frontend: frontendVersion,
    backend: backendVersion,
    buildDate: buildDate,
    fullInfo: `Frontend: v${frontendVersion} | Backend: v${backendVersion} | Built: ${buildDate}`
  };
};
'use strict';
window.AF_RUNTIME = Object.freeze({
  mode: localStorage.getItem('af-runtime-mode') || 'auto',
  apiBaseUrl: (localStorage.getItem('af-api-base') || 'http://localhost:8080').replace(/\/$/, ''),
  requestTimeoutMs: 20000,
  pollIntervalMs: 1500,
  logPollIntervalMs: 1000,
  maxGetRetries: 2,
  productionBranch: 'autoforge-frontend-production',
  frontendVersion: '1.0.0-production',
  demoFallback: true,
  credentials: 'include'
});

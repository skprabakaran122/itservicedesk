module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'fixed-active.cjs',
    instances: 1,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: 'calpion-service-desk-secret-key-2025'
    }
  }]
};

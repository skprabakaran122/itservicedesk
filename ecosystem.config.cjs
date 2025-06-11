module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server/index.ts',
    interpreter: 'node',
    interpreter_args: '--import tsx',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://servicedesk_user:servicedesk123@localhost:5432/servicedesk',
      SESSION_SECRET: '866fc68cc92dbaa085d34f5b072cb5bc2e3a4758d810f0a9862f61d147fc64d1e0f303b5e780ce2eeabac9c1697ee0985145321d435b7749ed499ec0d310d753'
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 5,
    min_uptime: '10s'
  }]
};

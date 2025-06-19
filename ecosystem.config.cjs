// PM2 Production Configuration - CommonJS format
const config = {
  apps: [{
    name: 'servicedesk',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['node_modules', 'logs'],
    kill_timeout: 5000,
    wait_ready: false,
    listen_timeout: 10000
  }]
};

module.exports = config;
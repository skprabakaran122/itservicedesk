module.exports = {
  apps: [{
    name: 'servicedesk-dev',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'development',
      PORT: 5000,
      DATABASE_URL: process.env.DATABASE_URL
    },
    watch: ['server.js'],
    ignore_watch: ['node_modules', 'logs', 'dist', 'client'],
    watch_delay: 1000,
    error_file: './logs/dev-err.log',
    out_file: './logs/dev-out.log',
    log_file: './logs/dev-combined.log',
    time: true,
    max_memory_restart: '500M',
    restart_delay: 2000,
    kill_timeout: 3000,
    wait_ready: false,
    listen_timeout: 5000
  }]
};
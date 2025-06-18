module.exports = {
  apps: [{
    name: 'itservicedesk',
    script: 'dist/production.cjs',
    instances: 1,
    exec_mode: 'fork',
    cwd: '/var/www/itservicedesk',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      DATABASE_URL: 'postgresql://ubuntu:password@localhost:5432/servicedesk'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['node_modules', 'logs', 'dist'],
    kill_timeout: 5000,
    wait_ready: false,
    listen_timeout: 10000
  }]
};
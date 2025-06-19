module.exports = {
  apps: [{
    name: 'servicedesk',
    script: 'server-production.cjs',
    cwd: '/var/www/itservicedesk',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/app.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    watch: false,
    kill_timeout: 5000
  }]
};

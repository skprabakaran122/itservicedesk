const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Ensure logs directory exists
const logsDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

const scripts = {
  // Development scripts
  'dev:pm2': () => {
    console.log('Starting development server with PM2...');
    try {
      execSync('pm2 start ecosystem.dev.config.js', { stdio: 'inherit' });
    } catch (error) {
      console.error('PM2 start failed, falling back to direct node execution');
      execSync('node server.js', { stdio: 'inherit' });
    }
  },

  'dev:stop': () => {
    console.log('Stopping development PM2 processes...');
    try {
      execSync('pm2 delete ecosystem.dev.config.js', { stdio: 'inherit' });
    } catch (error) {
      console.log('No PM2 processes to stop');
    }
  },

  'dev:restart': () => {
    console.log('Restarting development server...');
    scripts['dev:stop']();
    setTimeout(() => scripts['dev:pm2'](), 1000);
  },

  'dev:logs': () => {
    console.log('Showing development logs...');
    try {
      execSync('pm2 logs servicedesk-dev', { stdio: 'inherit' });
    } catch (error) {
      console.log('No PM2 logs available');
    }
  },

  // Production scripts
  'prod:pm2': () => {
    console.log('Starting production server with PM2...');
    try {
      execSync('pm2 start ecosystem.config.js', { stdio: 'inherit' });
    } catch (error) {
      console.error('PM2 start failed:', error.message);
    }
  },

  'prod:stop': () => {
    console.log('Stopping production PM2 processes...');
    try {
      execSync('pm2 delete ecosystem.config.js', { stdio: 'inherit' });
    } catch (error) {
      console.log('No PM2 processes to stop');
    }
  },

  'prod:restart': () => {
    console.log('Restarting production server...');
    scripts['prod:stop']();
    setTimeout(() => scripts['prod:pm2'](), 1000);
  },

  // Database scripts
  'db:setup': () => {
    console.log('Setting up database...');
    try {
      execSync('bash init-dev-environment.sh', { stdio: 'inherit' });
    } catch (error) {
      console.error('Database setup failed:', error.message);
    }
  },

  // Deployment scripts
  'deploy:ubuntu': () => {
    console.log('Deploying to Ubuntu server...');
    try {
      execSync('bash deploy-ubuntu-compatible.sh', { stdio: 'inherit' });
    } catch (error) {
      console.error('Ubuntu deployment failed:', error.message);
    }
  },

  'deploy:clean': () => {
    console.log('Clean deployment...');
    try {
      execSync('bash clean-build.sh', { stdio: 'inherit' });
    } catch (error) {
      console.error('Clean deployment failed:', error.message);
    }
  },

  // Status and monitoring
  'status': () => {
    console.log('Checking PM2 status...');
    try {
      execSync('pm2 status', { stdio: 'inherit' });
    } catch (error) {
      console.log('PM2 not running or not installed');
    }
  },

  'health': () => {
    console.log('Checking application health...');
    try {
      const response = execSync('curl -s http://localhost:5000/api/health', { encoding: 'utf8' });
      console.log('Health check response:', response);
    } catch (error) {
      console.log('Application not responding on port 5000');
    }
  }
};

// Execute script based on command line argument
const scriptName = process.argv[2];
if (scripts[scriptName]) {
  scripts[scriptName]();
} else {
  console.log('Available scripts:');
  Object.keys(scripts).forEach(name => {
    console.log(`  npm run script ${name}`);
  });
}

module.exports = scripts;
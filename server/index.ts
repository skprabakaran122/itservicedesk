import express, { type Request, Response, NextFunction } from "express";
import https from "https";
import http from "http";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { registerRoutes } from "./routes";
import { setupVite, serveStatic, log } from "./vite";
import { storage } from "./storage";

// Load environment variables from .env file
dotenv.config();

// SSL Certificate configuration
function getSSLCredentials() {
  try {
    // Try to load SSL certificates from various possible locations
    const certPaths = [
      // Let's Encrypt paths
      '/etc/letsencrypt/live/domain/fullchain.pem',
      '/etc/letsencrypt/live/domain/privkey.pem',
      // Custom certificate paths
      './ssl/cert.pem',
      './ssl/key.pem',
      // Environment variable paths
      process.env.SSL_CERT_PATH,
      process.env.SSL_KEY_PATH
    ].filter(Boolean);

    if (process.env.SSL_CERT && process.env.SSL_KEY) {
      return {
        cert: process.env.SSL_CERT,
        key: process.env.SSL_KEY
      };
    }

    // Try to read from files
    if (fs.existsSync('./ssl/cert.pem') && fs.existsSync('./ssl/key.pem')) {
      return {
        cert: fs.readFileSync('./ssl/cert.pem', 'utf8'),
        key: fs.readFileSync('./ssl/key.pem', 'utf8')
      };
    }

    return null;
  } catch (error) {
    log(`[SSL] Error loading SSL certificates: ${error}`);
    return null;
  }
}

// Create self-signed certificate for development
function createSelfSignedCert() {
  const forge = require('node-forge');
  const pki = forge.pki;

  // Generate key pair
  const keys = pki.rsa.generateKeyPair(2048);

  // Create certificate
  const cert = pki.createCertificate();
  cert.publicKey = keys.publicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = new Date();
  cert.validity.notAfter = new Date();
  cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);

  const attrs = [{
    name: 'commonName',
    value: 'localhost'
  }, {
    name: 'organizationName',
    value: 'Calpion IT Service Desk'
  }];

  cert.setSubject(attrs);
  cert.setIssuer(attrs);
  cert.sign(keys.privateKey);

  return {
    cert: pki.certificateToPem(cert),
    key: pki.privateKeyToPem(keys.privateKey)
  };
}

const app = express();

// Force HTTPS in production
app.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && !req.secure && req.get('x-forwarded-proto') !== 'https') {
    return res.redirect(301, `https://${req.get('host')}${req.url}`);
  }
  next();
});

// Security headers for HTTPS
app.use((req, res, next) => {
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

app.use(express.json({ limit: '50mb' })); // Increase JSON payload limit for file uploads
app.use(express.urlencoded({ extended: false, limit: '50mb' }));

app.use((req, res, next) => {
  const start = Date.now();
  const path = req.path;
  let capturedJsonResponse: Record<string, any> | undefined = undefined;

  const originalResJson = res.json;
  res.json = function (bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };

  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path.startsWith("/api")) {
      let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }

      if (logLine.length > 80) {
        logLine = logLine.slice(0, 79) + "…";
      }

      log(logLine);
    }
  });

  next();
});

// Monthly SLA Metrics Refresh Scheduler
function startSLAScheduler() {
  const scheduleNextRefresh = () => {
    const now = new Date();
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0);
    const timeUntilNextMonth = nextMonth.getTime() - now.getTime();
    
    log(`[SLA] Next SLA refresh scheduled for ${nextMonth.toISOString()}`);
    
    setTimeout(async () => {
      try {
        await storage.refreshSLAMetrics();
        log('[SLA] Monthly SLA metrics refresh completed');
      } catch (error) {
        log(`[SLA] Error during monthly refresh: ${error}`);
      }
      // Schedule the next refresh
      scheduleNextRefresh();
    }, timeUntilNextMonth);
  };
  
  scheduleNextRefresh();
}

// Auto-close resolved tickets after 3 days
function startAutoCloseScheduler() {
  const runAutoClose = async () => {
    try {
      const result = await storage.autoCloseResolvedTickets();
      if (result.closedCount > 0) {
        log(`[AUTO-CLOSE] Automatically closed ${result.closedCount} resolved tickets older than 3 days`);
      }
    } catch (error) {
      log(`[AUTO-CLOSE] Error during auto-close process: ${error}`);
    }
  };

  // Run immediately on startup
  runAutoClose();
  
  // Run daily at 2 AM
  const scheduleDaily = () => {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(2, 0, 0, 0); // 2 AM
    
    const timeUntilTomorrow = tomorrow.getTime() - now.getTime();
    
    setTimeout(async () => {
      await runAutoClose();
      // Schedule the next run
      scheduleDaily();
    }, timeUntilTomorrow);
  };
  
  scheduleDaily();
}

// Overdue change monitoring scheduler
function startOverdueChangeScheduler() {
  const runOverdueCheck = async () => {
    try {
      const result = await storage.sendOverdueNotifications();
      if (result.notificationCount > 0) {
        log(`[OVERDUE] Sent ${result.notificationCount} overdue notifications for ${result.changes.length} changes`);
      }
    } catch (error) {
      log(`[OVERDUE] Error during overdue check process: ${error}`);
    }
  };

  // Run immediately on startup
  runOverdueCheck();
  
  // Run every hour to check for overdue changes
  const scheduleHourly = () => {
    setTimeout(async () => {
      await runOverdueCheck();
      // Schedule the next run
      scheduleHourly();
    }, 60 * 60 * 1000); // 1 hour
  };
  
  scheduleHourly();
}

(async () => {
  try {
    // Initialize storage data once at startup
    await storage.initializeData();
    
    // Warm up database connection by running a simple query
    try {
      await storage.getProducts();
      log("Database connection warmed up");
    } catch (error) {
      log(`Warning: Failed to warm up database connection: ${error}`);
    }

    // Keep database connections alive with periodic health checks
    setInterval(async () => {
      try {
        await storage.getProducts();
      } catch (error) {
        // Silent health check - don't log errors
      }
    }, 60000); // Check every minute
    
    const server = await registerRoutes(app);

    app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
      const status = err.status || err.statusCode || 500;
      const message = err.message || "Internal Server Error";

      res.status(status).json({ message });
      throw err;
    });

    // importantly only setup vite in development and after
    // setting up all the other routes so the catch-all route
    // doesn't interfere with the other routes
    const isDevelopment = process.env.NODE_ENV === "development" || !process.env.NODE_ENV;
    if (isDevelopment) {
      await setupVite(app, server);
    } else {
      serveStatic(app);
    }

    // Start HTTP server (HTTPS temporarily disabled for verification)
    // Use port 5000 consistently across all environments
    const httpPort = parseInt(process.env.PORT || "5000", 10);
    log(`[DEBUG] Using port ${httpPort} for all environments`);
    
    server.listen(httpPort, () => {
      log(`HTTP server running on port ${httpPort} (host: 0.0.0.0)`);
      log(`[SSL] HTTPS temporarily disabled for verification - can be re-enabled later`);
      
      // Log Replit-specific access URLs for debugging
      if (process.env.REPLIT_DEV_DOMAIN) {
        log(`[Replit] Preview URL: https://${process.env.REPLIT_DEV_DOMAIN}`);
      }
      
      // Test external accessibility
      log(`[Network] Server bound to all interfaces on port ${httpPort}`);
    });

    // Start schedulers
    startSLAScheduler();
    startAutoCloseScheduler();
    startOverdueChangeScheduler();
    
  } catch (error) {
    log(`[CRITICAL] Server startup failed: ${error}`);
    console.error(error);
    process.exit(1);
  }
})();

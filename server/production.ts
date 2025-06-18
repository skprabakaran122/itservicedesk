import express, { type Request, Response, NextFunction } from "express";
import https from "https";
import http from "http";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { registerRoutes } from "./routes";
import { storage } from "./storage";

// Load environment variables from .env file
dotenv.config();

// Production-safe logging function
function log(message: string, source = "express") {
  const formattedTime = new Date().toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });
  console.log(`${formattedTime} [${source}] ${message}`);
}

// Production-safe static file serving
function serveStatic(app: express.Application) {
  app.use(express.static("dist/public"));
  app.get("*", (req: Request, res: Response) => {
    res.sendFile(path.resolve("dist/public/index.html"));
  });
}

// SSL Certificate configuration
function getSSLCredentials() {
  try {
    if (process.env.SSL_CERT && process.env.SSL_KEY) {
      return {
        cert: process.env.SSL_CERT,
        key: process.env.SSL_KEY
      };
    }

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

function createSelfSignedCert() {
  try {
    const forge = require('node-forge');
    const keys = forge.pki.rsa.generateKeyPair(2048);
    const cert = forge.pki.createCertificate();
    
    cert.publicKey = keys.publicKey;
    cert.serialNumber = '01';
    cert.validity.notBefore = new Date();
    cert.validity.notAfter = new Date();
    cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);
    
    const attrs = [{
      name: 'commonName',
      value: 'localhost'
    }];
    
    cert.setSubject(attrs);
    cert.setIssuer(attrs);
    cert.sign(keys.privateKey);
    
    const pemCert = forge.pki.certificateToPem(cert);
    const pemKey = forge.pki.privateKeyToPem(keys.privateKey);
    
    if (!fs.existsSync('./ssl')) {
      fs.mkdirSync('./ssl');
    }
    
    fs.writeFileSync('./ssl/cert.pem', pemCert);
    fs.writeFileSync('./ssl/key.pem', pemKey);
    
    log("[SSL] Self-signed certificate created");
    
    return {
      cert: pemCert,
      key: pemKey
    };
  } catch (error) {
    log(`[SSL] Error creating self-signed certificate: ${error}`);
    return null;
  }
}

function startSLAScheduler() {
  const schedule = async () => {
    try {
      await storage.refreshSLAMetrics();
      log("[SLA] Metrics refreshed successfully");
    } catch (error) {
      log(`[SLA] Error refreshing metrics: ${error}`);
    }
  };
  
  const now = new Date();
  const nextMidnight = new Date(now);
  nextMidnight.setDate(now.getDate() + 1);
  nextMidnight.setHours(0, 0, 0, 0);
  
  const msUntilMidnight = nextMidnight.getTime() - now.getTime();
  
  setTimeout(() => {
    schedule();
    setInterval(schedule, 24 * 60 * 60 * 1000);
  }, msUntilMidnight);
  
  log(`[SLA] Next SLA refresh scheduled for ${nextMidnight.toISOString()}`);
}

function startAutoCloseScheduler() {
  const schedule = async () => {
    try {
      const result = await storage.autoCloseResolvedTickets();
      if (result.closedCount > 0) {
        log(`[AutoClose] Closed ${result.closedCount} resolved tickets`);
      }
    } catch (error) {
      log(`[AutoClose] Error closing resolved tickets: ${error}`);
    }
  };
  
  setInterval(schedule, 60 * 60 * 1000);
  log("[AutoClose] Auto-close scheduler started (runs every hour)");
}

function startOverdueChangeScheduler() {
  const schedule = async () => {
    try {
      const result = await storage.sendOverdueNotifications();
      if (result.notificationCount > 0) {
        log(`[OverdueChanges] Sent ${result.notificationCount} overdue notifications`);
      }
    } catch (error) {
      log(`[OverdueChanges] Error sending overdue notifications: ${error}`);
    }
  };
  
  setInterval(schedule, 4 * 60 * 60 * 1000);
  log("[OverdueChanges] Overdue change scheduler started (runs every 4 hours)");
}

async function main() {
  try {
    log("Starting IT Service Desk...");
    
    const app = express();
    
    await storage.initializeData();
    log("Database connection warmed up");
    
    setInterval(async () => {
      try {
        await storage.getProducts();
      } catch (error) {
        // Silent health check
      }
    }, 60000);
    
    const server = await registerRoutes(app);

    app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
      const status = err.status || err.statusCode || 500;
      const message = err.message || "Internal Server Error";
      res.status(status).json({ message });
      throw err;
    });

    // Always serve static files in production
    serveStatic(app);

    // Start schedulers
    startSLAScheduler();
    startAutoCloseScheduler();
    startOverdueChangeScheduler();

    const httpPort = parseInt(process.env.PORT || "5000", 10);
    log(`[DEBUG] Using port ${httpPort} for all environments`);
    
    server.listen(httpPort, "0.0.0.0", () => {
      log(`HTTP server running on port ${httpPort} (host: 0.0.0.0)`);
      log(`[SSL] HTTPS temporarily disabled for verification - can be re-enabled later`);
      log(`[Network] Server bound to all interfaces on port ${httpPort}`);
    });

  } catch (error) {
    log(`Failed to start server: ${error}`);
    process.exit(1);
  }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  log(`Uncaught Exception: ${error}`);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  log(`Unhandled Rejection at: ${promise}, reason: ${reason}`);
  process.exit(1);
});

main().catch((error) => {
  log(`Application startup failed: ${error}`);
  process.exit(1);
});
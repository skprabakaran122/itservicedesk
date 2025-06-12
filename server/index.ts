import express, { type Request, Response, NextFunction } from "express";
import { registerRoutes } from "./routes";
import { setupVite, serveStatic, log } from "./vite";
import { storage } from "./storage";

const app = express();
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

(async () => {
  // Initialize storage data once at startup
  await storage.initializeData();
  
  // Warm up database connection by running a simple query
  try {
    await storage.getProducts();
    log("Database connection warmed up");
  } catch (error) {
    log("Warning: Failed to warm up database connection");
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
  if (app.get("env") === "development") {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }

  // ALWAYS serve the app on port 5000
  // this serves both the API and the client.
  // It is the only port that is not firewalled.
  const port = 5000;
  server.listen(port, "0.0.0.0", () => {
    log(`serving on port ${port} (host: 0.0.0.0)`);
    
    // Start the monthly SLA scheduler
    startSLAScheduler();
    
    // Start the auto-close scheduler
    startAutoCloseScheduler();
  });
})();

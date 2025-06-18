import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { registerRoutes } from './routes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = parseInt(process.env.PORT || '5000', 10);

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Trust proxy for nginx
app.set('trust proxy', true);

// Serve static files from the built frontend
const staticPath = path.join(__dirname, '../dist/public');
app.use(express.static(staticPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Register API routes
registerRoutes(app).then(() => {
  console.log('✓ API routes registered');
}).catch(error => {
  console.error('✗ Failed to register routes:', error);
  process.exit(1);
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Error handling
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Production server running on port ${PORT}`);
  console.log(`Serving static files from: ${staticPath}`);
  console.log(`Application ready at http://localhost:${PORT}`);
});
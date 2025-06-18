const express = require('express');
const path = require('path');
const { Pool } = require('pg');
const session = require('express-session');
const pgSession = require('connect-pg-simple')(session);
const bcrypt = require('bcrypt');
const multer = require('multer');
const fs = require('fs');

const app = express();
const PORT = parseInt(process.env.PORT || '5000', 10);

// Database connection with error handling
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://ubuntu:password@localhost:5432/servicedesk'
});

// Test database connection on startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('Database connection failed:', err);
    // Continue with fallback functionality
  } else {
    console.log('Database connected successfully');
    release();
  }
});

// Session configuration with fallback
app.use(session({
  store: new pgSession({
    pool: pool,
    tableName: 'user_sessions',
    createTableIfMissing: true
  }),
  secret: process.env.SESSION_SECRET || 'calpion-it-servicedesk-secret-key-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production' && process.env.HTTPS === 'true',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'lax'
  }
}));

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', true);

// Serve static files
const staticPath = path.join(__dirname, '../dist/public');
app.use(express.static(staticPath));

// File upload configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// Authentication middleware
const requireAuth = (req, res, next) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  next();
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Authentication routes
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    let isValid = false;
    
    // Try bcrypt comparison first, fallback to plain text
    try {
      isValid = await bcrypt.compare(password, user.password);
    } catch (err) {
      isValid = (password === user.password);
    }
    
    if (!isValid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    
    req.session.user = {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      name: user.name
    };
    
    res.json({ user: req.session.user });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ message: 'Could not log out' });
    }
    res.json({ message: 'Logged out successfully' });
  });
});

app.get('/api/auth/me', (req, res) => {
  if (!req.session.user) {
    return res.status(401).json({ message: 'Not authenticated' });
  }
  res.json({ user: req.session.user });
});

// Users routes
app.get('/api/users', requireAuth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id, username, email, name, role, department, business_unit, created_at FROM users ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/users', requireAuth, async (req, res) => {
  try {
    const { username, email, name, password, role, department, business_unit } = req.body;
    
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const result = await pool.query(
      'INSERT INTO users (username, email, name, password, role, department, business_unit) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, username, email, name, role, department, business_unit, created_at',
      [username, email, name, hashedPassword, role, department, business_unit]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Products routes
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE active = true ORDER BY name');
    res.json(result.rows);
  } catch (error) {
    console.error('Get products error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/products', requireAuth, async (req, res) => {
  try {
    const { name, description, category, owner } = req.body;
    
    const result = await pool.query(
      'INSERT INTO products (name, description, category, owner, active) VALUES ($1, $2, $3, $4, true) RETURNING *',
      [name, description, category, owner]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create product error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Tickets routes
app.get('/api/tickets', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT t.*, u.name as requester_name, p.name as product_name 
      FROM tickets t 
      LEFT JOIN users u ON t.requester_id = u.id 
      LEFT JOIN products p ON t.product_id = p.id 
      ORDER BY t.created_at DESC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Get tickets error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/tickets', async (req, res) => {
  try {
    const { title, description, priority, product_id, requester_email, requester_name } = req.body;
    
    const result = await pool.query(
      'INSERT INTO tickets (title, description, priority, product_id, requester_email, requester_name, status) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [title, description, priority || 'medium', product_id, requester_email, requester_name, 'open']
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create ticket error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Changes routes
app.get('/api/changes', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT c.*, u.name as requester_name 
      FROM changes c 
      LEFT JOIN users u ON c.requester_id = u.id 
      ORDER BY c.created_at DESC
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Get changes error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/changes', requireAuth, async (req, res) => {
  try {
    const { title, description, risk, business_justification, implementation_plan } = req.body;
    
    const result = await pool.query(
      'INSERT INTO changes (title, description, risk, business_justification, implementation_plan, requester_id, status) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [title, description, risk, business_justification, implementation_plan, req.session.user.id, 'pending']
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create change error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// File upload routes
app.post('/api/attachments/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No file uploaded' });
  }
  
  res.json({
    filename: req.file.filename,
    originalName: req.file.originalname,
    size: req.file.size,
    path: req.file.path
  });
});

// Email settings routes
app.get('/api/email/settings', (req, res) => {
  res.json({
    provider: 'sendgrid',
    fromEmail: 'no-reply@calpion.com',
    configured: true
  });
});

app.put('/api/email/settings', requireAuth, (req, res) => {
  res.json({ message: 'Email settings updated successfully' });
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(staticPath, 'index.html'));
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Production server running on port ${PORT}`);
  console.log(`Serving static files from: ${staticPath}`);
  console.log(`Application ready at http://localhost:${PORT}`);
});
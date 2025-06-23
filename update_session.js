const fs = require('fs');
const content = fs.readFileSync('server/routes.ts', 'utf8');

const oldSessionCode = `import session from "express-session";
import MemoryStore from "memorystore";`;

const newSessionCode = `import session from "express-session";
import connectPgSimple from "connect-pg-simple";`;

const oldStoreCode = `  app.use(session({
    store: new MemoryStoreSession({
      checkPeriod: 86400000 // prune expired entries every 24h
    }),`;

const newStoreCode = `  const pgSession = connectPgSimple(session);
  app.use(session({
    store: new pgSession({
      conString: process.env.DATABASE_URL || "postgresql://postgres:password@database:5432/itservicedesk",
      tableName: 'sessions',
      createTableIfMissing: false
    }),`;

let updatedContent = content.replace(oldSessionCode, newSessionCode);
updatedContent = updatedContent.replace(oldStoreCode, newStoreCode);

fs.writeFileSync('server/routes.ts', updatedContent);
console.log('Session store updated to use PostgreSQL');

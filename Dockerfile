# Multi-stage build for IT Service Desk
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build frontend
RUN npm run build

# Production stage
FROM node:20-alpine AS production

WORKDIR /app

# Install production dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy built application
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server
COPY --from=builder /app/shared ./shared
COPY --from=builder /app/drizzle.config.ts ./
COPY --from=builder /app/migrations ./migrations

# Install tsx for running TypeScript
RUN npm install -g tsx

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodeuser -u 1001
USER nodeuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Start application
CMD ["tsx", "server/index.ts"]
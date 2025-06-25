# Multi-stage Docker build for IT Service Desk
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files
COPY package*.json ./
# Install ALL dependencies (not just production) for building
RUN npm ci

# Copy source code
COPY . .

# Build frontend
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

# Install production dependencies + tsx for TypeScript support
COPY package*.json ./
RUN npm ci --production && npm install -g tsx

# Copy built application
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server
COPY --from=builder /app/shared ./shared
COPY --from=builder /app/migrations ./migrations
COPY docker-init.sh ./
RUN chmod +x docker-init.sh

# Create non-root user and setup directories
RUN apk add --no-cache curl && \
    addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 && \
    mkdir -p logs uploads && \
    chown -R appuser:nodejs /app && \
    chmod 755 /app/uploads

USER appuser

# Expose port 5000 (to match docker-compose)
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Start application with Docker initialization
CMD ["./docker-init.sh"]

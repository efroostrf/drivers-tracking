# ============================================
# Stage 1: Build Stage
# ============================================
FROM node:22-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./

# Install all dependencies (including devDependencies for building)
RUN npm ci

# Copy source code
COPY src/ ./src/
COPY tsconfig.json ./

# Build TypeScript code
RUN npm run build

# ============================================
# Stage 2: Production Stage
# ============================================
FROM node:22-alpine AS production

# Set working directory
WORKDIR /app

# Install dumb-init to handle signals properly
RUN apk add --no-cache dumb-init

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev && \
    npm cache clean --force

# Copy compiled code from builder stage
COPY --from=builder /app/dist ./dist

# Use non-root user for security
USER node

# Expose port (default 3000, can be overridden by environment)
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:${PORT:-3000}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "dist/index.js"]


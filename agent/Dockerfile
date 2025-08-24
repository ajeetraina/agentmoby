FROM node:18-alpine

# Install system dependencies and create user
RUN apk add --no-cache curl && \
    addgroup -g 1001 -S nodejs && \
    adduser -S mobyagent -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies using npm install (works without package-lock.json)
RUN npm install --production --verbose && \
    npm cache clean --force

# Copy source code
COPY --chown=mobyagent:nodejs . .

# Create data directory
RUN mkdir -p /app/data && chown mobyagent:nodejs /app/data

# Switch to non-root user
USER mobyagent

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "src/index.js"]

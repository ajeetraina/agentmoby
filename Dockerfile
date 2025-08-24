FROM node:18-alpine

WORKDIR /app

# Create package.json directly to avoid file issues
RUN echo '{ \
  "name": "agentmoby-adk", \
  "version": "1.0.0", \
  "main": "index.js", \
  "scripts": { \
    "start": "node index.js" \
  }, \
  "dependencies": { \
    "express": "^4.18.2", \
    "cors": "^2.8.5", \
    "axios": "^1.6.0" \
  } \
}' > package.json

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 8000
ENV PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8000/health || exit 1

CMD ["npm", "start"]

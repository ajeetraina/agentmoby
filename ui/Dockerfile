FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache curl

# Create user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev dependencies for build)
RUN npm install --verbose && \
    npm cache clean --force

# Copy source code
COPY --chown=nextjs:nodejs . .

# Build the application
RUN npm run build

# Switch to non-root user
USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=development

# Use Next.js dev mode for easier local testing
CMD ["npm", "run", "dev"]

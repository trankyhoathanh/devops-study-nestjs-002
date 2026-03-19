# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy source code
COPY . .

# Build application
RUN yarn build

# Stage 2: Production
FROM node:20-alpine

RUN apk add --no-cache tini

WORKDIR /app

# Copy built assets from builder
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./

RUN --mount=type=bind,from=builder,source=/app/node_modules,target=/tmp/node_modules \
    cp -r /tmp/node_modules ./node_modules && \
    # Xóa devDependencies và các file không cần
    rm -rf node_modules/@types \
           node_modules/*.md \
           node_modules/*.d.ts \
           node_modules/.bin \
           node_modules/.cache && \
    # Giữ lại chỉ production dependencies
    yarn install --production --frozen-lockfile --ignore-scripts && \
    yarn cache clean

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

RUN rm -rf /root/.cache /tmp/* /var/cache/apk/* && \
    mkdir -p /app/logs && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 37101

# QUAN TRỌNG: Chạy đúng file main.js
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/main.js"]
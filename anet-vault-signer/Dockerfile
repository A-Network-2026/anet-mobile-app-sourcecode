# anet-vault-signer — minimal Fly.io image
# Outbound-only daemon: polls L1, signs, POSTs back. No inbound port.

FROM node:20-alpine

WORKDIR /app

# Install deps first (better layer caching)
COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund

# Copy source
COPY src ./src

# Run as non-root for safety
RUN addgroup -S signer && adduser -S signer -G signer \
  && chown -R signer:signer /app
USER signer

ENV NODE_ENV=production

CMD ["node", "src/index.js"]

FROM node:20-alpine

WORKDIR /app

# Install deps first so Docker layer-caches them across code changes.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY src        ./src
COPY scripts    ./scripts
COPY schema.sql ./schema.sql

ENV NODE_ENV=production
CMD ["node", "src/index.js"]

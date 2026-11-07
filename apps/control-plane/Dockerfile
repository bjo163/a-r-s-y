FROM node:24-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app

COPY apps/control-plane/package.json ./package.json
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

COPY apps/control-plane/src ./src
COPY apps/control-plane/public ./public
COPY apps/control-plane/schema.sql ./schema.sql
COPY brand/arsy-mark.svg ./public/arsy-mark.svg

RUN chown -R node:node /app
USER node

EXPOSE 3000
HEALTHCHECK --interval=20s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]

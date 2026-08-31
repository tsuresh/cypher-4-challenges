# h08 Polluted Pearls — per-team Node instance.
FROM node:20-slim
WORKDIR /app
COPY app/package.json .
RUN npm install --omit=dev --no-audit --no-fund
COPY app/server.js .
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/docker-entrypoint.sh"]

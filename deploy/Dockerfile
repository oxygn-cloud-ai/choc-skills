FROM node:22-slim

WORKDIR /app

# Copy server and client
COPY server/package.json server/package-lock.json ./server/
RUN cd server && npm ci --omit=dev

COPY server/*.js ./server/
COPY client/ ./client/

EXPOSE 3000

CMD ["node", "server/server.js"]

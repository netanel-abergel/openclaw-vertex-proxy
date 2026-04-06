FROM node:18-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY src/proxy.js ./src/

EXPOSE 4100

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget -qO- http://localhost:${PROXY_PORT:-4100}/health || exit 1

CMD ["node", "src/proxy.js"]

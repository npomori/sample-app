# ビルドコンテキストは、このアプリと participant-app-base の親ディレクトリ。
# 公開するまでは file:../participant-app-base を解決するため、リポジトリ単体をコンテキストにしない。
# docker build -f astro-webauthn-app2/Dockerfile -t astro-webauthn-app2 .

FROM node:24-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate

FROM base AS library
WORKDIR /participant-app-base
COPY participant-app-base/package.json participant-app-base/pnpm-lock.yaml participant-app-base/pnpm-workspace.yaml participant-app-base/prisma.config.ts ./
COPY participant-app-base/prisma ./prisma
RUN pnpm install --frozen-lockfile
COPY participant-app-base ./
RUN pnpm run db:generate

FROM base AS dependencies
WORKDIR /app
COPY --from=library /participant-app-base /participant-app-base
COPY astro-webauthn-app2/package.json astro-webauthn-app2/pnpm-lock.yaml astro-webauthn-app2/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile --prod

FROM base AS build
WORKDIR /app
COPY --from=library /participant-app-base /participant-app-base
COPY astro-webauthn-app2/package.json astro-webauthn-app2/pnpm-lock.yaml astro-webauthn-app2/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY astro-webauthn-app2 ./
RUN pnpm run build

FROM node:24-alpine AS production
WORKDIR /app
RUN apk add --no-cache bash curl
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=library --chown=nodejs:nodejs /participant-app-base /participant-app-base
COPY --chown=nodejs:nodejs astro-webauthn-app2/package.json astro-webauthn-app2/pnpm-lock.yaml astro-webauthn-app2/pnpm-workspace.yaml ./
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs astro-webauthn-app2/entrypoint.sh astro-webauthn-app2/healthcheck.sh ./
RUN chmod +x entrypoint.sh healthcheck.sh

USER nodejs

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=90s --retries=3 \
    CMD ./healthcheck.sh

ENTRYPOINT ["./entrypoint.sh"]

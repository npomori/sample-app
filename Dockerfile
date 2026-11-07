# ビルドコンテキストは、このアプリと astro-participant-auth の親ディレクトリ。
# 公開するまでは file:../astro-participant-auth を解決するため、リポジトリ単体をコンテキストにしない。
# docker build -f astro-webauthn-app2/Dockerfile -t astro-webauthn-app2 .

FROM node:24-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate

FROM base AS library
WORKDIR /astro-participant-auth
COPY astro-participant-auth/package.json astro-participant-auth/pnpm-lock.yaml astro-participant-auth/pnpm-workspace.yaml astro-participant-auth/prisma.config.ts ./
COPY astro-participant-auth/prisma ./prisma
RUN pnpm install --frozen-lockfile
COPY astro-participant-auth ./
RUN pnpm run db:generate

FROM base AS dependencies
WORKDIR /app
COPY --from=library /astro-participant-auth /astro-participant-auth
COPY astro-webauthn-app2/package.json astro-webauthn-app2/pnpm-lock.yaml astro-webauthn-app2/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile --prod

FROM base AS build
WORKDIR /app
COPY --from=library /astro-participant-auth /astro-participant-auth
COPY astro-webauthn-app2/package.json astro-webauthn-app2/pnpm-lock.yaml astro-webauthn-app2/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY astro-webauthn-app2 ./
RUN pnpm run build

FROM node:24-alpine AS production
WORKDIR /app
RUN apk add --no-cache bash curl
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=library --chown=nodejs:nodejs /astro-participant-auth /astro-participant-auth
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

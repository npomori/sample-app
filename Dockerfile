# ビルドコンテキストはこのリポジトリ。
# ローカルの pnpm は隣の participant-app-base を file: で使う。
# イメージのビルドは participant-app-base.rev のコミットを GitHub から取る。
# docker build -t sample-app .

FROM node:24-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate

FROM base AS library
RUN apk add --no-cache git
WORKDIR /participant-app-base
COPY participant-app-base.rev /tmp/participant-app-base.rev
ARG BASE_REPO=https://github.com/npomori/participant-app-base.git
ARG BASE_REF=
RUN set -eu; \
    ref="${BASE_REF:-$(tr -d '[:space:]' < /tmp/participant-app-base.rev)}"; \
    git init; \
    git remote add origin "$BASE_REPO"; \
    git fetch --depth 1 origin "$ref"; \
    git checkout --detach FETCH_HEAD; \
    rm -rf .git
RUN pnpm install --frozen-lockfile
RUN pnpm run db:generate

FROM base AS dependencies
WORKDIR /app
COPY --from=library /participant-app-base /participant-app-base
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile --prod

FROM base AS build
WORKDIR /app
COPY --from=library /participant-app-base /participant-app-base
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . ./
RUN pnpm run build

FROM node:24-alpine AS production
WORKDIR /app
RUN apk add --no-cache bash curl
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=library --chown=nodejs:nodejs /participant-app-base /participant-app-base
COPY --chown=nodejs:nodejs package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs entrypoint.sh healthcheck.sh ./
RUN chmod +x entrypoint.sh healthcheck.sh

USER nodejs

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --start-period=90s --retries=3 \
    CMD ./healthcheck.sh

ENTRYPOINT ["./entrypoint.sh"]

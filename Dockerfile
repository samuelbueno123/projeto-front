# ==============================================================================
# Multi-stage Dockerfile for Flutter Web Application
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. BUILDER STAGE
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim AS build

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"
ENV FLUTTER_SUPPRESS_ANALYTICS=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git curl unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter stable SDK
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter precache --web

WORKDIR /app

# Dependency resolution
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code and static assets
COPY lib ./lib
COPY web ./web
COPY assets ./assets

# Build Flutter Web release with dart-defines
ARG API_BASE_URL=http://localhost:8080
ARG GOOGLE_WEB_CLIENT_ID=1093543407623-ch2dq0uh0bnvrhm6pkf6kd8v75bvr3a0.apps.googleusercontent.com

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}

# ------------------------------------------------------------------------------
# 2. RUNNER STAGE (Hardened, unprivileged Nginx)
# ------------------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runner

LABEL org.opencontainers.image.title="Gestao Condominial Frontend UI" \
      org.opencontainers.image.description="Flutter Web UI served via unprivileged Nginx" \
      org.opencontainers.image.version="1.0.0"

# Copy unprivileged Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled WebAssembly / JavaScript artifacts
COPY --from=build /app/build/web /usr/share/nginx/html

# Port 8080 is the standard unprivileged HTTP port
EXPOSE 8080

# Automated healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/healthz > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]

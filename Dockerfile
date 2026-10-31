FROM debian:bookworm-slim AS build

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"
ENV FLUTTER_SUPPRESS_ANALYTICS=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git curl unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 3.47.5 https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter precache --web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY lib ./lib
COPY web ./web

ARG API_BASE_URL=http://localhost:8080
ARG GOOGLE_WEB_CLIENT_ID=1093543407623-ch2dq0uh0bnvrhm6pkf6kd8v75bvr3a0.apps.googleusercontent.com
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}

FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

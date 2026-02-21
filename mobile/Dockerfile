FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.24.5

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl git unzip xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Устанавливаем Flutter SDK
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Отключаем аналитику и принимаем лицензии
RUN flutter config --no-analytics && \
    flutter precache --web && \
    dart --disable-analytics

WORKDIR /app

# Копируем pubspec файлы для кэширования зависимостей
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Копируем весь проект
COPY . .

# Собираем Flutter web
RUN flutter build web --release

# --- Финальный образ: лёгкий Nginx ---
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

# Nginx конфиг для SPA
RUN printf 'server {\n\
    listen 80;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]


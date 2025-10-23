# 前端构建阶段
FROM node:alpine as frontend
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false && npm run build

# PHP 依赖阶段
FROM composer:2 as vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts

# 最终运行镜像
FROM php:8.2-fpm-alpine
RUN apk add --no-cache \
    nginx \
    supervisor \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    && docker-php-ext-install pdo_mysql zip intl mbstring opcache

# 复制配置
COPY docker/nginx.conf     /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/php-fpm.conf   /usr/local/etc/php-fpm.d/www.conf
COPY docker/entrypoint.sh  /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html
# 依次复制代码、依赖、前端产物
COPY . ./
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public ./public
COPY --from=frontend /app/resources/views/assets ./resources/views/assets

# 权限 & 入口
RUN chown -R www-data:www-data /var/www/html \
 && chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]

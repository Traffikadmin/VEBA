# ─────────────────────────────────────────────
#  WordPress on PHP 8.2 + Apache
# ─────────────────────────────────────────────
FROM php:8.2-apache AS runtime

# OS deps + PHP extensions + WP-CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpng-dev \
      libjpeg-dev \
      libfreetype6-dev \
      libzip-dev \
      libicu-dev \
      libonig-dev \
      libmagickwand-dev \
      unzip \
      curl \
      less \
      default-mysql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
         gd \
         pdo \
         pdo_mysql \
         mysqli \
         opcache \
         intl \
         mbstring \
         zip \
         bcmath \
         exif \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && curl -sS -o /usr/local/bin/wp \
         https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# PHP runtime config
COPY docker/php/php.ini /usr/local/etc/php/conf.d/app.ini

# Apache config
RUN a2enmod rewrite headers expires deflate
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html

# Download WordPress core (keeps image self-contained; git repo supplies wp-content only)
RUN wp core download --allow-root --path=/var/www/html

# Overlay custom themes/plugins/mu-plugins from the repo
COPY wp-content/ ./wp-content/

# WordPress config (reads env vars — secrets injected by ECS at runtime)
COPY wp-config.php ./wp-config.php

# Lightweight health check endpoint
COPY health.php ./health.php

RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health.php || exit 1

EXPOSE 80
CMD ["apache2-foreground"]

# Install Caddy
FROM docker.io/caddy:builder-alpine AS caddy-builder
ENV GO111MODULE=on \
    GOPROXY=https://goproxy.cn,direct
RUN xcaddy build


# Install PHP
FROM docker.io/alpine:3.16
# Setup document root
WORKDIR /var/www/html

# Get caddy
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

# Install packages and remove default server definition
RUN apk add --no-cache \
  curl \
  php81 \
  php81-ctype \
  php81-curl \
  php81-dom \
  php81-fpm \
  php81-gd \
  php81-intl \
  php81-mbstring \
  php81-mysqli \
  php81-opcache \
  php81-openssl \
  php81-phar \
  php81-session \
  php81-xml \
  php81-xmlreader \
  php81-zlib \
  php81-redis \
  php81-tokenizer \
  php81-fileinfo \
  php81-zip \
  php81-pdo \
  php81-pdo_mysql \
  php81-pdo_pgsql \
  php81-exif \
  php81-pecl-xdebug \
  php81-xmlwriter \
  php81-simplexml \
  php81-iconv \
  php81-bcmath \
  supervisor \
  icu-data-full

# Create symlink so programs depending on `php` still function
RUN ln -s /usr/bin/php81 /usr/bin/php


# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"  && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

# Configure nginx
COPY config/Caddyfile /etc/caddy/Caddyfile

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php81/php-fpm.d/www.conf
COPY config/php.ini /etc/php81/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN mkdir /.config
RUN chown -R nobody.nobody /var/www/html /run /.config

# Switch to use a non-root user from here on
USER nobody

# Add application
COPY --chown=nobody src/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

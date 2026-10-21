# Install Caddy
FROM --platform=$BUILDPLATFORM docker.io/caddy:builder-alpine AS caddy-builder
ARG TARGETOS
ARG TARGETARCH
ARG GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on \
    GOPROXY=${GOPROXY}
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH xcaddy build


# Build PHP from Alpine's own php83 APKBUILD at a newer upstream release, so
# the image gets PHP security fixes before Alpine ships them while keeping the
# stock php83 package layout
FROM docker.io/alpine:3.24 AS php-build
ARG APORTS_REF=3.24-stable
ARG PHP_VERSION=8.3.36
ARG PHP_SHA256=dd54693aa334c5c4d72e9aee96b082c2473750a18a6c1d105789c93a3b1692fd
RUN apk add --no-cache alpine-sdk curl && \
    mkdir /aports && \
    curl -fsSL "https://gitlab.alpinelinux.org/alpine/aports/-/archive/${APORTS_REF}/aports.tar.gz?path=community/php83" | \
      tar -xz -C /aports --strip-components=1 && \
    cd /aports/community/php83 && \
    sed -i -e "s/^pkgver=.*/pkgver=${PHP_VERSION}/" -e 's/^pkgrel=.*/pkgrel=0\noptions="!check"/' APKBUILD && \
    abuild -F fetch && \
    echo "${PHP_SHA256}  /var/cache/distfiles/php-${PHP_VERSION}.tar.xz" | sha256sum -c - && \
    abuild -F checksum && \
    abuild-keygen -an && \
    abuild -F -r && \
    cp /root/.abuild/*.rsa.pub /root/packages/


# Install PHP
FROM docker.io/alpine:3.24 AS app
ARG PHP_VERSION=8.3.36
# Setup document root
WORKDIR /var/www/html

# Get caddy
COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

# Install packages and remove default server definition
RUN --mount=type=bind,from=php-build,source=/root/packages,target=/php-packages \
  cp /php-packages/*.rsa.pub /etc/apk/keys/ && \
  apk add --no-cache --repository /php-packages/community \
  curl \
  php83 \
  php83-ctype \
  php83-curl \
  php83-dom \
  php83-fpm \
  php83-gd \
  php83-intl \
  php83-mbstring \
  php83-mysqli \
  php83-opcache \
  php83-openssl \
  php83-phar \
  php83-session \
  php83-xml \
  php83-xmlreader \
  php83-zlib \
  php83-redis \
  php83-tokenizer \
  php83-fileinfo \
  php83-zip \
  php83-pdo \
  php83-pdo_mysql \
  php83-pdo_pgsql \
  php83-exif \
  php83-pecl-xdebug \
  php83-xmlwriter \
  php83-simplexml \
  php83-iconv \
  php83-bcmath \
  supervisor \
  icu-data-full && \
  rm /etc/apk/keys/$(basename /php-packages/*.rsa.pub) && \
  php83 -r 'exit(PHP_VERSION === getenv("PHP_VERSION") ? 0 : 1);'

# Create symlink so programs depending on `php` still function
RUN ln -s /usr/bin/php83 /usr/bin/php

# Install composer
COPY --from=docker.io/composer:2 /usr/bin/composer /usr/local/bin/composer

# Configure nginx
COPY config/Caddyfile /etc/caddy/Caddyfile

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY config/php.ini /etc/php83/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN mkdir /.config
RUN chown -R nobody:nobody /var/www/html /run /.config

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

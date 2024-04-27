# Docker PHP-FPM 8.1 & Caddy on Alpine Linux
Example PHP-FPM 8.1 & Caddy container image for Docker, built on [Alpine Linux](https://www.alpinelinux.org/).

Repository: https://github.com/ParaParty/docker-php-caddy

* Built on the lightweight and secure Alpine Linux distribution
* Multi-platform, supporting AMD4, ARMv6, ARMv7, ARM64
* Uses PHP 8.1 for better performance, lower CPU usage & memory footprint
* The services Caddy, PHP-FPM and supervisord run under a non-privileged user (nobody) to make it more secure
* The logs of all the services are redirected to the output of the Docker container (visible with `docker logs -f <container name>`)
* Follows the KISS principle (Keep It Simple, Stupid) to make it easy to understand and adjust the image to your needs

![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

## Usage

Start the Docker container:

    docker run -p 80:8080 paraparty/php-caddy

See the PHP info on http://localhost, or the static html page on http://localhost/test.html

Or mount your own code to be served by PHP-FPM & Caddy

    docker run -p 80:8080 -v ~/my-codebase:/var/www/html paraparty/php-caddy

## Configuration
In [config/](config/) you'll find the default configuration files for Caddy, PHP and PHP-FPM.
If you want to extend or customize that you can do so by mounting a configuration file in the correct folder;

Caddy configuration:

    docker run -v "`pwd`/Caddyfile:/etc/caddy/Caddyfile" paraparty/php-caddy

PHP configuration:

    docker run -v "`pwd`/php-setting.ini:/etc/php83/conf.d/settings.ini" paraparty/php-caddy

PHP-FPM configuration:

    docker run -v "`pwd`/php-fpm-settings.conf:/etc/php83/php-fpm.d/server.conf" paraparty/php-caddy

_Note; Because `-v` requires an absolute path I've added `pwd` in the example to return the absolute path to the current directory_

## Thanks
[TrafeX/docker-php-nginx](https://github.com/TrafeX/docker-php-nginx): Gives the idea of this repository.
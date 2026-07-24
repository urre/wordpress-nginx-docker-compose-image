FROM php:8.3-fpm

# persistent dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# Ghostscript is required for rendering PDF previews
		ghostscript \
	; \
	rm -rf /var/lib/apt/lists/*

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
# NOTE: the -dev library packages are kept (not purged) so their runtime
# shared objects (libMagickWand, libzip, etc.) remain available for the
# extensions at runtime. This is simpler and more robust than the
# ldd/apt-mark auto-removal dance, at the cost of a slightly larger image —
# an acceptable trade-off for a local development base image.
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libmagickwand-dev \
		libpng-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		mysqli \
		zip \
	; \
	\
# The last tagged PECL imagick release (3.7.0) does not build on PHP 8.3,
# so install imagick from the upstream master branch, which includes the
# PHP 8.3+ build fixes.
	curl -fsSL https://github.com/Imagick/imagick/archive/refs/heads/master.tar.gz -o /tmp/imagick.tar.gz; \
	mkdir -p /usr/src/php/ext/imagick; \
	tar -xzf /tmp/imagick.tar.gz -C /usr/src/php/ext/imagick --strip-components=1; \
	rm /tmp/imagick.tar.gz; \
	docker-php-ext-install imagick; \
	\
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini

# NOTE: WordPress core is intentionally NOT bundled here. The consuming project
# (wordpress-nginx-docker-compose) uses Bedrock, which installs WordPress core
# via Composer into web/wp and bind-mounts the app over /var/www/html. This
# image only needs to provide PHP-FPM and the WordPress-recommended extensions.

VOLUME /var/www/html

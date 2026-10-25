FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libpcre2-dev \
    && pecl install mailparse \
    && docker-php-ext-enable mailparse \
    && docker-php-ext-install fileinfo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Mirrors community-skeleton's real layout: a Symfony project root
# (/var/www/app) with public/ as the Apache document root - matches
# Localhost::documentRootDirectory = projectRootDirectory . '/public'.
RUN mkdir -p /var/www/app/public

WORKDIR /var/www/app/poc-harness
COPY composer.json ./
RUN composer install --no-interaction --prefer-dist

COPY src ./src
COPY run.php malicious-email.eml ./

# Real repo has NO .htaccess or vhost rule restricting PHP execution under
# public/assets/ - confirmed via community-skeleton/public/.htaccess (only
# rewrites requests for non-existent files; a written .php file exists, so
# the RewriteCond `!-f` fails and Apache serves+executes it directly, mod_php
# default). Leaving Apache's default config untouched here for fidelity.
RUN { \
      echo '<VirtualHost *:80>'; \
      echo '    DocumentRoot /var/www/app/public'; \
      echo '    <Directory /var/www/app/public>'; \
      echo '        AllowOverride All'; \
      echo '        Require all granted'; \
      echo '    </Directory>'; \
      echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/000-default.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]

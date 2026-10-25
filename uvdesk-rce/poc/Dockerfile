FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libpcre2-dev \
    && pecl install mailparse \
    && docker-php-ext-enable mailparse \
    && docker-php-ext-install fileinfo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Run Apache workers as a de-privileged uvdesk account (uid 1001), matching a
# real community-skeleton deploy (its Dockerfile drops privs via `gosu uvdesk`).
# This is why the landed reverse shell runs as uid=1001(uvdesk), not www-data -
# representative of production, not cosmetic.
RUN useradd -u 1001 -m -s /bin/bash uvdesk \
    && sed -i 's/:=www-data}/:=uvdesk}/g' /etc/apache2/envvars

RUN mkdir -p /var/www/app/public

WORKDIR /var/www/app/poc-harness
COPY composer.json ./
RUN composer install --no-interaction --prefer-dist

COPY src ./src
COPY plant.php malicious-email.eml ./

# community-skeleton's real public/.htaccess has no rule restricting PHP
# execution under public/assets/ - mirrored here for fidelity.
RUN { \
      echo '<VirtualHost *:80>'; \
      echo '    DocumentRoot /var/www/app/public'; \
      echo '    <Directory /var/www/app/public>'; \
      echo '        AllowOverride All'; \
      echo '        Require all granted'; \
      echo '    </Directory>'; \
      echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/000-default.conf

EXPOSE 80
CMD ["apache2-foreground"]

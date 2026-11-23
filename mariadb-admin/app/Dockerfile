# From github.com/anil3a/simple-phpadminer-mariadb-docker (app/), bumped to a current PHP base
FROM php:8.3-apache

RUN docker-php-ext-install pdo pdo_mysql

COPY index.php php_mysql_logo.png /var/www/html/
RUN chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html

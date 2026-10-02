#!/bin/sh
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
. /run/secrets/credentials   # définit WP_ADMIN_PASSWORD et WP_USER_PASSWORD

cd /var/www/html

# Attente bornée de MariaDB (30 essais max, pas une boucle infinie)
i=0
until mariadb-admin ping -h mariadb -u"${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        echo "[wordpress] MariaDB injoignable" >&2
        exit 1
    fi
    sleep 2
done

if [ ! -f wp-config.php ]; then
    echo "[wordpress] Installation de WordPress..."
    wp core download --allow-root

    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost=mariadb:3306

    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email

    wp user create --allow-root \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}"
fi

chown -R www-data:www-data /var/www/html

echo "[wordpress] Démarrage de php-fpm"
exec php-fpm8.2 -F
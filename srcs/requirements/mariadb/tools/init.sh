#!/bin/sh
set -e

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Premier lancement : le volume est vide
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[mariadb] Initialisation du dossier de données..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# La base WordPress n'existe pas encore : on la crée
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "[mariadb] Création de la base et des utilisateurs..."
    mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
fi

echo "[mariadb] Démarrage du serveur"
exec mysqld --user=mysql
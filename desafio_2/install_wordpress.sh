#!/bin/bash

DB_NAME="wordpress"
DB_USER="wordpress"
WP_DIR="/srv/www/wordpress"
APACHE_CONF="/etc/apache2/sites-available/wordpress.conf"


SQL1="CREATE DATABASE IF NOT EXISTS $DB_NAME"
SQL2="CREATE USER IF NOT EXITS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS':"
SQL3="GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';"
SQL4="FLUSH PRIVILEGES;"

read -sp "Please enter database password: " DB_PASS
#Install Dependencies:
sudo apt update
sudo apt install apache2 \
                 ghostscript \
                 libapache2-mod-php \
                 mysql-server \
                 php \
                 php-bcmath \
                 php-curl \
                 php-imagick \
                 php-intl \
                 php-json \
                 php-mbstring \
                 php-mysql \
                 php-xml \
                 php-zip -y

#Installing WordPress:

if [ -f "$WP_DIR/wp-config.php" ]; then
	echo "Wordpress is already installed"
else
	echo "WordPress is not installed."
	echo "INSTALLING"
	sudo mkdir -p /srv/www
	sudo chown www-data: /srv/www
	curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www
fi

#Creating MYSQL DB and WordPress user
if dpkg -l | grep -qw sql-server; then
	
	echo "SQL installed, configuration DB and user"
	read -sp "Enter mysql password: " DB_ROOT_PASS
	mysql -u root -p "$DB_ROOT_PASS" -e "$SQL1$SQL2$SQL3$SQL4"
	echo "DB and user already configurated"
	sudo service mysql reload
else
	sudo apt install mysql-server
	exit
fi


#Configure Apache for WordPress

if [ -f "$APACHE_CONF" ]; then
	echo "Apache configuration already exist"
else
	echo "Configuration Apache for wordPress"

	sudo bash -c "cat > $APACHE_CONF" <<EOF 
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

	echo "Apache configurations has been created"

	#Enable the site with:
	sudo a2ensite wordpress
	#Enable URL rewriting with:
	sudo a2enmod rewrite
	#Disable the default “It Works” site with:
	sudo a2dissite 000-default
	#Finally, reload apache2 to apply all these changes:
	sudo service apache2 reload
fi

#Configure WordPress to connect to the database (wp-config.php)

sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php

#Set database credentials

sudo -u www-data sed -i 's/database_name_here/'$DB_NAME'/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/'$DB_USER'/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/'$DB_PASS'/' /srv/www/wordpress/wp-config.php

#Save api content

API_WP=$(curl https://api.wordpress.org/secret-key/1.1/salt/)

KEYS=$(echo "$API_WP" | sed 's/[&]/\\&/g')

WP_CONFIG="/srv/www/wordpress/wp-config.php"

sudo -u www-data sed -i '/AUTH_KEY/d' $WP_CONFIG
sudo -u www-data sed -i '/SECURE_AUTH_KEY/d' $WP_CONFIG
sudo -u www-data sed -i '/LOGGED_IN_KEY/d' $WP_CONFIG
sudo -u www-data sed -i '/NONCE_KEY/d' $WP_CONFIG
sudo -u www-data sed -i '/AUTH_SALT/d' $WP_CONFIG
sudo -u www-data sed -i '/SECURE_AUTH_SALT/d' $WP_CONFIG
sudo -u www-data sed -i '/LOGGED_IN_SALT/d' $WP_CONFIG
sudo -u www-data sed -i '/NONCE_SALT/d' $WP_CONFIG

echo "$KEYS" | sudo -u www-data tee -a $WP_CONFIG > /dev/null

#Validate .htaccess

if [ -f $WP_DIR/.htaccess ]; then
	echo ".htaccess already exist"
else
	echo "creating .htaccess"
	sudo bash -c "cat $WP_DIR/.htaccess"<<EOF
	# BEGIN WordPress
	<IfModule mod_rewrite.c>
	RewriteEngine On
	RewriteBase /
	RewriteRule ^index\.php$ - [L]
	RewriteCond %{REQUEST_FILENAME} !-f
	RewriteCond %{REQUEST_FILENAME} !-d
	RewriteRule . /index.php [L]
	</IfModule>
	
	<files wp-config.php>
	order allow,deny
	deny from all
	</files>
	# END WordPress
EOF


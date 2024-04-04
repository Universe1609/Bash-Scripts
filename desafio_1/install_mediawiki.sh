#!/bin/bash

#Escribe un script en Bash que automatice la instalación de phpMyAdmin como herramienta de administración de bases de datos en un servidor Ubuntu que ya tiene MediaWiki instalado. El script debe realizar las siguientes tareas:

#Instalar phpMyAdmin desde los repositorios predeterminados de Ubuntu.
#Configurar phpMyAdmin para que funcione con el servidor web (por ejemplo, Apache).
#Realizar cualquier otra configuración necesaria para que phpMyAdmin funcione correctamente junto con MediaWiki.

read -sp "Please enter database password: " DB_PASS
echo " "

PMA_DIR="/etc/phpmyadmin"
DB_USER="wikiuser"

#Check if Open ssl is installed


#Chec if Apache is installed
if dpkg -l | grep -qw apache2; then
        echo "Apache is installed"
else
        echo "Apache is not installed. installing apache and others packages like mariadb, php, libapache2, etc"
        sudo apt update
       	sudo apt install apache2 mariadb-server php php-mysql libapache2-mod-php php-xml php-mbstring php-intl -y
fi

#Check if database is installed, already up and with a user to use for phpadmin
if dpkg -l | grep -qw mariadb-server; then
	echo "Mariadb database installed"
	
	read -sp "Enter db root password: " DB_ROOT_PASS

	if echo "SELECT User FROM mysql.user WHERE User='$DB_USER';" | mysql -u root -p"$DB_ROOT_PASS" 2>/dev/null | grep -qw $DB_USER; then
		echo "User for phpmyadmin is configured"
	else
		echo "Please configure a user"
	fi
else
	echo "Please configurate database with a user for phpadmin"
fi

#Check if mediawiki is installed
if [ -f "/var/www/mediawiki/LocalSettings.php" ]; then
    echo "MediaWiki appears to be installed."
else
    echo "MediaWiki does not appear to be installed."
    echo "Installing"
    cd /tmp/
    wget https://releases.wikimedia.org/mediawiki/1.41/mediawiki-1.41.1.tar.gz
    tar -xvzf /tmp/mediawiki-*.tar.gz
    sudo mkdir /var/lib/mediawiki
    sudo mv mediawiki-*/* /var/lib/mediawiki
    sudo ln -s /var/lib/mediawiki /var/www/html/mediawiki
fi


# Install PHPMyAdmin
if dpkg -l | grep -qw phpmyadmin; then
        echo "phpMyAdmin is already installed"
else
        echo "phpMyAdmin is not installed, installing"
        sudo apt install phpmyadmin -y
fi


# Configure Apache for PHP Myadmin
echo "Configuring Apache for PhpAdmin"
sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin.conf
sudo systemctl reload apache2.service

if [ -f "$PMA_DIR/config.inc.php" ]; then
        sed -i "s|\$cfg\['Servers'\]\[\$i\]\['host'\] = 'localhost'.*|\$cfg\['Servers'\]\[\$i\]\['host'\] = 'localhost';|" "$PMA_DIR/config.inc.php"

        sed -i "/\['host'\] = 'localhost'/a \$cfg['Servers'][\$i]['user'] = '$DB_USER';" "$PMA_DIR/config.inc.php"

        sed -i "/\['user'\] = '$DB_USER'/a \$cfg['Servers'][\$i]['password'] = '$DB_PASS';" "$PMA_DIR/config.inc.php"
else
        echo "PHP configuration file not found"
fi

echo "phpMyAdmin installation is completed, also configuration."

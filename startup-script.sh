#!/bin/bash

# sudo apt-get update
# sudo apt-get install -y apache2 unzip awscli jq
# sudo apt-get install -y php7.2-mbstring php7.2-xml
# sudo apt-get install -y php7.2 libapache2-mod-php7.2 php7.2-mysql \
#   php7.2-gd php7.2-intl php7.2-imap php7.2-tidy php7.2-xmlrpc \
#   php7.2-xsl php7.2-mbstring php7.2-zip php7.2-xml

# sudo a2enmod rewrite
# sudo systemctl restart apache2
# curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

param="EBRYX.COM_DEPLOYMENT_PROD"
echo "Fetching parameter [$param] from SSM..."

# In case region needs to be fetched for EC2 machine.
# EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
# EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

aws ssm get-parameters --name $param --region us-east-2 | jq -r '.Parameters[].Value' > /tmp/config
source /tmp/config
rm -f /tmp/config

if [[ -z $EBRYX_CODE || -z $EBRYX_ENV ]]; then
  echo "EBRYX_CODE and EBRYX_ENV variables are required."
  exit 1
fi

mkdir -p /var/www/html/
rootPath="/var/www/html/website"

if [[ -d $rootPath/ ]]; then
  echo "Deleting old dir: $rootPath/"
  sudo rm -rf $rootPath/
fi

echo "Fetching code from [$EBRYX_CODE]..."
sudo aws s3 cp "$EBRYX_CODE" ./
sudo unzip "$(basename "$EBRYX_CODE")" -d $rootPath/
sudo rm "$(basename "$EBRYX_CODE")"

echo "Finding complete path to public dir..."
filePath="$(find $rootPath/ -type f -name '.htaccess')"
if [[ -z $filePath ]]; then
  echo "Could not find .htaccess file in dir: $rootPath/"
  echo "Assuming public dir as: $rootPath/public/"
  dirPath="$rootPath/public/"
else
  dirPath="$(dirname "$filePath")"
  echo ".htaccess file found: $filePath"
  echo "Path to public dir is: $dirPath"
fi

echo "Changing directory to: $rootPath/"
cd $rootPath/

echo "Fetching env from [$EBRYX_ENV]..."
sudo aws s3 cp "$EBRYX_ENV" .env

if [[ ! -z $EBRYX_IMAGES ]]; then
  sudo aws s3 cp "$EBRYX_IMAGES" ./
  echo "Unzipping images to: $dirPath/uploads/"
  sudo unzip "$(basename "$EBRYX_IMAGES")" -d "$dirPath/uploads/"
  sudo rm "$(basename "$EBRYX_IMAGES")"
else
  echo "EBRYX_IMAGES not provided. Skipping image fetch..."
fi

defaultConfig="/etc/apache2/sites-enabled/000-default.conf"
# if [[ -f $defaultConfig ]]; then
#   echo "Updating file: [$defaultConfig]"
#   sudo sed -i "/DocumentRoot /c\\\tDocumentRoot $dirPath" "$defaultConfig"
# fi
# echo "Clearing directory: "$(dirname "$defaultConfig")"/*"
# sudo rm "$(dirname "$defaultConfig")"/*

echo "Writing to file: [$defaultConfig]"
echo "<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot $dirPath

  <Directory /var/www/html>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
	</Directory>

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" | sudo tee "$defaultConfig" > /dev/null

echo "Installing plugins using composer..."
sudo composer install
sudo php artisan key:generate

echo "Applying migration and seeding..."
# duplicate entries will return non-zero status. OR it to avoid non-zero status.
sudo php artisan migrate --force
sudo php artisan db:seed --force || :

# file permissions for laravel
echo "Updating file permissions..."
sudo chown -R www-data:www-data ./
sudo find ./ -type f -exec chmod 644 {} \;
sudo find ./ -type d -exec chmod 755 {} \;
sudo chgrp -R www-data storage bootstrap/cache
sudo chmod -R ug+rwx storage bootstrap/cache

appProvider="$dirPath/../app/Providers/AppServiceProvider.php"
if [[ -f $appProvider ]]; then
  echo "Forcing HTTP schema in code..."
  sudo sed -i "s|//|\\\URL::forceSchema('https');|g" $appProvider
fi

echo "Restarting apache2 service..."
sudo systemctl restart apache2


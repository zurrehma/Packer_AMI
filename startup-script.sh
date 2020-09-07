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

param="VAR_NAME"
echo "Fetching parameter [$param] from SSM..."

# In case region needs to be fetched for EC2 machine.
# EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
# EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

aws ssm get-parameters --name $param --region us-east-2 | jq -r '.Parameters[].Value' > /tmp/config
source /tmp/config
rm -f /tmp/config


mkdir -p /var/www/html/
rootPath="/var/www/html/website"

if [[ -d $rootPath/ ]]; then
  echo "Deleting old dir: $rootPath/"
  sudo rm -rf $rootPath/
fi

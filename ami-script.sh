#!/bin/bash -e
#set -e
# Update the system to the latest repositories and clean the downloaded binaries
sudo echo 'export DEBIAN_FRONTEND=noninteractive' >> /etc/environment
source /etc/environment
sudo rm -r /var/lib/apt/lists/*
echo '[Update the system to the latest repositories and clean the downloaded binaries]'
sudo apt-get update -y && sudo apt-get upgrade -y && \
sudo apt-get autoclean -y && sudo apt-get autoremove -y
# Make sure only root has the UID of 0
echo '[Making sure only root has the UID of 0]'
awk -F: '($3=="0"){print}' /etc/passwd
# Lock unnecessary accounts and add a custom new user
if [[ $accountName ]]; then
  echo '[Lock unnecessary accounts and add a custom new user]'
  passwd -l $accountName
  adduser $accuntName
fi
# Enable unattended updates
echo '[Enable unattended updates]'
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades -p critical dash	
sudo systemctl restart sshd
# Install fail2ban
echo '[Installing fail2ban]'
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
# Edit /etc/fail2ban/jail.local and make the following entries
# enabled = true
# port = 22
# filter = sshd
# logpath = /var/log/auth.log
# maxretry = 3
echo '[Editing /etc/fail2ban/jail.local]'
sed -i 's/^port.*=.*/port = 22/g' /etc/fail2ban/jail.local
sed -i 's/^enabled.*=.*/enabled = true/g' /etc/fail2ban/jail.local
sed -i 's/^filter.*=.*/filter = sshd/g' /etc/fail2ban/jail.local
sed -i 's/^maxretry.*=.*/maxretry = 3/g' /etc/fail2ban/jail.local
sed -i 's/^logpath.*=.*/logpath = \/var\/log\/auth.log/g' /etc/fail2ban/jail.local
# Enable and restart fail2ban
echo '[Enabling and restarting fail2ban]'
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo systemctl status fail2ban
# Install auditd
echo '[Installing auditd]'
sudo apt-get install auditd -y
# Enable Command-Line logging
echo '[Enabling Command-Line logging]'
sudo echo -e 'function log2syslog \n{ \ndeclare COMMAND \nCOMMAND=$(fc -ln -0)
logger -p local1.notice -t bash -i -- "${USER}:${COMMAND}" \n} \ntrap log2syslog DEBUG' >> /etc/profile
sudo echo -e '# command line audit logging \nlocal1.* -/var/log/cmdline' >> /etc/rsyslog.conf
sudo /etc/init.d/rsyslog restart
# secure shared memory
echo '[secure shared memory]'
sudo echo 'none /run/shm tmpfs defaults,ro 0 0' >> /etc/fstab
# Disable apport service
sudo systemctl disable apport
sudo systemctl stop apport
# Install apache2
sudo apt-get update
sudo apt-get install -y apache2 unzip awscli jq
sed -i '/.*<Directory \/var\/www\/>/,+4 s/^/#/' /etc/apache2/apache2.conf
# Install mod_security and mod_evasive
sudo apt-get install libapache2-mod-security2 -y
sudo apt-get install libapache2-mod-evasive -y
sudo apt-add-repository ppa:ondrej/php
sudo apt-get update -y
sudo apt-get install -y php7.2-mbstring php7.2-xml
sudo apt-get install -y php7.2 libapache2-mod-php7.2 php7.2-mysql \
  php7.2-gd php7.2-intl php7.2-imap php7.2-tidy php7.2-xmlrpc \
  php7.2-xsl php7.2-mbstring php7.2-zip php7.2-xml
sudo a2enmod rewrite
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
sudo systemctl restart apache2
# Setup logging
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt-get update && sudo apt-get install filebeat
sudo systemctl enable filebeat
sudo cp /tmp/filebeat.yml /etc/filebeat/filebeat.yml
sudo filebeat modules enable apache mysql auditd iptables
# Configure the IPTABLES to accept incoming connections only at port 22,80,443 and from loopback address.
echo '[Configure the IPTABLES to accept incoming connections only at port 22,80,443 and from loopback address.]'
sudo iptables -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p udp -m udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -j DROP

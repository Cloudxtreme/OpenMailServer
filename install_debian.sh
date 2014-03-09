#!/usr/bin/env bash
#
# Author:   Matt Jones <matt@azmatt.co.uk>
#
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Matt Jones
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# Check for root
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 2>&1
	exit 1
fi

# Do updates
apt-get update
apt-get upgrade

# Install random password generator
apt-get -y install apg

clear

echo "Please enter the hostname you would like for this server ($(cat /etc/hostname)): "
read HOSTNAME
if [[ "${HOSTNAME}" != "" ]]; then
	echo "Setting hostname"
	echo ${HOSTNAME} > /etc/hostname
	hostname ${HOSTNAME}
fi


#
# Set up global variables
#
echo "Generating secure MySQL root password... please wait."
MYSQL_ROOT_PASS=`create_password`

echo "Generating secure MySQL postfix password... please wait."
MYSQL_POSTFIX_USER=postfix
MYSQL_POSTFIX_PASS=`create_password`
MYSQL_POSTFIX_DB=postfix

VMAIL_USER=vmail
VMAIL_HOME=/home/vmail

#
# Add vmail user
#
sudo groupadd -g 5000 ${VMAIL_USER}
sudo useradd -m -g ${VMAIL_USER} -u 5000 -d ${VMAIL_HOME} -s /bin/bash ${VMAIL_USER}

#
# Generate and set MySQL passwords
#
echo "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASS}" | debconf-set-selections 
echo "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASS}" | debconf-set-selections 


#
# Set initial postfix settings for unattended install
#
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string localhost" | debconf-set-selections
echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections


#
# Install required packages
#
apt-get -y install openssl apache2 php5 postfix-tls postfix-mysql libsasl2 libsasl2-modules dovecot-common dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-managesieved dovecot-sieve mysql-server spamassassin clamav amavisd-new


#
# Creating MySQL users & structure
#
mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "GRANT SELECT, INSERT, DELETE, UPDATE ON ${MYSQL_POSTFIX_DB}.* TO ${MYSQL_POSTFIX_USER}@localhost IDENTIFIED BY '${MYSQL_POSTFIX_PASSWORD}'";
mysql -uroot -p"${MYSQL_ROOT_PASS}" ${MYSQL_POSTFIX_DB} < ./conf/mysql/postfix.sql


#
# Copy config files to locations
#
if  [ -f /etc/postfix/main.cf ]; then
	mv /etc/postfix/main.cf /etc/postfix/main.cf.backup 
fi

if  [ -f /etc/postfix/master.cf ]; then
	mv /etc/postfix/master.cf /etc/postfix/master.cf.backup 
fi

cp ./conf/postfix/main.cf /etc/postfix/main.cf
cp ./conf/postfix/master.cf /etc/postfix/master.cf
cp ./conf/postfix/mysql_virtual_domains_maps.cf /etc/postfix/mysql_virtual_domains_maps.cf
cp ./conf/postfix/mysql_virtual_mailbox_maps.cf /etc/postfix/mysql_virtual_mailbox_maps.cf
cp ./conf/postfix/mysql_virtual_mailbox_limit_maps.cf /etc/postfix/mysql_virtual_mailbox_limit_maps.cf
cp ./conf/postfix/mysql_virtual_alias_maps.cf /etc/postfix/mysql_virtual_alias_maps.cf
cp ./conf/postfix/mysql_relay_domains_maps.cf /etc/postfix/mysql_relay_domains_maps.cf
cp ./conf/postfix/sasl/smtpd.conf /etc/postfix/sasl/smtpd.conf


#
# Secure config files
#
chgrp postfix /etc/postfix/mysql_*.cf
chmod 640 /etc/postfix/mysql_*.cf


#
# Replace placeholder strings with real values
#
sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/postfix/*.cf
sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/postfix/*.cf
sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/postfix/*.cf
sed -i "s/VMAIL_USER/${VMAIL_USER}/g" /etc/postfix/*.cf
sed -i "s/VMAIL_HOME/${VMAIL_HOME}/g" /etc/postfix/*.cf

sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/postfix/sasl/smtpd.conf
sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/postfix/sasl/smtpd.conf
sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/postfix/sasl/smtpd.conf
sed -i "s/VMAIL_USER/${VMAIL_USER}/g" /etc/postfix/sasl/smtpd.conf
sed -i "s/VMAIL_HOME/${VMAIL_HOME}/g" /etc/postfix/sasl/smtpd.conf

#
# Allow postfix to access sasl user group
#
usermod -G sasl postfix


#
# Generate transport maps
#
postmap /etc/postfix/transport


#
# Generate SSL keys
#
openssl req -new -x509 -newkey rsa:2048 -days 365 -keyout /etc/ssl/certs/server.key -out /etc/ssl/certs/server.crt
openssl rsa -in /etc/ssl/certs/server.key -out /etc/ssl/certs/server.key
chown nobody:nobody /etc/ssl/certs/server.key /etc/ssl/certs/server.crt
chmod 400 /etc/ssl/certs/server.key
chmod 444 /etc/ssl/certs/server.crt
mv /etc/ssl/certs/server.key /etc/ssl/private/
mv /etc/ssl/certs/server.crt /etc/ssl/private/

#
# Restart services
#


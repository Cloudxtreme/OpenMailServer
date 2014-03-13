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
apt-get -y upgrade

# Install random password generator
apt-get -y install apg

clear

#
# Set up global variables
#
echo "Generating secure MySQL root password... please wait."
MYSQL_ROOT_PASS=`create_password`

echo "Generating secure MySQL postfix password... please wait."
MYSQL_POSTFIX_USER=postfix
MYSQL_POSTFIX_PASS=`create_password`
MYSQL_POSTFIX_DB=postfix

echo "Generating secure MySQL amavis password... please wait."
MYSQL_AMAVIS_USER=amavis
MYSQL_AMAVIS_PASS=`create_password`
MYSQL_AMAVIS_DB=amavis

VMAIL_USER=vmail
VMAIL_GROUP=vmail
VMAIL_HOME=/home/vmail

SSL_COUNTRY_ISO2=GB
SSL_CITY=Leominster
SSL_STATE_PROVINCE=Herefordshire
SSL_CERT_FILE=/etc/ssl/private/server.crt
SSL_KEY_FILE=/etc/ssl/private/server.key


#
# Ask for hostname
#
echo "Please enter the hostname you would like for this server ($(hostname)): "
read HOSTNAME
if [[ "${HOSTNAME}" != "" ]]; then
	echo "Setting hostname"
	echo ${HOSTNAME} > /etc/hostname
	echo ${HOSTNAME} > /etc/mailname
	hostname ${HOSTNAME}
else
	echo "Leaving hostname unchanged"
	HOSTNAME="$(hostname)"
fi


#
# Generate SSL keys
#
openssl req \
	-x509 -nodes -days 3650 -newkey rsa:2048 \
	-subj "/C=${SSL_COUNTRY_ISO2}/ST=${SSL_STATE_PROVINCE}/L=${SSL_CITY}/O=${HOSTNAME}/OU=IT/CN=${HOSTNAME}/emailAddress=root@${HOSTNAME}/" \
	-out ${SSL_CERT_FILE} -keyout ${SSL_KEY_FILE}

# Set correct file permission.
chmod 0444 ${SSL_CERT_FILE}
chmod 0444 ${SSL_KEY_FILE}


#
# Add vmail user
#
sudo groupadd -g 5000 ${VMAIL_GROUP}
sudo useradd -m -g ${VMAIL_GROUP} -u 5000 -d ${VMAIL_HOME} -s /bin/bash ${VMAIL_USER}


#
# Generate and set MySQL passwords for unattended install
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
apt-get -y install openssl apache2 php5 postfix-mysql libsasl2-modules dovecot-common dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-managesieved dovecot-sieve mysql-server amavisd-new spamassassin clamav-daemon libnet-dns-perl pyzor razor arj bzip2 cabextract cpio file gzip nomarch pax rar unrar unzip zip zoo


#
# Creating MySQL users & structure
#
mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "GRANT SELECT, INSERT, DELETE, UPDATE ON ${MYSQL_POSTFIX_DB}.* TO ${MYSQL_POSTFIX_USER}@localhost IDENTIFIED BY '${MYSQL_POSTFIX_PASS}';";
mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE ${MYSQL_POSTFIX_DB};"
mysql -uroot -p"${MYSQL_ROOT_PASS}" ${MYSQL_POSTFIX_DB} < ./conf/mysql/postfix.sql

mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "GRANT SELECT, INSERT, DELETE, UPDATE ON ${MYSQL_AMAVIS_DB}.* TO ${MYSQL_AMAVIS_USER}@localhost IDENTIFIED BY '${MYSQL_AMAVIS_PASS}';";
mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE ${MYSQL_AMAVIS_DB};"
mysql -uroot -p"${MYSQL_ROOT_PASS}" ${MYSQL_AMAVIS_DB} < ./conf/mysql/amavis.sql

# We need to create a new view to allow a list of domains in the amavis DB
#mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "CREATE VIEW ${MYSQL_AMAVIS_DB}.vmail_domain AS SELECT DOMAIN FROM ${MYSQ_POSTFIX_DB}.domain";
#mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "GRANT SELECT ON ${MYSQL_POSTFIX_DB}.* TO ${MYSQL_AMAVIS_USER}@localhost;"
# Commented this out for the moment because amavis is expecting a list of policy rules which we dont have at the moment


#
# Configure postfix
#
if [ -f /etc/postfix/main.cf ]; then
	mv /etc/postfix/main.cf /etc/postfix/main.cf.backup 
fi

if [ -f /etc/postfix/master.cf ]; then
	mv /etc/postfix/master.cf /etc/postfix/master.cf.backup 
fi

cp ./conf/postfix/main.cf /etc/postfix/main.cf
cp ./conf/postfix/master.cf /etc/postfix/master.cf

cp ./conf/postfix/mysql_catch_all_maps.cf /etc/postfix/mysql_catch_all_maps.cf
cp ./conf/postfix/mysql_domain_alias_catchall_maps.cf /etc/postfix/mysql_domain_alias_catchall_maps.cf
cp ./conf/postfix/mysql_domain_alias_maps.cf /etc/postfix/mysql_domain_alias_maps.cf
cp ./conf/postfix/mysql_recipient_bcc_maps_domain.cf /etc/postfix/mysql_recipient_bcc_maps_domain.cf
cp ./conf/postfix/mysql_recipient_bcc_maps_user.cf /etc/postfix/mysql_recipient_bcc_maps_user.cf
cp ./conf/postfix/mysql_relay_domains_maps.cf /etc/postfix/mysql_relay_domains_maps.cf
cp ./conf/postfix/mysql_sender_bcc_maps_domain.cf /etc/postfix/mysql_sender_bcc_maps_domain.cf
cp ./conf/postfix/mysql_sender_bcc_maps_user.cf /etc/postfix/mysql_sender_bcc_maps_user.cf
cp ./conf/postfix/mysql_sender_login_maps.cf /etc/postfix/mysql_sender_login_maps.cf
cp ./conf/postfix/mysql_transport_maps_user.cf /etc/postfix/mysql_transport_maps_user.cf
cp ./conf/postfix/mysql_transport_maps_domain.cf /etc/postfix/mysql_transport_maps_domain.cf
cp ./conf/postfix/mysql_virtual_alias_maps.cf /etc/postfix/mysql_virtual_alias_maps.cf
cp ./conf/postfix/mysql_virtual_domains_maps.cf /etc/postfix/mysql_virtual_domains_maps.cf
cp ./conf/postfix/mysql_virtual_mailbox_maps.cf /etc/postfix/mysql_virtual_mailbox_maps.cf


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
sed -i "s=VMAIL_USER=${VMAIL_USER}=g" /etc/postfix/*.cf
sed -i "s=VMAIL_GROUP=${VMAIL_GROUP}=g" /etc/postfix/*.cf
sed -i "s=VMAIL_HOME=${VMAIL_HOME}=g" /etc/postfix/*.cf
sed -i "s=SSL_CERT_FILE=${SSL_CERT_FILE}=g" /etc/postfix/*.cf
sed -i "s=SSL_KEY_FILE=${SSL_KEY_FILE}=g" /etc/postfix/*.cf


#
# Configure sasl
#
#mkdir -p /var/spool/postfix/var/run/saslauthd
#usermod -G sasl postfix
#cp ./conf/postfix/sasl/smtpd.conf /etc/postfix/sasl/smtpd.conf
#cp ./conf/postfix/sasl/saslauthd /etc/default/saslauthd

#sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/postfix/sasl/smtpd.conf
#sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/postfix/sasl/smtpd.conf
#sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/postfix/sasl/smtpd.conf
#sed -i "s=VMAIL_USER=${VMAIL_USER}=g" /etc/postfix/sasl/smtpd.conf
#sed -i "s=VMAIL_GROUP=${VMAIL_GROUP}=g" /etc/postfix/sasl/smtpd.conf
#sed -i "s=VMAIL_HOME=${VMAIL_HOME}=g" /etc/postfix/sasl/smtpd.conf



#
# Configure Dovecot
#
if [ -f /etc/dovecot/dovecot.conf ]; then
	mv /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.backup 
fi

if [ -f /etc/dovecot/dovecot-sql.conf.ext ]; then
	mv /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.backup
fi

if [ -f /etc/dovecot/conf.d/10-auth.conf ]; then
	mv /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.backup 
fi

if [ -f /etc/dovecot/conf.d/10-mail.conf ]; then
	mv /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.backup 
fi

if [ -f /etc/dovecot/conf.d/10-master.conf ]; then
	mv /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.backup 
fi

if [ -f /etc/dovecot/conf.d/10-ssl.conf ]; then
	mv /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.backup 
fi

if [ -f /etc/dovecot/conf.d/auth-sql.conf.ext ]; then
	mv /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/auth-sql.conf.ext.backup
fi

cp ./conf/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
cp ./conf/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf
cp ./conf/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf
cp ./conf/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf
cp ./conf/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
cp ./conf/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/auth-sql.conf.ext
cp ./conf/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext


#
# Replace placeholder strings with real values
#
sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/dovecot/*.{conf,ext}
sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/dovecot/*.{conf,ext}
sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/dovecot/*.{conf,ext}
sed -i "s=VMAIL_USER=${VMAIL_USER}=g" /etc/dovecot/*.{conf,ext}
sed -i "s=VMAIL_GROUP=${VMAIL_GROUP}=g" /etc/dovecot/*.{conf,ext}
sed -i "s=VMAIL_HOME=${VMAIL_HOME}=g" /etc/dovecot/*.{conf,ext}
sed -i "s=SSL_CERT_FILE=${SSL_CERT_FILE}=g" /etc/dovecot/*.{conf,ext}
sed -i "s=SSL_KEY_FILE=${SSL_KEY_FILE}=g" /etc/dovecot/*.{conf,ext}

sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s=VMAIL_USER=${VMAIL_USER}=g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s=VMAIL_GROUP=${VMAIL_GROUP}=g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s=VMAIL_HOME=${VMAIL_HOME}=g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s=SSL_CERT_FILE=${SSL_CERT_FILE}=g" /etc/dovecot/conf.d/*.{conf,ext}
sed -i "s=SSL_KEY_FILE=${SSL_KEY_FILE}=g" /etc/dovecot/conf.d/*.{conf,ext}


# Secure config files
chgrp vmail /etc/dovecot/*.conf
chgrp vmail /etc/dovecot/conf.d/
chgrp vmail /etc/dovecot/conf.d/*.{conf,ext}
chmod 640 /etc/dovecot/*.conf
chmod 640 /etc/dovecot/conf.d/*.{conf,ext}


#
# Configure ClamAV / Amavis
#
cp ./conf/amavis/conf.d/50-user /etc/amavis/conf.d/50-user
sed -i "s/HOSTNAME/${HOSTNAME}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_POSTFIX_USER/${MYSQL_POSTFIX_USER}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_POSTFIX_PASS/${MYSQL_POSTFIX_PASS}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_POSTFIX_DB/${MYSQL_POSTFIX_DB}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_AMAVIS_USER/${MYSQL_AMAVIS_USER}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_AMAVIS_PASS/${MYSQL_AMAVIS_PASS}/g" /etc/amavis/conf.d/50-user
sed -i "s/MYSQL_AMAVIS_DB/${MYSQL_AMAVIS_DB}/g" /etc/amavis/conf.d/50-user

# Secure config files
chgrp vmail /etc/amavis/conf.d/*
chmod 640 /etc/amavis/conf.d/*

# Add users
adduser clamav amavis
adduser amavis clamav


#
# Configure spamassassin
#
sed -i "s/ENABLED=0/ENABLED=1/g" /etc/default/spamassassin
sed -i "s/CRON=0/CRON=1/g" /etc/default/spamassassin


#
# Restart services
#
#service saslauthd restart
service postfix restart
service dovecot restart
service amavis restart
service clamav-daemon start

#
# Save important vars to installations.txt
#
cat > installation.txt <<EOF

MYSQL_ROOT_PASS		= ${MYSQL_ROOT_PASS}

MYSQL_POSTFIX_USER	= ${MYSQL_POSTFIX_USER}
MYSQL_POSTFIX_PASS	= ${MYSQL_POSTFIX_PASS}
MYSQL_POSTFIX_DB	= ${MYSQL_POSTFIX_DB}

MYSQL_AMAVIS_USER	= ${MYSQL_AMAVIS_USER}
MYSQL_AMAVIS_PASS	= ${MYSQL_AMAVIS_PASS}
MYSQL_AMAVIS_DB		= ${MYSQL_AMAVIS_DB}

VMAIL_USER			= ${VMAIL_USER}
VMAIL_GROUP			= ${VMAIL_GROUP}
VMAIL_HOME			= ${VMAIL_HOME}

SSL_COUNTRY_ISO2	= ${SSL_COUNTRY_ISO2}
SSL_CITY			= ${SSL_CITY}
SSL_STATE_PROVINCE	= ${SSL_STATE_PROVINCE}
SSL_CERT_FILE		= ${SSL_CERT_FILE}
SSL_KEY_FILE		= ${SSL_KEY_FILE}

EOF

chmod 600 installation.txt


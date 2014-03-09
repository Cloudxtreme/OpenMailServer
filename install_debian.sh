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
	echo “This script must be run as root” 2>&1
	exit 1
fi

# Do updates
apt-get update
apt-get upgrade

# Install random password generator
apt-get -y install apg

# Install required packages
apt-get -y install apache2 php5 postfix-mysql dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-managesieved dovecot-sieve mysql-server spamassassin clamav

# Copy config files to locations

# Set up database structure

# Restart services
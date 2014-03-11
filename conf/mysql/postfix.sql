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
# LIABILITY, 



#
# Table structure for table admin
#
CREATE TABLE admin (
  username varchar(255) NOT NULL default '',
  password varchar(255) NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  modified datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (username),
  KEY username (username)
) COMMENT='Postfix Admin - Virtual Admins';

#
# Table structure for table alias
#
CREATE TABLE alias (
  address varchar(255) NOT NULL default '',
  goto text NOT NULL,
  domain varchar(255) NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  modified datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (address),
  KEY address (address)
) COMMENT='Postfix Admin - Virtual Aliases';

#
# Table structure for table alias domain
#
CREATE TABLE IF NOT EXISTS `alias_domain` (
    alias_domain VARCHAR(255) NOT NULL,
    target_domain VARCHAR(255) NOT NULL,
    created DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    modified DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (alias_domain),
    INDEX (target_domain),
    INDEX (active)
) ENGINE=MyISAM;

#
# Table structure for table domain
#
CREATE TABLE domain (
  domain varchar(255) NOT NULL default '',
  description varchar(255) NOT NULL default '',
  aliases int(10) NOT NULL default '0',
  mailboxes int(10) NOT NULL default '0',
  maxquota int(10) NOT NULL default '0',
  transport VARCHAR(255) NOT NULL DEFAULT 'dovecot',
  backupmx tinyint(1) NOT NULL default '0',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  modified datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  sender_bcc VARCHAR(255) NOT NULL DEFAULT '',
  recipient_bcc VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (domain),
  KEY domain (domain)
) COMMENT='Postfix Admin - Virtual Domains';

#
# Table structure for table domain_admins
#
CREATE TABLE domain_admins (
  username varchar(255) NOT NULL default '',
  domain varchar(255) NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  KEY username (username)
) COMMENT='Postfix Admin - Domain Admins';

#
# Table structure for table log
#
CREATE TABLE log (
  timestamp datetime NOT NULL default '0000-00-00 00:00:00',
  username varchar(255) NOT NULL default '',
  domain varchar(255) NOT NULL default '',
  action varchar(255) NOT NULL default '',
  data varchar(255) NOT NULL default '',
  KEY timestamp (timestamp)
) COMMENT='Postfix Admin - Log';

#
# Table structure for table mailbox
#
CREATE TABLE mailbox (
  username varchar(255) NOT NULL default '',
  password varchar(255) NOT NULL default '',
  name varchar(255) NOT NULL default '',
  maildir varchar(255) NOT NULL default '',
  quota int(10) NOT NULL default '0',
  domain varchar(255) NOT NULL default '',
  transport VARCHAR(255) NOT NULL DEFAULT 'dovecot',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  modified datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  sender_bcc VARCHAR(255) NOT NULL DEFAULT '',
  recipient_bcc VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY  (username),
  KEY username (username)
) COMMENT='Postfix Admin - Virtual Mailboxes';

#
# Table structure for table vacation
#
CREATE TABLE vacation (
  email varchar(255) NOT NULL default '',
  subject varchar(255) NOT NULL default '',
  body text NOT NULL,
  cache text NOT NULL,
  domain varchar(255) NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  active tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (email),
  KEY email (email)
) COMMENT='Postfix Admin - Virtual Vacation';
#------------------------------------End copy-------------------------------------
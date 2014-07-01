#!/bin/bash

if [ ! -d /var/lib/mysql/mysql ]; then
  mysql_install_db > /dev/null 2>&1
fi

exec mysqld_safe

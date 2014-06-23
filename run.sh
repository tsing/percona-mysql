#!/bin/bash

. path.ini

mkdir -p $HOME/data
mkdir -p $HOME/log

if [ ! -d $HOME/data/mysql ]; then
  docker run --rm -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql mysql_install_db
  cid=`docker run -d -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql`
  pid=`docker top $cid|head -2|tail -1|awk '{print $2}'`
  sleep 5
  nsexec $pid sh -c 'mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME \"libmurmur_udf.so\""'
  nsexec $pid sh -c 'mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME \"libfnv1a_udf.so\""'
  nsexec $pid sh -c 'mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME \"libfnv_udf.so\""'
else
  docker run -d -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql
fi


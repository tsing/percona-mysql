#!/bin/bash

. path.ini

mkdir -p $HOME/data
mkdir -p $HOME/log

docker run --rm -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql mysql_install_db
docker run -d -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql

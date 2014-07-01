#!/bin/bash

get_sid() {
  cdir=`dirname $0`
  cd $cdir/..
  tdir=`pwd`
  sid=`basename $tdir`
  echo $sid
}

sid=`get_sid`
if docker ps|grep -q $sid; then
  /usr/local/bin/nicedocker exec $sid mysqladmin --no-defaults shutdown
else
  echo "Service $sid not running."
fi

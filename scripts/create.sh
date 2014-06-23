#!/bin/bash

# create.sh is for some cluster service, for example,when we
# add a new slave to mysql cluster, we should tell this slave
# to find masterhost, execute change master to ...
#
# if this service need not, delete it.

NICEDOCKER=/usr/local/bin/nicedocker

get_sid() {
  cdir=`dirname $0`
  cd $cdir/..
  tdir=`pwd`
  if [ -f $tdir/admin/service.ini ]; then
    . $tdir/admin/service.ini
  else
    echo "failed to get service id"
    exit 1
  fi
}

nicescale_env() {
  test -f /etc/.fp/csp.conf
}

nicescale_env || exit 0

get_sid
sid=$SERVICE_ID

DOCKEREXEC="$NICEDOCKER exec $sid"
RUBY=/opt/nicescale/support/bin/ruby

REPL_USER=repl
#MYSOCKET=/var/run/mysqld/mysqld.sock

function create_user_repl() {
  echo "GRANT REPLICATION SLAVE,REPLICATION CLIENT,RELOAD ON *.* TO '$REPL_USER'@'%'IDENTIFIED BY '$REPL_PASSWD';" > /services/$sid/data/create_user_repl.sql
  $DOCKEREXEC sh -c "mysql -f -u root < /var/lib/mysql/create_user_repl.sql"
  /bin/rm /services/$sid/data/create_user_repl.sql
}

function mysql_install_db() {
  image=`docker ps|grep $sid|awk '{print $2}'`
  docker stop $sid
  docker run --rm -v /services/$sid/data:/var/lib/mysql -v /services/$sid/log:/var/log/mysql $image /usr/bin/mysql_install_db
  docker start $sid
  sleep 3
  $DOCKEREXEC sh -c 'mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME \"libmurmur_udf.so\""'
  $DOCKEREXEC sh -c 'mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME \"libfnv1a_udf.so\""'
  $DOCKEREXEC sh -c 'mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME \"libfnv_udf.so\""'
}

function change_to_master() {
  echo "lock master $mip..."
  $DOCKEREXEC sh -c "mysql -h$mip -P$mport -u$REPL_USER -p$REPL_PASSWD -e 'flush tables with read lock'"
  echo "get master status ..."
  m_tmp=`$DOCKEREXEC sh -c "mysql -h$mip -P$mport -u$REPL_USER -p$REPL_PASSWD -e 'show master status\G'"|head -3|tail -2|awk '{print $2}'`
  mfile=`echo $m_tmp | awk '{print $1}'`
  [ -z "$mfile" ] && echo "Failed to get master binlog file." && exit 1
  echo "master binlog file: $mfile"
  mpos=`echo $m_tmp | awk '{print $2}'`
  echo "master position: $mpos"
  [ -z "$mpos" ] && echo "Failed to get master position offset." && exit 1
  echo "slave begin to change master..."
  echo "stop slave;" > /services/$sid/data/change_master.sql
  echo "CHANGE MASTER TO MASTER_HOST='$mip', MASTER_PORT=$mport, MASTER_USER='$REPL_USER', MASTER_PASSWORD='$REPL_PASSWD', MASTER_LOG_FILE='$mfile', MASTER_LOG_POS=$mpos;" >> /services/$sid/data/change_master.sql
  echo "start slave;" >> /services/$sid/data/change_master.sql
  $DOCKEREXEC sh -c "mysql -u root < /var/lib/mysql/change_master.sql"
  es=$?
  if [ $es -eq 0 ]; then echo "change master ok."
  else echo "change master failed."
  fi
  /bin/rm /services/$sid/data/change_master.sql
  echo "unlock master $mip..."
  $DOCKEREXEC sh -c "mysql -h$mip -P$mport -u$REPL_USER -p$REPL_PASSWD -e 'unlock tables'"
  return $es
}

# if return false, then do nothing, if get master, then do change master to
msid_ruby="require 'fp/node';
cid=FP::Vars.get_service_var('$sid', 'cluster_id', 'meta');
if cid == 'null'; puts 'single';
else
  msid = FP::Vars.get_cluster_var(cid, 'master', 'service_id', 'meta');
  puts msid;
end
"
msid=`$RUBY -e "$msid_ruby"`
if [ -n "$msid" ]; then
  REPL_PASSWD=`echo $msid|md5sum|cut -c 1-10`
  mip_ruby="require 'fp/node';puts FP::Vars.get_auto_var_by_service('$msid', 'ips')"
  mport_ruby="require 'fp/node'; puts FP::Vars.get_global_var_by_service('$msid', 'port', 'mysql')"
fi

mysql_install_db
if [ "$msid" = 'single' ]; then
  echo "single mysql"
elif [ "$msid" != "$sid" ]; then
  mip=`$RUBY -e "$mip_ruby"`
  mport=`$RUBY -e "$mport_ruby"`
  echo "I am slave, and get master ip:$mip, master port:$mport, changing to master..."
  while [ true ]; do
    ping -w2 $mip > /dev/null 2>&1 && break
    sleep 2
  done
  change_to_master
else 
  echo "I am master, my service id:$msid, grant user repl to replication, password is the first 10 of md5sum(master service id)"
  create_user_repl
fi

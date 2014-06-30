FROM  ubuntu:trusty
# choose 3306 for mysql user
RUN  groupadd mysql -g 3306
RUN  useradd mysql -u 3306 -g mysql -M -d /nonexistent -s /bin/false

# install mysql 
RUN  apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
RUN  echo 'deb http://repo.percona.com/apt trusty main' > /etc/apt/sources.list.d/percona.list
RUN  apt-get update
RUN  DEBIAN_FRONTEND=noninteractive apt-get -y install percona-server-server-5.6

ADD  . /opt/nicedocker

EXPOSE  3306

CMD  ["/usr/bin/mysqld_safe"]

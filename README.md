percona-mysql
=============

percona mysql for nicescale

Build
-----

  docker build -t nicescale/percona-mysql .


Run
-----

  . path.ini
  docker run -d -v $HOME/data:$data -v $HOME/log:$log nicescale/percona-mysql

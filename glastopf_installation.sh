#! /bin/bash

# ToDo: Fix errors:
#	* Database

GT_INSTALL_DIR="/opt/glastopf/"
APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

echo "deb http://ftp.debian.org/debian/ wheezy-backports main" >> /etc/apt/source.list

echo "Installing necessary packages"
$APT_CMD update
$APT_CMD $APT_OPTS install python python-openssl python-gevent libevent-dev python-dev build-essential make
$APT_CMD $APT_OPTS install python-argparse python-chardet python-requests python-sqlalchemy python-lxml
$APT_CMD $APT_OPTS install python-beautifulsoup python-pip python-dev python-setuptools
$APT_CMD $APT_OPTS install g++ git php5-common php5-cgi php5 php5-dev liblapack-dev gfortran
$APT_CMD $APT_OPTS install libxml2-dev libxslt-dev
$APT_CMD $APT_OPTS install libmysqlclient-dev
$APT_CMD $APT_OPTS install pwgen

PIP_CMD=$(which pip)

$PIP_CMD install --upgrade distribute

echo "Clonging into BFR and installing it"
cd /opt
git clone git://github.com/glastopf/BFR.git
cd BFR
phpize
./configure --enable-bfr
BFR_DIR=$( (make && make install) | tail -n1 | grep "Installing shared extensions:" | cut -d":" -f2 | tr -d ' ')

if [ ! -f /etc/php5/cgi/php.ini.bak ]; then
	echo "Backing up php.ini"
	cp /etc/php5/cgi/php.ini /etc/php5/cgi/php.ini.bak
fi

echo "zend_extension = ${BFR_DIR}bfr.so" >> /etc/php5/cgi/php.ini

echo "Installing glastopf"
$PIP_CMD install glastopf

echo "Upgradeing greenlet"
$PIP_CMD install --upgrade greenlet

echo "Creating glastopf directory and creating config files"
mkdir -p ${GT_INSTALL_DIR}
cd ${GT_INSTALL_DIR}
glastopf-runner &> /dev/null &
GT_PID=$!

# Install mysql and create mysql user
echo -e "Installing mysql-server for logging, remember password!"
read -p "Hit [ENTER] to continue."
$APT_CMD $APT_OPTS install mysql-server
mysql_pw=$(pwgen 30 1)
echo "CREATE DATABASE glastopf; GRANT ALL ON glastopf.* TO 'glastopf'@'localhost' IDENTIFIED BY '$mysql_pw'" | mysql -u root -h localhost -p

if [ ! -f ${GT_INSTALL_DIR}glastopf.cfg.bak ]; then
	echo "Backing up glastopf.cfg"
	cp ${GT_INSTALL_DIR}glastopf.cfg ${GT_INSTALL_DIR}glastopf.cfg.bak
fi

# Edit config
echo "Manipulating config"
# 1. Turn of console-logging
sed -i "s/\(consolelog_enabled *= *\).*/\1False/" ${GT_INSTALL_DIR}glastopf.cfg 

# 2. Enable mysql logging
# Currently not working beacause of "ValueError: sample larger than population"
#sed -i "s/\(connection_string *= *\).*/\1mysql:\/\/glastopf:$mysql_pw@localhost\/glastopf/" ${GT_INSTALL_DIR}glastopf.cfg

cat > /etc/init.d/glastopf <<EOF
#!/bin/bash

# Author: Miguel Cabrerizo <doncicuto@gmail.com>

### BEGIN INIT INFO
# Provides:          glastopf
# Required-Start:    \$remote_fs \$network \$syslog
# Required-Stop:     \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start glastopf
# Description:       Glastopf is a web application honeypot.
### END INIT INFO

DAEMON_PATH="${GT_INSTALL_DIR}"
DAEMON="$(which glastopf-runner)""
 
NAME="glastopf"
DESC="Glastopf Honeypot"
PIDFILE="/var/run/\$NAME.pid"
SCRIPTNAME="/etc/init.d/\$NAME"

case "\$1" in

start) 
        echo -n "Starting \$DESC: "
        start-stop-daemon --start --chdir \$DAEMON_PATH --background --pidfile \$PIDFILE --make-pidfile --exec \$DAEMON && echo "OK"
        ;;

stop)
        echo -n "Stopping \$DESC: "
        start-stop-daemon --stop --pidfile \$PIDFILE && echo "OK"
        ;;

restart)
        echo "Restarting \$DESC: " 
        \$0 stop
        sleep 1
        \$0 start
        ;;

*)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;

esac

exit 0
EOF

chmod +x /etc/init.d/glastopf
update-rc.d glastopf defaults


echo "Restarting glastopf"
kill -9 $GT_PID && /etc/init.d/glastopf start
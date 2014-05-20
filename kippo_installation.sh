#! /bin/bash

KIPPO_INSTALL_DIR="/opt/kippo/"
APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

$APT_CMD $APT_OPTS install python-twisted python-mysqldb iptables-persistent pwgen

# download kippo
cd /tmp/
wget http://kippo.googlecode.com/files/kippo-0.8.tar.gz

tar -xvzf kippo-0.8.tar.gz

# move it to /opt/
mv kippo-0.8/ ${KIPPO_INSTALL_DIR}
cd ${KIPPO_INSTALL_DIR}

dpkg -s mysql-server &> /dev/null

if [ $? -ne 0 ]
then
	read -p "Installing mysql-server, remember password! Hit [ENTER] to continue."
	$APT_CMD $APT_OPTS install mysql-server
fi

read -s -p "Please enter your mysql root password: " MYSQL_ROOT_PW

kippo_pw=$(pwgen 30 1)

echo "CREATE DATABASE kippo; GRANT ALL ON kippo.* TO 'kippo'@'localhost' IDENTIFIED BY '${kippo_pw}';" | mysql -u root -h localhost --password="${MYSQL_ROOT_PW}"

mysql -u root -h localhost --password="${MYSQL_ROOT_PW}" kippo < ${KIPPO_INSTALL_DIR}doc/sql/mysql.sql

cat > ${KIPPO_INSTALL_DIR}kippo.cfg <<EOL

[database_mysql]
host = localhost
database = kippo
username = kippo
password = ${kippo_pw}
port = 3306
EOL

adduser --system --home ${KIPPO_INSTALL_DIR} --disabled-login kippo
chown -R kippo:nogroup ${KIPPO_INSTALL_DIR}

cat > /etc/init.d/kippo <<EOF
#!/bin/bash

### BEGIN INIT INFO
# Provides:          kippo
# Required-Start:    \$remote_fs \$network \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start kippo
# Description:       Kippo is a SSH honeypot.
### END INIT INFO

NAME="kippo"
DESC="Kippo Honeypot"
PIDDIR="/var/run/\$NAME"
PIDFILE="\$PIDDIR/\$NAME.pid"
SCRIPTNAME="/etc/init.d/\$NAME"

DAEMON_PATH="${KIPPO_INSTALL_DIR}"
DAEMON="${which twistd}"
DAEMON_ARGS="-y kippo.tac -l log/kippo.log --pidfile \$PIDFILE"
 
[ -d "\$PIDDIR" ] || mkdir -p "\$PIDDIR" && chown kippo "\$PIDDIR"


case "\$1" in

start) 
        echo -n "Starting \$DESC: "
        start-stop-daemon --start --chdir \$DAEMON_PATH --chuid kippo --background --pidfile \$PIDFILE --exec \$DAEMON -- \$DAEMON_ARGS && echo "OK"
        ;;

stop)
        echo -n "Stopping \$DESC: "
        start-stop-daemon --stop --pidfile \$PIDFILE && echo "OK"
        ;;

restart)
        echo "Restarting \$DESC: " 
        $0 stop
        sleep 1
        $0 start
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


# move ssh port away from port 22
sed -i "s/^Port 22$/Port 4711/" /etc/ssh/sshd_config
/etc/init.d/ssh restart

iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j REDIRECT --to-port 2222
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "Kippo installation done. Your kippo is now listening on port 22, your real sshd is listening on port 4711 now!"
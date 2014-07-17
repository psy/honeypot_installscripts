#! /bin/bash

JS_LOG_DIR="/opt/justniffer/logs/"

APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

$APT_CMD $APT_OPTS install curl patch tar make libc6 libpcap0.8 libpcap0.8-dev g++ gcc libboost-iostreams-dev libboost-program-options-dev libboost-regex-dev

cd /tmp/

wget -O justniffer.tar.gz "http://downloads.sourceforge.net/project/justniffer/justniffer/justniffer%200.5.11/justniffer_0.5.11.tar.gz?r=http%3A%2F%2Fjustniffer.sourceforge.net%2F&ts=1405417186&use_mirror=dfn"
tar -xvzf justniffer.tar.gz
cd justniffer-0.5.11

./configure
make
make install

mkdir -p $JS_LOG_DIR

echo "Looking up own ip"
$OWN_IP="$(curl ifconfig.me)"

# create init skript!
cat > /etc/init.d/justniffer <<EOF
#!/bin/bash

# Author: Miguel Cabrerizo <doncicuto@gmail.com>

### BEGIN INIT INFO
# Provides:          justniffer
# Required-Start:    \$remote_fs \$network \$syslog
# Required-Stop:     \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start justniffer
# Description:       Log network traffic
### END INIT INFO

NAME="justniffer"
DESC="Justniffer Network Traffic Analyzer"
PIDFILE="/var/run/\$NAME.pid"
SCRIPTNAME="/etc/init.d/\$NAME"

case "\$1" in

start) 
		if [[ -f \$PIDFILE && "\$(pgrep -F \$PIDFILE)" != "" ]]; then
			echo "Already running!"
			exit 1
		fi

        echo -n "Starting \$DESC: "
        $(which justniffer) -i eth0 -x -l "LOGBOUNDARY%newline%request.timestamp(%Y-%m-%dT%H:%M:%S%z) %source.ip %source.port -> %dest.ip %dest.port %request.line%newline%request" -p "not ((dst host $OWN_IP and dst port 4711) or (src host $OWN_IP and dst port 5000))" >> ${JS_LOG_DIR}log &
        echo \$! > \$PIDFILE
        if [ \$(pgrep -F \$PIDFILE) ]; then
        	echo "OK"
        else
        	rm \$PIDFILE
        	echo "failed!"
        fi
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

chmod +x /etc/init.d/justniffer
update-rc.d justniffer defaults

# logrotate?!
cat > /etc/logrotate.d/justniffer <<EOF
/opt/justniffer/logs/log {
	daily
	rotate 14
	compress
	delaycompress
	notifempty
}
EOF

/etc/init.d/justniffer start
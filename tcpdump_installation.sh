#! /bin/bash

TD_INSTALL_DIR="/opt/tcpdump/"
APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

$APT_CMD $APT_OPTS install tcpdump

mkdir -p /opt/tcpdump/

lvcreate -L 70G -n tcpdump vg00
mkfs.ext4 /dev/vg00/tcpdump
mount /dev/vg00/tcpdump /opt/tcpdump/

mkdir -p /opt/tcpdump/log/

echo "/dev/vg00/tcpdump /opt/tcpdump ext4 defaults,noatime 0 2" >> /etc/fstab

cat /etc/cron.daily/tcpdump.cleanup <<EOF
#!/bin/bash

find ${TD_INSTALL_DIR}log/ -atime +40 -print0 | xargs -0 /bin/rm -f    
EOF
chmod +x /etc/cron.daily/tcpdump.cleanup

cat > /etc/init.d/tcpdump <<EOF
#!/bin/bash

# Author: Miguel Cabrerizo <doncicuto@gmail.com>

### BEGIN INIT INFO
# Provides:          tcpdump
# Required-Start:    \$remote_fs \$network \$syslog
# Required-Stop:     \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start tcpdump
# Description:       Dump all traffic except for port 22
### END INIT INFO

DAEMON_PATH="${TD_INSTALL_DIR}"
DAEMON="$(which tcpdump)"
DAEMON_ARGS="-i eth0 -s 65535 -w log/tcpdump.pcap -C 1000 port ! 22 and port ! 4711"
 
NAME="tcpdump"
DESC="Tcpdump"
PIDFILE="/var/run/\$NAME.pid"
SCRIPTNAME="/etc/init.d/\$NAME"

case "\$1" in

start) 
        echo -n "Starting \$DESC: "
        start-stop-daemon --start --chdir \$DAEMON_PATH --background --pidfile \$PIDFILE --make-pidfile --exec \$DAEMON -- \$DAEMON_ARGS && echo "OK"
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

chmod +x /etc/init.d/tcpdump
/etc/init.d/tcpdump start
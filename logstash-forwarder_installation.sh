#! /bin/bash

LS_INSTALL_DIR="/opt/logstash-forwarder/"
APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

read -p "Please insert your logstash servers IP and Port (ip:port): " ES_IP

$APT_CMD $APT_OPTS install git rubygems

cd /tmp/
wget -c "http://golang.org/dl/go1.2.2.linux-amd64.tar.gz"
tar -C /usr/local/ -xzf go1.2.2.linux-amd64.tar.gz

export PATH=$PATH:/usr/local/go/bin

#echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile

git clone git://github.com/elasticsearch/logstash-forwarder.git
cd logstash-forwarder/
go build

#gem install fpm
#make deb
mkdir -p ${LS_INSTALL_DIR}bin
mkdir -p ${LS_INSTALL_DIR}config

cp logstash-forwarder logstash-forwarder.sh ${LS_INSTALL_DIR}bin/

cat > ${LS_INSTALL_DIR}config/config <<EOF
{
  "network": {
    "servers": [ "$ES_IP" ],
    "ssl ca": "/etc/ssl/logstash.pub",
    "timeout": 15
  },
  "files": [
    {
      "paths": [ 
        "/opt/glastopf/log/glastopf.log"
      ],
      "fields": { "type": "glastopf" }
    }, {
      "paths": [
        "/opt/kippo/log/kippo.log"
      ],
      "fields": { "type": "kippo" }
    }
  ]
}
EOF

cat > /etc/init.d/logstash-forwarder <<EOF
#!/bin/bash

# Author: Miguel Cabrerizo <doncicuto@gmail.com>

### BEGIN INIT INFO
# Provides:          logstash-forwarder
# Required-Start:    \$remote_fs \$network \$syslog
# Required-Stop:     \$remote_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start logstash-forwarder
# Description:       Forward logs to logstash server
### END INIT INFO

DAEMON_PATH="${LS_INSTALL_DIR}bin/"
DAEMON="logstash-forwarder"
DAEMON_ARGS="-config ${LS_INSTALL_DIR}config/config -log-to-syslog"
 
NAME="logstash-forwarder"
DESC="logstash-forwarder"
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

chmod +x /etc/init.d/logstash-forwarder
update-rc logstash-forwarder defaults


read -p "Please copy your ssl ca file to /etc/ssl/logstash.pub and press [ENTER]. If you want to do this step later and start logstash-forwarder manually, type \"N\" and press [Enter]" CONTINUE

if [ "$CONTINUE" != "N" ]; then
        /etc/init.d/logstash-forwarder start
fi


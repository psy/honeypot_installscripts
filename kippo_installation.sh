#! /bin/bash

KIPPO_INSTALL_DIR="/opt/kippo/"
APT_CMD=$(which apt-get)
APT_OPTS="--yes --no-install-recommends"

$APT_CMD $APT_OPTS install python-mysqldb iptables-persistent pwgen

# download kippo
cd /tmp/
wget http://kippo.googlecode.com/files/kippo-0.8.tar.gz

tar -xvzf kippo-0.8.tar.gz

# move it to /opt/
mv kippo-0.8/ ${KIPPO_INSTALL_DIR}
cd ${KIPPO_INSTALL_DIR}

dpkg -s mysql-server > /dev/null

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


# move ssh port away from port 22
sed -i "s/^Port 22$/Port 4711/" /etc/ssh/sshd_config
/etc/init.d/ssh restart

iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j REDIRECT --to-port 4711
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
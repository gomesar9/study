#!/bin/bash
# Must copy this file to same directory inside container
source install-icinga-module


MODULE_PATH=/usr/share/icingaweb2/modules/director
FILE_FLAG=/etc/icinga2/.setup.flag

if [ -f $FILE_FLAG ]; then
    echo "Already configured"
    if [ "$ENABLE_WEB" = "true" ]; then
        service apache2 start
        if [ "$ENABLE_DIRECTOR" = "true" ]; then
            /usr/bin/icingacli director daemon run &  # Dont know how to start using 'service <> start', we do not have systemd :(
        fi
    fi
    service icinga2 start
else
    echo "Waiting for services (10s)"
    sleep 10s
    tables=$(mysql -u $ICINGA_USER -h $DB_HOST --password=$ICINGA_PASS -e "USE $ICINGA_DB; SHOW tables;" | wc -l)
    if [ $tables -le 10 ] && [ -f '/usr/share/icinga2-ido-mysql/schema/mysql.sql' ]; then
        echo "Creating databae $ICINGA_DB"
        > /tmp/icinga.sql cat << EOF
CREATE DATABASE IF NOT EXISTS $ICINGA_DB;
GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON ${ICINGA_DB}.* TO '$ICINGA_USER'@'%' IDENTIFIED BY '$ICINGA_PASS';
EOF
        mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD < /tmp/icinga.sql
        # rm /tmp/icinga.sql
        mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD $ICINGA_DB < /usr/share/icinga2-ido-mysql/schema/mysql.sql
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] IDO schema loaded. [Ok]" >> $FILE_FLAG
    fi

    if [ "$ENABLE_WEB" = "true" ]; then
        if [ -z $ICINGAWEB_DB ] || [ -z $ICINGAWEB_USER ] || [ -z $ICINGAWEB_PASS ]; then
            echo "Please set all ICINGAWEB variables (ICINGAWEB_DB, ICINGAWEB_USER, ICINGAWEB_PASS)"
            echo "Aborting installation."
            exit 1
        fi
        apt install --quiet -y apache2 icingaweb2

        # Create database and user for IcingaWeb
        > /tmp/icingaweb.sql cat << EOF
CREATE DATABASE $ICINGAWEB_DB;
GRANT ALL ON ${ICINGAWEB_DB}.* TO $ICINGAWEB_USER@'%' IDENTIFIED BY '$ICINGAWEB_PASS';
EOF
        mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD < /tmp/icingaweb.sql
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Icingaweb database configured. [OK]" >> $FILE_FLAG
        # rm /tmp/icingaweb.sql

        if [ "$ENABLE_DIRECTOR" = "true" ]; then
            if [ -z $DIRECTOR_DB ] || [ -z $DIRECTOR_USER ] || [ -z $DIRECTOR_PASS ]; then
                echo "Please set all DIRECTOR variables (DIRECTOR_DB, DIRECTOR_USER, DIRECTOR_PASS)"
                echo "Aborting installation."
                exit 1
            fi
            install_module "ipl" "v0.4.0"
            install_module "incubator" "v0.5.0"
            install_module "reactbundle" "v0.7.0"
            install_module "director" "v1.7.1"

            # Create database and user for director
            > /tmp/director.sql cat << EOF
CREATE DATABASE $DIRECTOR_DB CHARACTER SET 'utf8';
GRANT ALL ON ${DIRECTOR_DB}.* TO $DIRECTOR_USER@'%' IDENTIFIED BY '$DIRECTOR_PASS';
EOF
            mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD < /tmp/director.sql
            # rm /tmp/director.sql
            icingacli module enable director

            useradd -r -g icingaweb2 -d /var/lib/icingadirector -s /bin/false icingadirector
            install -d -o icingadirector -g icingaweb2 -m 0750 /var/lib/icingadirector
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Icinga Director configured. [OK]" >> $FILE_FLAG

            cp "${MODULE_PATH}/contrib/systemd/icinga-director.service" /etc/systemd/system/
            #systemctl daemon-reload
            #systemctl enable icinga-director.service
        fi

        chown -R www-data:icingaweb2 /etc/icingaweb2/*
    fi

    icinga2 api setup
    if [ -f '/usr/share/icinga2-ido-mysql/schema/mysql.sql' ]; then
        # TODO: best way to know when it is a master host, and should run ido-mysql
        > /etc/icinga2/features-available/ido-mysql.conf cat << EOF
/**
 * The db_ido_mysql library implements IDO functionality
 * for MySQL.
 */

library "db_ido_mysql"

object IdoMysqlConnection "ido-mysql" {
  user = "icinga2",
  password = "mysql#icinga2",
  host = "icinga_db",
  database = "icinga2"
}
EOF
        chown nagios:nagios /etc/icinga2/features-available/ido-mysql.conf
        chmod 644 /etc/icinga2/features-available/ido-mysql.conf
        icinga2 feature enable ido-mysql
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] IDO-mysql started ($?)." >> $FILE_FLAG
    fi

    service icinga2 restart
    echo "##### Icinga credentials:"
    echo "DATABASE: '$ICINGA_DB'"
    echo "USER: '$ICINGA_USER'"
    echo "PASS: '$ICINGA_PASS'"

    if [ "$ENABLE_WEB" = "true" ]; then
        service apache2 restart

        echo "##### Use this token to configure icingaweb2:"
        icingacli setup token create
        echo "##### IcingaWeb credentials:"
        echo "DATABASE: '$ICINGAWEB_DB'"
        echo "USER: '$ICINGAWEB_USER'"
        echo "PASS: '$ICINGAWEB_PASS'"

        if [ "$ENABLE_DIRECTOR" = "true" ]; then
            # systemctl start icinga-director.service
            /usr/bin/icingacli director daemon run &
            echo "##### Director credentials:"
            echo "DATABASE: '$DIRECTOR_DB'"
            echo "USER: '$DIRECTOR_USER'"
            echo "PASS: '$DIRECTOR_PASS'"
            echo "> HINT: You must create director resouce with this credentials before setup director endpoint"
        fi
    fi
    touch $FILE_FLAG
fi

while [ 1 -eq 1 ]; do
    sleep 10m;
done

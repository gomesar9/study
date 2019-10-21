#!/bin/bash
source ./install-icinga-module


file_flag=/etc/icinga2/.setup.flag

if [ -f $file_flag ]; then
    echo "Already configured"
    service apache2 start
    service icinga2 start
else
    echo "Waiting for services (10s)"
    sleep 10s
    tables=$(echo "use icinga;show tables;"|mysql -u icinga -h $DB_HOST --password=$DB_PASS | wc -l)
    if [ $tables -le 2 ]; then
        mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD icinga < /usr/share/icinga2-ido-mysql/schema/mysql.sql
    fi

    if [[ $ENABLE_DIRECTOR = "true" ]]; then
        install_module "ipl" "v0.4.0"
        install_module "incubator" "v0.5.0"
        install_module "reactbundle" "v0.7.0"
        install_module "director" "v1.7.1"

        > /tmp/director.sql cat << EOF
CREATE DATABASE director CHARACTER SET 'utf8';
CREATE USER director@'%' IDENTIFIED BY '$DIRECTOR_PASS';
GRANT ALL ON director.* TO director@'%';
EOF
        mysql -u root -h s_icinga_db --password=$MYSQL_ROOT_PASSWORD icinga < /tmp/director.sql
        icingacli module enable director
    fi

    chown -R www-data:icingaweb2 /etc/icingaweb2/*

    icinga2 feature enable ido-mysql
    icinga2 api setup

    service apache2 restart
    service icinga2 restart

    echo "##### Use this token to configure icingaweb2:"
    icingacli setup token create

    touch $file_flag
fi

while [ 1 -eq 1 ]; do
    sleep 10m;
done

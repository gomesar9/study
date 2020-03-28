FROM icinga2 AS icinga2_master

RUN echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-install boolean false" | debconf-set-selections \
    && echo "icinga2-ido-mysql icinga2-ido-mysql/enable boolean true" | debconf-set-selections \
    && apt install -y icinga2-ido-mysql icingacli monitoring-plugins

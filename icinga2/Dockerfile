FROM debian_base:latest AS icinga2

RUN curl https://packages.icinga.com/icinga.key | apt-key add - && \
    echo "deb http://packages.icinga.com/debian icinga-buster main" | tee /etc/apt/sources.list.d/icinga.list && \
    echo "deb-src http://packages.icinga.com/debian icinga-buster main" | tee -a /etc/apt/sources.list.d/icinga.list && \
    apt update && apt install -y icinga2 icingacli && \
    echo "##### Icinga2 installed"

RUN apt install -y vim-icinga2 vim-addon-manager mariadb-client apache2 && \
    vim-addon-manager -w install icinga2

RUN echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-install boolean false" | debconf-set-selections && \
    echo "icinga2-ido-mysql icinga2-ido-mysql/enable boolean true" | debconf-set-selections && \
    apt install -y icinga2-ido-mysql icingaweb2 icingacli

WORKDIR /code

ADD ./code/* /code/

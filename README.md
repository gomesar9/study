# Study

Topics:
- Docker
- Docker-compose
- Icinga2
- Elasticsearch
- Kibana
- Filebeat
- Logstash
- Django
- Galera Cluster (MariaDB)
- Grafana


## Icinga2
1. Build icinga2 base image:
```
cd icinga2
./build.sh
cd -
```

2. Start containers:
```
docker-compose -f docker-compose.yml -f docker-compose.icinga.yml up --build icinga_web
```

3. Setup IcingaWeb:

Go to: http://localhost:81/icingaweb2

Use informations printed in temrinal (ticket, credencials)

4. Create resouce for director, and finish its setup.
5. Deploy and Go ;]

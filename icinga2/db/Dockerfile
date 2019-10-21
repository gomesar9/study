FROM debian_base

RUN apt update && apt mariadb-server mariadb-client && \
  mysql_secure_installation

ENTRYPOINT ["mysql"]
